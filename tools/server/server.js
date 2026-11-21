// СССР РП (City Alpha) — онлайн-сервер. Node.js 18+, без внешних библиотек (свой WebSocket по RFC 6455).
//
// Запуск:              node server.js        (порт из переменной PORT, иначе 7777)
// Render.com:          Root Directory: tools/server → Start Command: node server.js
// База:                Firebase Realtime Database — переменные FIREBASE_URL и FIREBASE_SECRET.
//                      Без них всё хранится в памяти до перезапуска (для тестов).
// Владелец сервера:    первый зарегистрированный аккаунт получает админку 5-го уровня.
//
// Сервер — главный: деньги, фракции и ранги, дома, районы ОПГ, время и погода хранятся и проверяются
// здесь. Телефон присылает изменения, сервер принимает их или поправляет («money_set», «faction_set»).
//
// Протокол — JSON в текстовых кадрах WebSocket. Клиент → сервер:
//   auth {mode:"login"|"register", nick, pass}        hello {look}
//   st {s:[x,y,z,yaw,anim,aspeed,car,xf,wanted,hp,fid]}  say {x}  save {d}
//   money {cash, bank, ver}     faction {fid, rank}    give {to, amount}
//   act {to, kind, dmg?}        answer {id, ok}        turf {key, gid}
//   home {i, buy:true|false}    roster {}
// Сервер → клиент:
//   auth_ok {nick, save, prof}  auth_err {msg}   welcome {id, name, list}   join / left
//   sts {l:[[id, s], ...]}      chat {n, x, k}   money_set {cash, bank, ver, msg}
//   faction_set {fid, rank, msg}  act {from, name, kind, ...}  ask {id, from, name, kind, text}
//   turf {map}  homes {taken}  world {min, day, weather}  roster {fid, list}  tp {x,y,z}
//   kicked {msg}  notice {x}
'use strict';
const http = require('http');
const crypto = require('crypto');

const PORT = parseInt(process.env.PORT || '7777', 10);
const SEND_MS = 125;
const VIEW_DIST = 300;
const CHAT_DIST = 60;
const MAX_PLAYERS = 200;
const GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

const FACTIONS = ['mayor', 'police', 'hospital', 'fire', 'kgb', 'tyap', 'universam', 'solnce', 'kavkaz', 'police_p', 'hospital_p'];
const POLICE = ['police', 'police_p', 'kgb'];
const MEDIC = ['hospital', 'hospital_p'];
const GANGS = ['tyap', 'universam', 'solnce', 'kavkaz'];
const SELF_RANK_MAX = 6;            // до этого ранга можно дорасти стажем; выше — только лидер/админ
const RANK_COOLDOWN_MS = 4 * 60 * 1000;
// Доходы по видам: [сколько можно получить «залпом», сколько восполняется за минуту].
// Клиент сообщает, откуда деньги; сервер пропускает рост денег только в пределах этих лимитов.
const INCOME = {
  job: [30000, 3000], duty: [30000, 3000], pay: [60000, 2000], biz: [200000, 12000],
  reward: [60000, 3000], crime: [40000, 4000], fish: [30000, 3000], casino: [150000, 15000],
  race: [60000, 6000], misc: [15000, 1500],
};
const START_MONEY = 5000;           // как START_MONEY в main.gd

// ---------------------------------------------------------------- база
const FB_URL = (process.env.FIREBASE_URL || '').replace(/\/+$/, '');
const FB_SECRET = process.env.FIREBASE_SECRET || '';
const USE_FB = !!(FB_URL && FB_SECRET);
const mem = {};                     // режим без Firebase: дерево в памяти

function memNode(path, create) {
  let node = mem;
  const parts = path.split('/').filter(Boolean);
  for (let i = 0; i < parts.length; i++) {
    if (node[parts[i]] === undefined || node[parts[i]] === null || typeof node[parts[i]] !== 'object') {
      if (!create) return { parent: null };
      node[parts[i]] = {};
    }
    if (i === parts.length - 1) return { parent: node, key: parts[i] };
    node = node[parts[i]];
  }
  return { parent: null };
}

async function dbGet(path) {
  if (!USE_FB) {
    const parts = path.split('/').filter(Boolean);
    let node = mem;
    for (const k of parts) { if (node == null || typeof node !== 'object') return null; node = node[k]; }
    return node === undefined ? null : JSON.parse(JSON.stringify(node));
  }
  // без ответа базы 10 с — ошибка (игрок увидит сообщение, а не вечное «Подождите...»)
  const r = await fetch(`${FB_URL}/${path}.json?auth=${FB_SECRET}`, { signal: AbortSignal.timeout(10000) });
  if (!r.ok) throw new Error('firebase get ' + r.status);
  return await r.json();
}

async function dbPatch(path, obj) {
  if (!USE_FB) {
    const { parent, key } = memNode(path, true);
    parent[key] = Object.assign(typeof parent[key] === 'object' && parent[key] ? parent[key] : {}, JSON.parse(JSON.stringify(obj)));
    for (const k of Object.keys(obj)) if (obj[k] === null) delete parent[key][k];
    return;
  }
  const r = await fetch(`${FB_URL}/${path}.json?auth=${FB_SECRET}`,
    { method: 'PATCH', body: JSON.stringify(obj), headers: { 'Content-Type': 'application/json' }, signal: AbortSignal.timeout(10000) });
  if (!r.ok) throw new Error('firebase patch ' + r.status);
}

function dbLater(path, obj) { dbPatch(path, obj).catch(e => log('ошибка базы: ' + e.message)); }

// общие данные мира — держим в памяти, пишем в базу сразу
const world = { turf: {}, homes: {}, biz: {}, leaders: {}, members: {}, owner: '' };

async function loadWorld() {
  try {
    world.turf = (await dbGet('world/turf')) || {};
    world.homes = (await dbGet('world/homes')) || {};
    world.biz = (await dbGet('world/biz')) || {};
    world.leaders = (await dbGet('world/leaders')) || {};
    world.budget = (await dbGet('world/budget')) || 0;
    world.tax = (await dbGet('world/tax')) || 0;
    world.families = (await dbGet('world/families')) || {};
    world.members = (await dbGet('world/members')) || {};
    world.owner = (await dbGet('world/owner')) || '';
    world.port = (await dbGet('world/port')) || { owner: '', ammo: 200 };
    world.gstock = (await dbGet('world/gstock')) || {};
    log(`мир загружен: районов ${Object.keys(world.turf).length}, домов занято ${Object.keys(world.homes).length}`);
  } catch (e) { log('не удалось загрузить мир: ' + e.message); }
}

// ---------------------------------------------------------------- игроки
let nextId = 1;
const players = new Map();          // id -> p
const SAVE_EVERY_MS = 20000;

function accKey(nick) { return nick.toLowerCase().replace(/[.#$\[\]\/\s]/g, '_'); }
function hashPass(pass, salt) { return crypto.scryptSync(pass, salt, 32).toString('hex'); }
function cleanName(s) { return String(s || '').replace(/[\x00-\x1f\[\]<>]/g, '').trim().slice(0, 24); }
function cleanText(s) { return String(s || '').replace(/[\x00-\x1f\[\]]/g, '').trim().slice(0, 160); }
function dist(a, b) { return Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]); }
function online() { let n = 0; for (const p of players.values()) if (p.name) n++; return n; }
function log(s) { console.log(new Date().toISOString().slice(0, 19).replace('T', ' ') + ' ' + s); }

// Журнал важных действий (переводы, продажи, аресты, наказания, репорты): последние 1000 — в памяти (/logs),
// всё — в консоль (Render → Logs) и в базу logs/<дата>, чтобы разбирать жалобы и ловить читеров.
const AUDIT = [];
function audit(kind, text, nicks) {
  const t = Date.now();
  const e = { t, kind, text, nicks: (nicks || []).map(n => String(n).toLowerCase()) };
  AUDIT.push(e);
  if (AUDIT.length > 1000) AUDIT.shift();
  log(`[${kind}] ${text}`);
  const day = new Date(t).toISOString().slice(0, 10);
  dbLater('logs/' + day, { [t.toString(36) + Math.random().toString(36).slice(2, 5)]: `${kind}: ${text}` });
}
function byNick(nick) {
  const k = accKey(String(nick || ''));
  for (const p of players.values()) if (p.acc && p.acc.key === k) return p;
  return null;
}
function near(p, q, d) { return p.s && q.s && dist(p.s, q.s) <= d; }
function isLeader(p) { return !!(p.acc && p.acc.faction && world.leaders[p.acc.faction] === p.acc.key); }
function admin(p) { return p.acc ? (p.acc.admin | 0) : 0; }
function banUntilMsg(acc) {
  const d = new Date(acc.ban_until + 3 * 3600000).toISOString();
  return `Бан до ${d.slice(8, 10)}.${d.slice(5, 7)} ${d.slice(11, 16)} МСК: ${acc.ban_reason || 'нарушение правил'}`;
}

// ---------------------------------------------------------------- WebSocket
const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end(`SSSR RP server: online ${online()}\n`);
});

server.on('upgrade', (req, sock) => {
  const key = req.headers['sec-websocket-key'];
  if (!key || players.size >= MAX_PLAYERS) { sock.destroy(); return; }
  const accept = crypto.createHash('sha1').update(key + GUID).digest('base64');
  sock.write('HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n' +
             `Sec-WebSocket-Accept: ${accept}\r\n\r\n`);
  sock.setNoDelay(true);
  const id = nextId++;
  const p = { id, sock, name: '', info: {}, s: null, chatT: 0, buf: Buffer.alloc(0), frags: [],
              bk: newBuckets(), sale: 0, ver: 1, hitT: 0, asks: new Map() };
  players.set(id, p);
  sock.on('data', (d) => { p.buf = Buffer.concat([p.buf, d]); readFrames(p); });
  sock.on('close', () => drop(p));
  sock.on('error', () => drop(p));
});

function frame(op, payload) {
  const len = payload.length;
  let head;
  if (len < 126) { head = Buffer.from([0x80 | op, len]); }
  else if (len < 65536) { head = Buffer.alloc(4); head[0] = 0x80 | op; head[1] = 126; head.writeUInt16BE(len, 2); }
  else { head = Buffer.alloc(10); head[0] = 0x80 | op; head[1] = 127; head.writeBigUInt64BE(BigInt(len), 2); }
  return Buffer.concat([head, payload]);
}

function send(p, obj) {
  if (!p || p.sock.destroyed) return;
  try { p.sock.write(frame(1, Buffer.from(JSON.stringify(obj)))); } catch (e) { /* закрылся */ }
}
function sendAll(obj, filter) { for (const q of players.values()) if (q.name && (!filter || filter(q))) send(q, obj); }
function notice(p, x) { send(p, { t: 'chat', n: '', x, k: 'info' }); }

function readFrames(p) {
  while (p.buf.length >= 2) {
    const b0 = p.buf[0], b1 = p.buf[1];
    const fin = (b0 & 0x80) !== 0, op = b0 & 0x0f, masked = (b1 & 0x80) !== 0;
    let len = b1 & 0x7f, off = 2;
    if (len === 126) { if (p.buf.length < 4) return; len = p.buf.readUInt16BE(2); off = 4; }
    else if (len === 127) { if (p.buf.length < 10) return; len = Number(p.buf.readBigUInt64BE(2)); off = 10; }
    if (len > 400000) { p.sock.destroy(); return; }
    const need = off + (masked ? 4 : 0) + len;
    if (p.buf.length < need) return;
    let data = p.buf.subarray(off + (masked ? 4 : 0), need);
    if (masked) {
      const m = p.buf.subarray(off, off + 4);
      data = Buffer.from(data);
      for (let i = 0; i < data.length; i++) data[i] ^= m[i & 3];
    }
    p.buf = p.buf.subarray(need);
    if (op === 8) { try { p.sock.end(frame(8, Buffer.alloc(0))); } catch (e) {} drop(p); return; }
    if (op === 9) { try { p.sock.write(frame(10, data)); } catch (e) {} continue; }
    if (op === 10) continue;
    if (op === 1 || op === 2 || op === 0) {
      p.frags.push(data);
      if (!fin) continue;
      const msg = Buffer.concat(p.frags).toString('utf8');
      p.frags = [];
      let obj = null;
      try { obj = JSON.parse(msg); } catch (e) { continue; }
      if (obj && typeof obj === 'object') {
        try { onMessage(p, obj); } catch (e) { log('ошибка обработки: ' + e.stack); }
      }
    }
  }
}

// ---------------------------------------------------------------- аккаунты
// Сессии для переподключения без пароля (обрыв мобильной сети): токен живёт 30 минут.
const tokens = new Map();               // токен -> { key, exp }
const memo = new Map();                 // ключ аккаунта -> лимиты дохода (не сбрасываются перезаходом)
setInterval(() => { const now = Date.now(); for (const [t, v] of tokens) if (v.exp < now) tokens.delete(t); }, 60000);

async function onAuth(p, m) {
  if (p.acc || p.authBusy) return;
  if (m.mode === 'token') return onTokenAuth(p, m);
  const nick = cleanName(m.nick);
  const pass = String(m.pass || '');
  if (!/^[A-Za-zА-Яа-яЁё0-9_]{3,20}$/.test(nick)) {
    return send(p, { t: 'auth_err', msg: 'Ник: от 3 до 20 букв, цифр или «_», без пробелов' });
  }
  if (pass.length < 4 || pass.length > 64) return send(p, { t: 'auth_err', msg: 'Пароль: от 4 до 64 символов' });
  const key = accKey(nick);
  log(`${m.mode === 'register' ? 'регистрация' : 'вход'}: запрос ${nick}`);
  p.authBusy = true;
  try {
    let acc = await dbGet('accounts/' + key);
    if (m.mode === 'register') {
      if (acc) return send(p, { t: 'auth_err', msg: 'Такой ник уже занят — выбери другой или войди' });
      if (!RP_NICK.test(nick)) return send(p, { t: 'auth_err', msg: 'RP-ник: Имя_Фамилия с большой буквы, например Иван_Петров' });
      const salt = crypto.randomBytes(16).toString('hex');
      acc = { nick, salt, hash: hashPass(pass, salt), created: Date.now(), save: '', saved_at: 0,
              cash: START_MONEY, bank: 0, faction: '', rank: 0, rank_t: 0, admin: 0, home: -1,
              sex: m.sex === 'f' ? 'f' : 'm' };
      if (!world.owner) {   // первый аккаунт — владелец сервера
        world.owner = key;
        acc.admin = 5;
        dbLater('world', { owner: key });
      }
      await dbPatch('accounts/' + key, acc);
      log(`регистрация ${nick}${acc.admin ? ' (владелец сервера)' : ''}`);
    } else {
      if (!acc) return send(p, { t: 'auth_err', msg: 'Аккаунт не найден — зарегистрируйся' });
      const h = hashPass(pass, acc.salt);
      if (!crypto.timingSafeEqual(Buffer.from(h, 'hex'), Buffer.from(String(acc.hash), 'hex'))) {
        return send(p, { t: 'auth_err', msg: 'Неверный пароль' });
      }
      if (acc.banned) return send(p, { t: 'auth_err', msg: 'Аккаунт заблокирован: ' + (acc.ban_reason || 'нарушение правил') });
      if (acc.ban_until > Date.now()) return send(p, { t: 'auth_err', msg: banUntilMsg(acc) });
    }
    login(p, key, acc, nick);
  } catch (e) {
    log('ошибка базы при входе: ' + e.message);
    send(p, { t: 'auth_err', msg: /40[13]/.test(e.message) ? 'Сервер не может открыть базу (проверь FIREBASE_SECRET на Render)' : 'База данных не отвечает, попробуй ещё раз' });
  } finally {
    p.authBusy = false;
  }
}

function login(p, key, acc, nick) {
  p.acc = {
    key, nick: acc.nick || nick, save: String(acc.save || ''),
    cash: acc.cash == null ? null : acc.cash | 0, bank: acc.bank == null ? null : acc.bank | 0,
    faction: FACTIONS.includes(acc.faction) ? acc.faction : '', rank: acc.rank | 0, rank_t: acc.rank_t || 0,
    admin: acc.admin | 0, home: acc.home == null ? -1 : acc.home | 0, muted: acc.muted || 0,
    sex: acc.sex === 'f' ? 'f' : 'm',
  };
  for (const q of players.values()) {
    if (q !== p && q.acc && q.acc.key === key) {
      // старая сессия этого же аккаунта (обрыв связи или второй телефон): её данные свежее базы
      for (const f of ['cash', 'bank', 'faction', 'rank', 'rank_t', 'admin', 'home', 'muted']) p.acc[f] = q.acc[f];
      if (q.pendingSave != null) p.acc.save = q.pendingSave;
      p.sale = q.sale;
      flushSave(q); send(q, { t: 'kicked', msg: 'Вход с другого устройства' }); drop(q);
    }
  }
  if (memo.has(key)) { const mm = memo.get(key); p.bk = mm.bk; p.sale = Math.max(p.sale, mm.sale); }
  memo.set(key, { bk: p.bk, sale: p.sale });
  const token = crypto.randomBytes(18).toString('hex');
  tokens.set(token, { key, exp: Date.now() + 30 * 60000 });
  send(p, { t: 'auth_ok', nick: p.acc.nick, save: p.acc.save, prof: profile(p), token });
}

async function onTokenAuth(p, m) {
  const tk = tokens.get(String(m.token || ''));
  if (!tk || tk.exp < Date.now()) return send(p, { t: 'auth_err', msg: 'Сессия истекла — войди заново' });
  tokens.delete(String(m.token));
  p.authBusy = true;
  try {
    const acc = await dbGet('accounts/' + tk.key);
    if (!acc || acc.banned) return send(p, { t: 'auth_err', msg: acc ? 'Аккаунт заблокирован' : 'Аккаунт не найден' });
    if (acc.ban_until > Date.now()) return send(p, { t: 'auth_err', msg: banUntilMsg(acc) });
    login(p, tk.key, acc, acc.nick);
    log(`переподключился ${p.acc.nick}`);
  } catch (e) {
    send(p, { t: 'auth_err', msg: 'Сервер базы не отвечает, попробуй позже' });
  } finally {
    p.authBusy = false;
  }
}

function profile(p) {
  const a = p.acc;
  return { cash: a.cash, bank: a.bank, faction: a.faction, rank: a.rank, admin: a.admin, home: a.home,
           leader: isLeader(p), ver: p.ver, sex: a.sex || 'm',
           family: a.family && world.families[a.family] ? world.families[a.family].name : '' };
}

function takenHomes(p) {
  const out = [];
  for (const i of Object.keys(world.homes)) if (!p.acc || world.homes[i] !== p.acc.key) out.push(+i);
  return out;
}

function persist(p, fields) { if (p.acc) dbLater('accounts/' + p.acc.key, fields); }

function flushSave(p) {
  if (!p.acc || p.pendingSave == null) return;
  const d = p.pendingSave;
  p.pendingSave = null;
  p.lastWrite = Date.now();
  persist(p, { save: d, saved_at: Date.now(), cash: p.acc.cash, bank: p.acc.bank });
}

setInterval(() => {
  const now = Date.now();
  for (const p of players.values()) if (p.pendingSave != null && now - (p.lastWrite || 0) >= SAVE_EVERY_MS) flushSave(p);
  for (const p of players.values())   // деньги в базу — не чаще раза в 20 с на игрока
    if (p.moneyDirty && p.acc && now - (p.moneyT || 0) >= SAVE_EVERY_MS) { p.moneyDirty = false; p.moneyT = now; persist(p, { cash: p.acc.cash, bank: p.acc.bank }); }
}, 2000);

// ---------------------------------------------------------------- экономика
function setMoney(p, cash, bank, msg) {
  p.acc.cash = cash; p.acc.bank = bank; p.ver++;
  send(p, { t: 'money_set', cash, bank, ver: p.ver, msg: msg || '' });
  persist(p, { cash, bank });
}

function newBuckets() {
  const t = Date.now(), b = {};
  for (const k of Object.keys(INCOME)) b[k] = { v: Math.min(INCOME[k][0], INCOME[k][1] * 2), t };
  return b;
}
function bucket(p, k) {
  const b = p.bk[k], now = Date.now();
  b.v = Math.min(INCOME[k][0], b.v + (now - b.t) / 60000 * INCOME[k][1]); b.t = now;
  return b;
}
// Сколько из роста денег gain покрывают лимиты (лимиты списываются).
function incomeCheck(p, src, gain) {
  const take = [];
  let left = gain;
  for (const k of Object.keys(src)) {
    if (!INCOME[k] || k === 'misc' || left <= 0) continue;
    const b = bucket(p, k);
    const x = Math.min(Math.max(0, +src[k] || 0), b.v, left);
    take.push([b, x]); left -= x;
  }
  const misc = bucket(p, 'misc');
  const xm = Math.min(misc.v, left); left -= xm;
  const xs = Math.min(p.sale, left); left -= xs;
  for (const [b, x] of take) b.v -= x;
  misc.v -= xm; p.sale -= xs;
  return Math.floor(gain - left); // сколько из роста денег законно
}

function onMoney(p, m) {
  if (!p.acc) return;
  const cash = Math.trunc(+m.cash), bank = Math.trunc(+m.bank);
  if (!Number.isFinite(cash) || !Number.isFinite(bank) || cash < 0 || bank < 0) return;
  if ((m.ver | 0) < p.ver) return;   // устаревший отчёт (сервер уже поменял деньги)
  if (p.acc.cash == null) {   // старый аккаунт без денег на сервере — берём с телефона, но не больше 300 000
    const k = Math.min(1, 300000 / Math.max(1, cash + bank));
    p.acc.cash = Math.floor(cash * k); p.acc.bank = Math.floor(bank * k);
    persist(p, { cash: p.acc.cash, bank: p.acc.bank });
    if (k < 1) setMoney(p, p.acc.cash, p.acc.bank, 'Сервер ограничил стартовые деньги');
    return;
  }
  const gain = cash + bank - p.acc.cash - p.acc.bank;
  if (gain > 0) {
    const src = (m.src && typeof m.src === 'object') ? m.src : {};
    const ok = incomeCheck(p, src, gain);
    if (ok < gain) {   // законную часть оставляем, лишнее снимаем (сначала с наличных)
      log(`подозрение: ${p.acc.nick} +${gain} ₽, законно ${ok} (${JSON.stringify(src).slice(0, 120)})`);
      for (const q of players.values()) if (admin(q) >= 1) notice(q, `[античит] ${p.acc.nick}: +${gain} ₽ слишком быстро`);
      p.flags = (p.flags || 0) + 1;
      let extra = gain - ok;
      let c = cash, b = bank;
      const fc = Math.min(extra, Math.max(0, c - p.acc.cash)); c -= fc; extra -= fc;
      const fb = Math.min(extra, Math.max(0, b - p.acc.bank)); b -= fb; extra -= fb;
      if (extra > 0) { c = Math.max(0, c - extra); }
      return setMoney(p, c, b, 'Сервер отклонил часть денег: слишком быстрый доход');
    }
  }
  p.acc.cash = cash; p.acc.bank = bank; p.moneyDirty = true;
}

function onGive(p, m) {
  const q = players.get(m.to | 0);
  const amount = Math.trunc(+m.amount);
  if (!p.acc || !q || !q.acc || q === p) return;
  if (!(amount > 0)) return notice(p, 'Неверная сумма');
  if (!near(p, q, 5)) return notice(p, 'Игрок слишком далеко');
  if (p.acc.cash == null || p.acc.cash < amount) return notice(p, 'Не хватает наличных');
  setMoney(p, p.acc.cash - amount, p.acc.bank, `Передал ${amount} ₽ игроку ${q.acc.nick}`);
  setMoney(q, (q.acc.cash || 0) + amount, q.acc.bank || 0, `${p.acc.nick} передал тебе ${amount} ₽`);
  audit('перевод', `${p.acc.nick} → ${q.acc.nick}: ${amount} ₽`, [p.acc.nick, q.acc.nick]);
}

// ---------------------------------------------------------------- фракции
function setFaction(p, fid, rank, msg) {
  const old = p.acc.faction;
  if (old && old !== fid) {
    if (world.members[old]) delete world.members[old][p.acc.key];
    dbLater(`world/members/${old}`, { [p.acc.key]: null });
    if (world.leaders[old] === p.acc.key) { delete world.leaders[old]; dbLater('world/leaders', { [old]: null }); }
  }
  p.acc.faction = fid; p.acc.rank = fid ? rank : 0; p.acc.rank_t = Date.now();
  if (fid) {
    (world.members[fid] = world.members[fid] || {})[p.acc.key] = { nick: p.acc.nick, rank: p.acc.rank };
    dbLater(`world/members/${fid}`, { [p.acc.key]: { nick: p.acc.nick, rank: p.acc.rank } });
  }
  persist(p, { faction: fid, rank: p.acc.rank, rank_t: p.acc.rank_t });
  send(p, { t: 'faction_set', fid, rank: p.acc.rank, leader: isLeader(p), msg: msg || '' });
}

function onFaction(p, m) {
  if (!p.acc) return;
  const fid = String(m.fid || ''), rank = m.rank | 0, a = p.acc;
  if (fid === a.faction && rank <= a.rank && fid !== '') return;   // клиент ограничил ранг своим максимумом — не спорим
  let ok = false;
  if (fid === '') ok = true;                                                         // ушёл сам
  else if (!a.faction && FACTIONS.includes(fid) && rank === 1) ok = true;             // устроился через отдел кадров
  else if (fid === a.faction && rank === a.rank + 1 && rank <= SELF_RANK_MAX &&
           Date.now() - a.rank_t >= RANK_COOLDOWN_MS) ok = true;                       // повышение за стаж
  if (ok) {
    if (fid && a.faction && fid !== a.faction) return;
    setFaction(p, fid, rank);
    if (fid) factionChat(fid, '', fid === a.faction && rank > 1 ? `${a.nick} повышен до ${rank} ранга` : `${a.nick} вступил в организацию`);
  } else {
    send(p, { t: 'faction_set', fid: a.faction, rank: a.rank, leader: isLeader(p), msg: 'Сервер: изменение фракции отклонено' });
  }
}

function factionChat(fid, from, x) {
  for (const q of players.values()) if (q.acc && q.acc.faction === fid) send(q, { t: 'chat', n: from, x, k: 'faction' });
}

async function onRoster(p) {
  if (!p.acc || !p.acc.faction) return send(p, { t: 'roster', fid: '', list: [] });
  const fid = p.acc.faction;
  const mem = world.members[fid] || {};
  const list = Object.keys(mem).map(k => ({ nick: mem[k].nick, rank: mem[k].rank | 0,
    online: !![...players.values()].find(q => q.acc && q.acc.key === k), leader: world.leaders[fid] === k }));
  list.sort((x, y) => (y.leader - x.leader) || (y.rank - x.rank) || (y.online - x.online));
  send(p, { t: 'roster', fid, list: list.slice(0, 100), leader: world.leaders[fid] ? (mem[world.leaders[fid]] || {}).nick || '' : '' });
}

// ---------------------------------------------------------------- взаимодействие игроков
function onAct(p, m) {
  const q = players.get(m.to | 0);
  if (!p.acc || !q || !q.acc || q === p) return;
  const kind = String(m.kind || '');
  const now = Date.now();
  if (kind === 'hit') {
    const melee = !!m.melee;
    if (now - p.hitT < 250) return;
    p.hitT = now;
    if (!near(p, q, melee ? 3.5 : 70)) return;
    const dmg = Math.max(1, Math.min(melee ? 15 : 40, m.dmg | 0));
    send(q, { t: 'act', from: p.id, name: p.acc.nick, kind: 'hit', dmg, melee });
  } else if (kind === 'arrest') {
    if (!POLICE.includes(p.acc.faction)) return notice(p, 'Задерживать может только милиция или КГБ');
    if (!near(p, q, 4)) return notice(p, 'Подойди ближе');
    if (!q.s || (q.s[8] | 0) <= 0) return notice(p, 'Этот гражданин не в розыске');
    send(q, { t: 'act', from: p.id, name: p.acc.nick, kind: 'arrest' });
    setMoney(p, p.acc.cash || 0, (p.acc.bank || 0) + 300 * (q.s[8] | 0), `Премия за задержание: ${300 * (q.s[8] | 0)} ₽`);
    audit('арест', `${p.acc.nick} задержал ${q.acc.nick} (розыск ${q.s[8] | 0})`, [p.acc.nick, q.acc.nick]);
    sendAll({ t: 'chat', n: '', x: `${p.acc.nick} задержал ${q.acc.nick}`, k: 'faction' }, r => r.acc && POLICE.includes(r.acc.faction));
  } else if (kind === 'heal') {
    if (!MEDIC.includes(p.acc.faction)) return notice(p, 'Лечить может только врач');
    if (!near(p, q, 4)) return notice(p, 'Подойди ближе');
    askPlayer(p, q, 'heal', `Врач ${p.acc.nick} предлагает лечение за 300 ₽. Согласен?`);
  } else if (kind === 'invite') {
    if (!p.acc.faction || !(isLeader(p) || admin(p) >= 3)) return notice(p, 'Приглашать может лидер организации');
    if (q.acc.faction) return notice(p, 'Игрок уже в организации');
    if (!near(p, q, 6)) return notice(p, 'Подойди ближе');
    askPlayer(p, q, 'invite', `${p.acc.nick} приглашает тебя в организацию. Вступить?`, { fid: p.acc.faction });
  } else if (kind === 'passport') {
    if (!near(p, q, 6)) return;
    askPlayer(p, q, 'passport', `${p.acc.nick} просит показать паспорт. Показать?`);
  }
}

let askId = 1;
function askPlayer(p, q, kind, text, extra) {
  const id = askId++;
  q.asks.set(id, Object.assign({ kind, from: p.id, t: Date.now() }, extra || {}));
  send(q, { t: 'ask', id, from: p.id, name: p.acc.nick, kind, text });
  notice(p, 'Предложение отправлено, ждём ответа');
}

function onAnswer(q, m) {
  const a = q.asks.get(m.id | 0);
  if (!a) return;
  q.asks.delete(m.id | 0);
  const p = players.get(a.from);
  if (!p || !p.acc || Date.now() - a.t > 60000) return;
  if (!m.ok) {
    if (a.kind === 'ticket') send(q, { t: 'act', from: p.id, name: p.acc.nick, kind: 'su', stars: 1, why: 'отказ платить штраф' });
    return notice(p, `${q.acc.nick} отказался`);
  }
  if (a.kind === 'heal') {
    if ((q.acc.cash || 0) < 300) return notice(q, 'Нужно 300 ₽ наличными');
    setMoney(q, q.acc.cash - 300, q.acc.bank || 0, 'Оплата лечения 300 ₽');
    setMoney(p, (p.acc.cash || 0) + 300, p.acc.bank || 0, `${q.acc.nick} оплатил лечение`);
    send(q, { t: 'act', from: p.id, name: p.acc.nick, kind: 'heal' });
  } else if (a.kind === 'invite') {
    if (q.acc.faction || p.acc.faction !== a.fid) return;
    setFaction(q, a.fid, 1, 'Ты принят в организацию');
    factionChat(a.fid, '', `${q.acc.nick} принят в организацию (пригласил ${p.acc.nick})`);
  } else if (a.kind === 'family') {
    const fam = world.families[a.fid];
    if (!fam || q.acc.family) return;
    fam.members[q.acc.key] = q.acc.nick;
    q.acc.family = a.fid; persist(q, { family: a.fid }); saveFam(a.fid);
    send(q, { t: 'prof', prof: profile(q) });
    famChat(a.fid, '', `${q.acc.nick} вступил в семью «${fam.name}»`);
  } else if (a.kind === 'call') {
    if (p.callWith || q.callWith) return notice(q, 'Линия занята');
    p.callWith = q.id; q.callWith = p.id;
    for (const r of [p, q]) send(r, { t: 'chat', n: '📞', x: `Разговор: ${p.acc.nick} — ${q.acc.nick}. Пиши /t текст, /h — положить трубку`, k: 'call' });
  } else if (a.kind === 'trade') {
    if (a.price > 0) {
      if ((q.acc.cash || 0) < a.price) return notice(q, 'Не хватает наличных');
      setMoney(q, q.acc.cash - a.price, q.acc.bank || 0, `Купил «${a.item}»: −${a.price} ₽`);
      setMoney(p, (p.acc.cash || 0) + a.price, p.acc.bank || 0, `Продал «${a.item}»: +${a.price} ₽`);
      audit('сделка', `${p.acc.nick} → ${q.acc.nick}: «${a.item}» за ${a.price} ₽`, [p.acc.nick, q.acc.nick]);
    }
    send(p, { t: 'trade_done', item: a.item, sold: true, who: q.acc.nick });
    send(q, { t: 'trade_done', item: a.item, sold: false, who: p.acc.nick });
  } else if (a.kind === 'med') {
    if ((q.acc.cash || 0) < 500) return notice(q, 'Нужно 500 ₽ наличными');
    setMoney(q, q.acc.cash - 500, q.acc.bank || 0, 'Медкарта: −500 ₽');
    setMoney(p, (p.acc.cash || 0) + 500, p.acc.bank || 0, `${q.acc.nick} оплатил медосмотр`);
    send(q, { t: 'act', from: p.id, name: p.acc.nick, kind: 'medcard' });
  } else if (a.kind === 'gun') {
    if ((q.acc.cash || 0) < 3000) return notice(q, 'Нужно 3000 ₽ наличными');
    setMoney(q, q.acc.cash - 3000, q.acc.bank || 0, 'Лицензия на оружие: −3000 ₽');
    addBudget(3000, `лицензия ${q.acc.nick}`);
    send(q, { t: 'act', from: p.id, name: p.acc.nick, kind: 'gunlic' });
  } else if (a.kind === 'ticket') {
    if ((q.acc.cash || 0) + (q.acc.bank || 0) < a.sum) { notice(p, `${q.acc.nick} нечем платить — объяви в розыск (/su)`); return notice(q, 'Не хватает денег на штраф'); }
    const c = Math.min(q.acc.cash || 0, a.sum);
    setMoney(q, (q.acc.cash || 0) - c, (q.acc.bank || 0) - (a.sum - c), `Штраф ${a.sum} ₽ оплачен (${a.why})`);
    addBudget(a.sum, `штраф ${q.acc.nick}: ${a.why}`);
    notice(p, `${q.acc.nick} оплатил штраф ${a.sum} ₽ — деньги ушли в казну`);
    audit('штраф', `${p.acc.nick} → ${q.acc.nick} ${a.sum} ₽: ${a.why}`, [p.acc.nick, q.acc.nick]);
  } else if (a.kind === 'passport') {
    send(p, { t: 'chat', n: '', x: `Паспорт: ${q.acc.nick}. Организация: ${q.acc.faction || 'нет'}, ранг ${q.acc.rank}`, k: 'info' });
  }
}

// ---------------------------------------------------------------- порт (склад патронов ОПГ), банк, лотерея
// Порт: в западной части Казани склад с патронами. Владеет одна ОПГ — её люди возят ящики (по 50) к себе в общак.
// Захват: 90 с держаться у склада (45 м). Если у склада больше защитников, чем нападающих, — таймер стоит.
const HARBOR = { x: -500, z: 33, r: 45, CAP: 90000, CD: 15 * 60000, BOX: 50, MAX: 400 };
world.port = world.port || { owner: '', ammo: 200 };
world.gstock = world.gstock || {};
let portCap = null;          // { gid, until, by, empty }
let portCd = 0;
function nearPort(p) { return p.s && Math.hypot(p.s[0] - HARBOR.x, p.s[2] - HARBOR.z) < HARBOR.r; }
function portMsg(p) {
  const f = p && p.acc ? p.acc.faction : '';
  return { t: 'port', owner: world.port.owner, ammo: world.port.ammo,
    cap: portCap ? { gid: portCap.gid, left: Math.max(0, Math.round((portCap.until - Date.now()) / 1000)) } : null,
    stock: GANGS.includes(f) ? (world.gstock[f] | 0) : 0 };
}
function portAll() { for (const q of players.values()) if (q.name) send(q, portMsg(q)); }
function savePort() { dbLater('world', { port: world.port }); }
function gangName(g) { return { tyap: 'Тяп-Ляп', universam: 'Универсам', solnce: 'Солнце', kavkaz: 'Кавказ' }[g] || g; }
function onPort(p, m) {
  if (!p.acc) return;
  const f = p.acc.faction, a = String(m.a || '');
  if (a === 'state') return send(p, portMsg(p));
  if (!GANGS.includes(f)) return notice(p, 'Склад порта — дела ОПГ');
  if (a === 'cap') {
    if (!nearPort(p)) return notice(p, 'Ты не у склада');
    if (world.port.owner === f) return notice(p, 'Склад и так ваш');
    if (portCap) return notice(p, 'Склад уже штурмуют');
    if (Date.now() < portCd) return notice(p, `Склад недавно брали. Следующий захват через ${Math.ceil((portCd - Date.now()) / 60000)} мин`);
    portCap = { gid: f, until: Date.now() + HARBOR.CAP, by: p.acc.nick, empty: 0 };
    sendAll({ t: 'chat', n: '', x: `⚠ ${gangName(f)} штурмует склад в порту! Владелец: ${world.port.owner ? gangName(world.port.owner) : 'никто'}`, k: 'faction' },
      q => q.acc && (GANGS.includes(q.acc.faction) || POLICE.includes(q.acc.faction)));
    log(`[порт] захват начал ${p.acc.nick} (${f})`);
    return portAll();
  }
  if (a === 'load') {
    if (world.port.owner !== f) return notice(p, 'Склад не ваш — сначала захватите');
    if (!nearPort(p)) return notice(p, 'Ты не у склада');
    if (p.portBox) return notice(p, 'Ящик уже у тебя в руках');
    if (world.port.ammo < HARBOR.BOX) return notice(p, 'На складе пусто — ждите теплоход');
    world.port.ammo -= HARBOR.BOX; p.portBox = true; savePort();
    send(p, { t: 'port_box', on: true });
    return portAll();
  }
  if (a === 'deliver') {
    if (!p.portBox) return;
    p.portBox = false;
    world.gstock[f] = (world.gstock[f] | 0) + HARBOR.BOX;
    dbLater('world/gstock', { [f]: world.gstock[f] });
    send(p, { t: 'port_box', on: false });
    for (const q of players.values()) if (q.acc && q.acc.faction === f) send(q, { t: 'chat', n: '', x: `${p.acc.nick} привёз ящик патронов в общак (+${HARBOR.BOX}). В общаке: ${world.gstock[f]}`, k: 'faction' });
    return send(p, portMsg(p));
  }
  if (a === 'take') {
    const n = Math.max(1, Math.min(60, m.n | 0));
    const have = world.gstock[f] | 0;
    if (have <= 0) return notice(p, 'В общаке нет патронов — везите из порта');
    const got = Math.min(n, have);
    world.gstock[f] = have - got;
    dbLater('world/gstock', { [f]: world.gstock[f] });
    send(p, { t: 'ammo', n: got });
    return send(p, portMsg(p));
  }
  if (a === 'drop' && p.portBox) {   // ящик потерян (упал, арест, вышел)
    p.portBox = false;
    send(p, { t: 'port_box', on: false });
  }
}
setInterval(() => {   // теплоход понемногу подвозит патроны
  if (world.port.ammo < HARBOR.MAX) { world.port.ammo = Math.min(HARBOR.MAX, world.port.ammo + 5); savePort(); }
  portAll();
}, 60000);
setInterval(() => {   // захват склада
  if (!portCap) return;
  let att = 0, def = 0;
  for (const q of players.values()) {
    if (!q.acc || !nearPort(q) || q.injured) continue;
    if (q.acc.faction === portCap.gid) att++;
    else if (world.port.owner && q.acc.faction === world.port.owner) def++;
  }
  const now = Date.now();
  if (att === 0) {
    portCap.empty += 2;
    if (portCap.empty >= 10) {
      sendAll({ t: 'chat', n: '', x: `Штурм склада сорван: ${gangName(portCap.gid)} ушли из порта`, k: 'faction' }, q => q.acc && GANGS.includes(q.acc.faction));
      portCap = null; portCd = now + 5 * 60000;
      return portAll();
    }
  } else portCap.empty = 0;
  if (def > att) portCap.until += 2000;   // защитников больше — склад держится
  if (now >= portCap.until) {
    const g = portCap.gid;
    world.port.owner = g; savePort();
    sendAll({ t: 'chat', n: '', x: `Склад в порту теперь держит ${gangName(g)}`, k: 'faction' }, q => q.acc && (GANGS.includes(q.acc.faction) || POLICE.includes(q.acc.faction)));
    log(`[порт] склад взяли ${g}`);
    portCap = null; portCd = now + HARBOR.CD;
  }
  portAll();
}, 2000);

// Банк: кредит (до 50 000 ₽, +10 %, на 3 дня), вклад (+1 % в час, не больше +30 %).
const LOAN_MAX = 50000, LOAN_FEE = 0.10, LOAN_DAYS = 3, DEP_RATE = 0.01, DEP_CAP = 0.30;
function bankMsg(p) {
  const a = p.acc;
  return { t: 'bank_st', loan: a.loan ? a.loan.due : 0, until: a.loan ? a.loan.until : 0,
    dep: a.dep ? a.dep.sum : 0, dep_gain: a.dep ? depGain(a.dep) : 0 };
}
function depGain(d) { return Math.floor(d.sum * Math.min(DEP_CAP, DEP_RATE * (Date.now() - d.t) / 3600000)); }
function loanOverdue(p) {
  const a = p.acc;
  if (!a || !a.loan || Date.now() < a.loan.until) return;
  let due = a.loan.due, c = a.cash | 0, b = a.bank | 0;
  const fb = Math.min(b, due); b -= fb; due -= fb;
  const fc = Math.min(c, due); c -= fc; due -= fc;
  if (due <= 0) { a.loan = null; persist(p, { loan: null }); setMoney(p, c, b, 'Банк списал просроченный кредит'); }
  else {   // не хватило — остаток растёт на 10 %, срок ещё сутки
    a.loan = { due: Math.ceil(due * 1.1), until: Date.now() + 86400000 }; persist(p, { loan: a.loan });
    setMoney(p, c, b, `Просрочка кредита! Списано всё, долг ${a.loan.due} ₽ (+10 %)`);
  }
}
function onBank(p, m) {
  if (!p.acc) return;
  const a = p.acc, op = String(m.a || ''), sum = Math.trunc(+m.sum || 0);
  if (op === 'loan') {
    if (a.loan) return notice(p, 'Сначала погаси старый кредит');
    if (!(sum >= 1000 && sum <= LOAN_MAX)) return notice(p, `Кредит: от 1 000 до ${LOAN_MAX} ₽`);
    a.loan = { due: Math.ceil(sum * (1 + LOAN_FEE)), until: Date.now() + LOAN_DAYS * 86400000 };
    persist(p, { loan: a.loan });
    setMoney(p, a.cash | 0, (a.bank | 0) + sum, `Кредит ${sum} ₽ на карту. Вернуть ${a.loan.due} ₽ за ${LOAN_DAYS} дня`);
    log(`[банк] кредит ${a.nick} ${sum}`);
  } else if (op === 'repay') {
    if (!a.loan) return notice(p, 'Кредита нет');
    const pay = Math.min(a.loan.due, (a.bank | 0) + (a.cash | 0));
    if (pay <= 0) return notice(p, 'Нечем платить');
    let b = a.bank | 0, c = a.cash | 0;
    const fb = Math.min(b, pay); b -= fb; c -= pay - fb;
    a.loan.due -= pay;
    if (a.loan.due <= 0) a.loan = null;
    persist(p, { loan: a.loan || null });
    setMoney(p, c, b, a.loan ? `Внесено ${pay} ₽, осталось ${a.loan.due} ₽` : 'Кредит погашен полностью');
  } else if (op === 'dep') {
    if (!(sum >= 1000) || sum > (a.bank | 0)) return notice(p, 'Вклад: от 1 000 ₽ и не больше, чем на карте');
    const old = a.dep ? a.dep.sum + depGain(a.dep) : 0;
    a.dep = { sum: old + sum, t: Date.now() };
    persist(p, { dep: a.dep });
    setMoney(p, a.cash | 0, (a.bank | 0) - sum, `На вклад ${sum} ₽. Растёт на 1 % в час`);
  } else if (op === 'wd') {
    if (!a.dep) return notice(p, 'Вклада нет');
    const total = a.dep.sum + depGain(a.dep);
    a.dep = null; persist(p, { dep: null });
    setMoney(p, a.cash | 0, (a.bank | 0) + total, `Вклад закрыт: ${total} ₽ на карту`);
  }
  send(p, bankMsg(p));
}
setInterval(() => { for (const p of players.values()) if (p.acc) loanOverdue(p); }, 300000);

// Лотерея «Спортлото 3 из 20»: билет 200 ₽, розыгрыш каждые 30 минут (в :00 и :30 по Москве).
const LOTTO_PRICE = 200, LOTTO_MAX = 5;
const lotto = { tickets: [], pool: 10000, last: null };
function lottoNext() { const s = 1800000; return Math.ceil((Date.now() + 1) / s) * s; }
function lottoMsg(p) {
  const key = p.acc ? p.acc.key : '';
  return { t: 'lotto', next: Math.round((lottoNext() - Date.now()) / 1000), pool: lotto.pool,
    my: lotto.tickets.filter(t => t.key === key).map(t => t.nums), last: lotto.last };
}
function onLotto(p, m) {
  if (!p.acc) return;
  if (m.a === 'buy') {
    const nums = Array.isArray(m.nums) ? [...new Set(m.nums.map(x => x | 0))] : [];
    if (nums.length !== 3 || nums.some(x => x < 1 || x > 20)) return notice(p, 'Выбери 3 разных числа от 1 до 20');
    if (lotto.tickets.filter(t => t.key === p.acc.key).length >= LOTTO_MAX) return notice(p, `Не больше ${LOTTO_MAX} билетов на розыгрыш`);
    const c = p.acc.cash | 0, b = p.acc.bank | 0;
    if (c + b < LOTTO_PRICE) return notice(p, 'Не хватает денег на билет');
    const fc = Math.min(c, LOTTO_PRICE);
    setMoney(p, c - fc, b - (LOTTO_PRICE - fc), '');
    lotto.tickets.push({ key: p.acc.key, nick: p.acc.nick, nums: nums.sort((x, y) => x - y) });
    lotto.pool += LOTTO_PRICE / 2;
    addBudget(LOTTO_PRICE / 2, 'лотерея');
  }
  send(p, lottoMsg(p));
}
function lottoDraw() {
  const pool = [...Array(20)].map((_, i) => i + 1);
  const win = [];
  while (win.length < 3) win.push(pool.splice(Math.floor(Math.random() * pool.length), 1)[0]);
  win.sort((x, y) => x - y);
  const jack = lotto.tickets.filter(t => t.nums.filter(x => win.includes(x)).length === 3);
  const winners = [];
  for (const t of lotto.tickets) {
    const hit = t.nums.filter(x => win.includes(x)).length;
    let prize = hit === 2 ? 1000 : hit === 1 ? 200 : 0;
    if (hit === 3) prize = Math.floor(lotto.pool / jack.length);
    if (!prize) continue;
    winners.push([t.nick, prize]);
    for (const q of players.values()) if (q.acc && q.acc.key === t.key) {
      setMoney(q, q.acc.cash | 0, (q.acc.bank | 0) + prize, `Спортлото: угадано ${hit} из 3 — выигрыш ${prize} ₽ на карту`);
    }
    // кто вышел — выигрыш сгорает (купил билет — жди розыгрыша в игре)
  }
  if (jack.length) lotto.pool = 10000;
  lotto.last = { nums: win, winners: winners.sort((a, b) => b[1] - a[1]).slice(0, 5) };
  const big = winners.length ? ` Лучший выигрыш: ${winners[0][0]} — ${winners[0][1]} ₽` : '';
  if (lotto.tickets.length) sendAll({ t: 'chat', n: '', x: `Спортлото: выпали ${win.join(', ')}. Билетов: ${lotto.tickets.length}.${big}`, k: 'ad' });
  lotto.tickets = [];
}
(function lottoTimer() { setTimeout(() => { lottoDraw(); lottoTimer(); }, lottoNext() - Date.now() + 500); })();

function onTurf(p, m) {
  if (!p.acc || !GANGS.includes(p.acc.faction)) return;
  const key = String(m.key || '');
  if (!/^[kp]:-?\d+,-?\d+$/.test(key) || m.gid !== p.acc.faction) return;
  world.turf[key] = p.acc.faction;
  dbLater('world/turf', { [key]: p.acc.faction });
  sendAll({ t: 'turf', map: { [key]: p.acc.faction } });
  log(`район ${key} взят: ${p.acc.faction} (${p.acc.nick})`);
}

function onHome(p, m) {
  if (!p.acc) return;
  const i = m.i | 0;
  if (i < 0 || i > 5000) return;
  if (m.buy) {
    if (world.homes[i] && world.homes[i] !== p.acc.key) {
      p.sale += Math.min(Math.max(0, m.price | 0), 5000000);   // клиент вернёт деньги за занятое жильё
      return send(p, { t: 'home_res', i, ok: false, msg: 'Это жильё уже занято другим игроком' });
    }
    if (p.acc.home >= 0 && p.acc.home !== i && world.homes[p.acc.home] === p.acc.key) {
      delete world.homes[p.acc.home];
      dbLater('world/homes', { [p.acc.home]: null });
    }
    world.homes[i] = p.acc.key;
    p.acc.home = i;
    dbLater('world/homes', { [i]: p.acc.key });
    persist(p, { home: i });
    send(p, { t: 'home_res', i, ok: true });
  } else if (world.homes[i] === p.acc.key) {
    p.sale += Math.min(Math.max(0, m.price | 0) / 2, 2000000);   // продажа своего дома — законный большой доход
    delete world.homes[i];
    p.acc.home = -1;
    dbLater('world/homes', { [i]: null });
    persist(p, { home: -1 });
  }
  sendAll({ t: 'homes_upd', i, taken: !!world.homes[i] }, q => q !== p);
}

// ---------------------------------------------------------------- бизнесы (ларьки, магазины, АЗС) — общие на сервер
const MAX_BIZ = 3;
function bizMap(p) {
  const o = {};
  for (const i of Object.keys(world.biz)) if (!p.acc || world.biz[i].k !== p.acc.key) o[i] = world.biz[i].n;
  return o;
}
function onBiz(p, m) {
  if (!p.acc) return;
  const i = m.i | 0;
  if (i < 0 || i > 5000) return;
  const cur = world.biz[i];
  if (m.buy) {
    if (cur && cur.k !== p.acc.key) {
      if (!m.claim) p.sale += Math.min(Math.max(0, m.price | 0), 5000000);   // клиент вернёт деньги
      return send(p, { t: 'biz_res', i, ok: false, claim: !!m.claim, msg: `Этот бизнес уже принадлежит игроку ${cur.n}` });
    }
    const mine = Object.keys(world.biz).filter(j => world.biz[j].k === p.acc.key && +j !== i).length;
    if (mine >= MAX_BIZ) {
      if (!m.claim) p.sale += Math.min(Math.max(0, m.price | 0), 5000000);
      return send(p, { t: 'biz_res', i, ok: false, claim: !!m.claim, msg: `Больше ${MAX_BIZ} бизнесов иметь нельзя` });
    }
    world.biz[i] = { k: p.acc.key, n: p.acc.nick };
    dbLater('world/biz', { [i]: world.biz[i] });
    send(p, { t: 'biz_res', i, ok: true });
    if (!cur) log(`бизнес ${i} куплен: ${p.acc.nick}`);
  } else if (cur && cur.k === p.acc.key) {
    delete world.biz[i];
    dbLater('world/biz', { [i]: null });
  } else return;
  sendAll({ t: 'biz_upd', i, n: world.biz[i] ? world.biz[i].n : '' }, q => q !== p);
}

// ---------------------------------------------------------------- время и погода (одни на всех)
const DAY_EPOCH = 1794600000;       // начало отсчёта игровых дней
// погода по сезону (московский месяц): зимой снег, летом без снега, весной и в ноябре — всё вперемешку
const WEATHERS = {
  winter: ['clear', 'cloudy', 'cloudy', 'snow', 'snow', 'snow'],
  edge: ['clear', 'cloudy', 'cloudy', 'rain', 'rain', 'snow'],
  warm: ['clear', 'clear', 'clear', 'cloudy', 'cloudy', 'rain', 'rain'],
};
function worldMsg() {
  const s = Date.now() / 1000;
  const min = s % 1440;            // 1 реальная секунда = 1 игровая минута
  const day = Math.floor((s - DAY_EPOCH) / 1440) + 1;
  const period = Math.floor(s / 420);
  const h = crypto.createHash('md5').update('w' + period).digest()[0];
  const month = new Date(Date.now() + 3 * 3600000).getUTCMonth() + 1;
  const list = [12, 1, 2].includes(month) ? WEATHERS.winter : [3, 11].includes(month) ? WEATHERS.edge : WEATHERS.warm;
  return { t: 'world', min, day, weather: list[h % list.length], tax: world.tax || 0 };
}
setInterval(() => sendAll(worldMsg()), 15000);

// ---------------------------------------------------------------- чат и команды
const HELP = [
  'Чат: обычный текст — рядом · /s крик · /w шёпот · /b OOC · /me /do /try /todo фраза*действие · /pm ник текст · /g всем · /ad объявление',
  'Фракции: /r рация · /d госволна · /f чат. Документы: /pass /lic /med ID. /id ник — узнать ID · /budget — казна · /report текст',
  'Милиция/КГБ: /cuff /uncuff /follow /search ID · /ticket ID сумма причина · /su ID звёзды причина · /givegun ID.  Врач: /givemed ID · /revive ID',
  'Семья: /fcreate Название · /finvite ID · /fam текст · /finfo · /fput /ftake сумма · /fkick ник · /fleave.  Телефон: /sms ID текст · /call ID · /t текст · /h',
  'Суд (мэрия 3+): /sentence ID минуты статья · /free ID.  Выборы: /election · /candidate · /vote ник.  Мэр: /tax 0–20 · /payout фракция сумма',
  'Лидер: /rank ник N · /uninvite ник · /roster.  Админ: /help admin',
].join('\n');
const REPORTS = [];
let reportSeq = 0;

// панель администратора в телефоне: игроки онлайн и открытые репорты
function onAdminPanel(p) {
  if (!admin(p)) return;
  const list = [];
  for (const q of players.values()) if (q.name && q.acc) {
    list.push([q.acc.nick, q.acc.faction || '', q.acc.warns | 0, admin(q), (q.acc.muted || 0) > Date.now(), !!q.frozen, q.acc.cash | 0]);
  }
  list.sort((a, b) => a[0].localeCompare(b[0]));
  const reps = REPORTS.filter(r => !r.done).slice(-10).map(r => [r.id, r.nick, r.text, Math.round((Date.now() - r.t) / 60000)]);
  send(p, { t: 'adm', lvl: admin(p), players: list, reports: reps });
}

const HELP_ADMIN = [
  '/a текст — админ-чат · /ann текст — объявление · /kick ник · /ban ник причина · /unban ник',
  '/givemoney ник сумма · /tp ник · /tphere ник · /makeleader ник фракция · /setadmin ник 0-5 · /mute ник минуты',
  '/event (3+) · /reports · /ans ник текст (ответ на репорт) · /warn ник причина (3 = бан 3 дня) · /logs [ник] · /hp ник · /freeze ник',
].join('\n');

async function onSay(p, m) {
  if (!p.acc || !p.name) return;
  const now = Date.now();
  if (now - p.chatT < 700) return;
  p.chatT = now;
  const x = cleanText(m.x);
  if (!x) return;
  if (p.acc.muted && p.acc.muted > now) return notice(p, `Чат заблокирован ещё на ${Math.ceil((p.acc.muted - now) / 60000)} мин`);
  if (x[0] !== '/') return localChat(p, `${p.acc.nick}: ${x}`, 'say', CHAT_DIST);
  const sp = x.indexOf(' ');
  const cmd = (sp < 0 ? x : x.slice(0, sp)).toLowerCase();
  const rest = sp < 0 ? '' : x.slice(sp + 1).trim();
  const arg = rest.split(/\s+/);
  const lvl = admin(p);
  switch (cmd) {
    case '/help': return notice(p, arg[0] === 'admin' && lvl ? HELP_ADMIN : HELP);
    case '/g': return rest && sendAll({ t: 'chat', n: p.acc.nick, x: rest, k: 'shout' });
    case '/me': return rest && localChat(p, `* ${p.acc.nick} ${rest}`, 'me', CHAT_DIST);
    case '/do': return rest && localChat(p, `* ${rest} (${p.acc.nick})`, 'me', CHAT_DIST);
    case '/try': return rest && localChat(p, `* ${p.acc.nick} ${rest} — ${Math.random() < 0.5 ? 'удачно' : 'неудачно'}`, 'me', CHAT_DIST);
    case '/f':
      if (!p.acc.faction) return notice(p, 'Ты не в организации');
      return rest && factionChat(p.acc.faction, p.acc.nick, rest);
    case '/pm': {
      const q = byNick(arg[0]);
      const txt = rest.slice((arg[0] || '').length).trim();
      if (!q || !txt) return notice(p, 'Использование: /pm ник текст (игрок должен быть онлайн)');
      send(q, { t: 'chat', n: `ЛС от ${p.acc.nick}`, x: txt, k: 'pm' });
      return send(p, { t: 'chat', n: `ЛС для ${q.acc.nick}`, x: txt, k: 'pm' });
    }
    case '/report':
      if (!rest) return notice(p, '/report текст');
      if (REPORTS.filter(r => r.nick === p.acc.nick && !r.done).length >= 3) return notice(p, 'У тебя уже 3 открытых репорта — дождись ответа');
      REPORTS.push({ id: ++reportSeq, nick: p.acc.nick, text: rest.slice(0, 200), t: now, done: false });
      if (REPORTS.length > 100) REPORTS.shift();
      audit('репорт', `${p.acc.nick}: ${rest}`, [p.acc.nick]);
      sendAll({ t: 'chat', n: `Репорт от ${p.acc.nick}`, x: rest, k: 'admin' }, q => admin(q) >= 1);
      return notice(p, 'Репорт отправлен администрации');
    case '/roster': return onRoster(p);
    case '/rank': {
      const q = byNick(arg[0]); const r = parseInt(arg[1], 10);
      if (!(isLeader(p) || lvl >= 3)) return notice(p, 'Только лидер организации');
      if (!q || !r || r < 1) return notice(p, 'Использование: /rank ник ранг (игрок онлайн)');
      if (lvl < 3 && (q.acc.faction !== p.acc.faction || r >= p.acc.rank)) return notice(p, 'Можно ставить ранг ниже своего и только своим');
      setFaction(q, q.acc.faction, r, `Тебе установлен ранг ${r}`);
      return factionChat(q.acc.faction, '', `${p.acc.nick} установил ${q.acc.nick} ранг ${r}`);
    }
    case '/uninvite': {
      if (!(isLeader(p) || lvl >= 3)) return notice(p, 'Только лидер организации');
      const key = accKey(arg[0] || '');
      const fid = lvl >= 3 && !p.acc.faction ? null : p.acc.faction;
      const q = byNick(arg[0]);
      if (q) {
        if (fid && q.acc.faction !== fid) return notice(p, 'Игрок не в твоей организации');
        factionChat(q.acc.faction, '', `${q.acc.nick} уволен (${p.acc.nick})`);
        return setFaction(q, '', 0, 'Тебя уволили из организации');
      }
      if (fid && world.members[fid] && world.members[fid][key]) {   // уволить того, кто не в игре
        delete world.members[fid][key];
        dbLater(`world/members/${fid}`, { [key]: null });
        dbLater('accounts/' + key, { faction: '', rank: 0 });
        return factionChat(fid, '', `${arg[0]} уволен (${p.acc.nick})`);
      }
      return notice(p, 'Игрок не найден');
    }
  }
  if (rpCommand(p, cmd, arg, rest, lvl) || rpCommand2(p, cmd, arg, rest, lvl)) return;   // RP-команды — для всех игроков
  if (!lvl) return notice(p, 'Неизвестная команда. /help — список');
  switch (cmd) {
    case '/a': return sendAll({ t: 'chat', n: `[A] ${p.acc.nick}`, x: rest, k: 'admin' }, q => admin(q) >= 1);
    case '/ann': return rest && sendAll({ t: 'chat', n: 'ОБЪЯВЛЕНИЕ', x: rest, k: 'admin' });
    case '/kick': {
      const q = byNick(arg[0]);
      if (!q || admin(q) >= lvl) return notice(p, 'Нельзя');
      send(q, { t: 'kicked', msg: `Кик от администратора ${p.acc.nick}` });
      audit('кик', `${q.acc.nick} — админ ${p.acc.nick}`, [q.acc.nick, p.acc.nick]);
      return drop(q);
    }
    case '/ban': {
      if (lvl < 2) return notice(p, 'Нужен 2 уровень админки');
      const key = accKey(arg[0] || '');
      const reason = rest.slice((arg[0] || '').length).trim() || 'нарушение правил';
      const q = byNick(arg[0]);
      if (q && admin(q) >= lvl) return notice(p, 'Нельзя');
      await dbPatch('accounts/' + key, { banned: true, ban_reason: reason }).catch(() => {});
      if (q) { send(q, { t: 'kicked', msg: 'Бан: ' + reason }); drop(q); }
      audit('бан', `${arg[0]} — админ ${p.acc.nick}: ${reason}`, [arg[0], p.acc.nick]);
      return sendAll({ t: 'chat', n: '', x: `${arg[0]} забанен администратором ${p.acc.nick}: ${reason}`, k: 'admin' });
    }
    case '/unban':
      if (lvl < 2) return notice(p, 'Нужен 2 уровень админки');
      await dbPatch('accounts/' + accKey(arg[0] || ''), { banned: null, ban_reason: null, ban_until: null }).catch(() => {});
      return notice(p, `${arg[0]} разбанен`);
    case '/mute': {
      const q = byNick(arg[0]); const mins = Math.max(1, Math.min(1440, parseInt(arg[1], 10) || 10));
      if (!q || admin(q) >= lvl) return notice(p, 'Нельзя');
      q.acc.muted = Date.now() + mins * 60000;
      persist(q, { muted: q.acc.muted });
      notice(q, `Чат заблокирован на ${mins} мин администратором ${p.acc.nick}`);
      audit('мут', `${q.acc.nick} на ${mins} мин — админ ${p.acc.nick}`, [q.acc.nick, p.acc.nick]);
      return notice(p, 'Готово');
    }
    case '/givemoney': {
      if (lvl < 4) return notice(p, 'Нужен 4 уровень админки');
      const q = byNick(arg[0]); const sum = parseInt(arg[1], 10);
      if (!q || !sum) return notice(p, '/givemoney ник сумма (игрок онлайн)');
      setMoney(q, Math.max(0, (q.acc.cash || 0) + sum), q.acc.bank || 0, `Администратор выдал ${sum} ₽`);
      audit('выдача', `${sum} ₽ → ${q.acc.nick} — админ ${p.acc.nick}`, [q.acc.nick, p.acc.nick]);
      return notice(p, 'Готово');
    }
    case '/tp': {
      const q = byNick(arg[0]);
      if (!q || !q.s) return notice(p, 'Игрок не найден');
      return send(p, { t: 'tp', x: q.s[0] + 1.5, y: q.s[1] + 0.5, z: q.s[2] });
    }
    case '/tphere': {
      const q = byNick(arg[0]);
      if (!q || !p.s) return notice(p, 'Игрок не найден');
      return send(q, { t: 'tp', x: p.s[0] + 1.5, y: p.s[1] + 0.5, z: p.s[2] });
    }
    case '/makeleader': {
      if (lvl < 3) return notice(p, 'Нужен 3 уровень админки');
      const q = byNick(arg[0]); const fid = arg[1];
      if (!q || !FACTIONS.includes(fid)) return notice(p, '/makeleader ник фракция (' + FACTIONS.join(', ') + ')');
      setFaction(q, fid, 99);
      world.leaders[fid] = q.acc.key;
      audit('лидер', `${q.acc.nick} → лидер ${fid} — админ ${p.acc.nick}`, [q.acc.nick, p.acc.nick]);
      dbLater('world/leaders', { [fid]: q.acc.key });
      send(q, { t: 'faction_set', fid, rank: 99, leader: true, msg: 'Ты назначен лидером организации!' });
      return sendAll({ t: 'chat', n: '', x: `${q.acc.nick} назначен лидером «${fid}»`, k: 'admin' });
    }
    case '/setadmin': {
      if (lvl < 5) return notice(p, 'Только владелец сервера');
      const q = byNick(arg[0]); const l = Math.max(0, Math.min(4, parseInt(arg[1], 10) || 0));
      if (!q) return notice(p, 'Игрок должен быть онлайн');
      q.acc.admin = l;
      audit('админка', `${q.acc.nick}: уровень ${l} — ${p.acc.nick}`, [q.acc.nick, p.acc.nick]);
      persist(q, { admin: l });
      send(q, { t: 'prof', prof: profile(q) });
      return notice(p, `${q.acc.nick}: админка ${l}`);
    }
  }
  return adminExtra(p, cmd, arg, rest, lvl);
}

// Команды администрации, добавленные к основным: ответ на репорт, предупреждения, журнал, лечение, заморозка.
async function adminExtra(p, cmd, arg, rest, lvl) {
  switch (cmd) {
    case '/ans': {
      const q = byNick(arg[0]); const txt = rest.slice((arg[0] || '').length).trim();
      if (!q || !txt) return notice(p, '/ans ник текст — ответ на репорт');
      send(q, { t: 'chat', n: `Администратор ${p.acc.nick}`, x: txt, k: 'pm' });
      for (const r of REPORTS) if (r.nick === q.acc.nick && !r.done) { r.done = true; r.by = p.acc.nick; }
      audit('ответ', `${p.acc.nick} → ${q.acc.nick}: ${txt}`, [p.acc.nick, q.acc.nick]);
      return notice(p, 'Ответ отправлен');
    }
    case '/warn': {
      const q = byNick(arg[0]); const reason = rest.slice((arg[0] || '').length).trim() || 'нарушение правил';
      if (!q || admin(q) >= lvl) return notice(p, '/warn ник причина (игрок онлайн)');
      q.acc.warns = (q.acc.warns | 0) + 1;
      persist(q, { warns: q.acc.warns });
      audit('варн', `${q.acc.nick} (${q.acc.warns}/3) — админ ${p.acc.nick}: ${reason}`, [q.acc.nick, p.acc.nick]);
      if (q.acc.warns >= 3) {   // третье предупреждение — бан на 3 дня
        const until = Date.now() + 3 * 86400000;
        q.acc.warns = 0;
        persist(q, { warns: 0, ban_until: until, ban_reason: '3 предупреждения: ' + reason });
        send(q, { t: 'kicked', msg: 'Бан на 3 дня: 3 предупреждения (' + reason + ')' });
        drop(q);
        return sendAll({ t: 'chat', n: '', x: `${arg[0]} получил 3/3 предупреждения и забанен на 3 дня`, k: 'admin' });
      }
      notice(q, `Предупреждение ${q.acc.warns}/3 от администратора ${p.acc.nick}: ${reason}. На третьем — бан на 3 дня.`);
      return notice(p, `Выдано: ${q.acc.warns}/3`);
    }
    case '/event': {   // запустить событие сейчас (для проверки)
      if (lvl < 3) return notice(p, 'Нужен 3 уровень админки');
      if (ev) endEvent(null);
      startEvent();
      return notice(p, 'Событие запущено: ' + ev.title);
    }
    case '/reports': {
      const open = REPORTS.filter(r => !r.done);
      if (!open.length) return notice(p, 'Открытых репортов нет');
      return notice(p, open.slice(-8).map(r => `#${r.id} ${r.nick}: ${r.text}`).join('\n'));
    }
    case '/logs': {
      const who = (arg[0] || '').toLowerCase();
      const list = AUDIT.filter(e => !who || e.nicks.includes(who)).slice(-12);
      if (!list.length) return notice(p, 'В журнале пусто' + (who ? ' по этому игроку' : ''));
      return notice(p, list.map(e => `${new Date(e.t + 3 * 3600000).toISOString().slice(11, 16)} ${e.kind}: ${e.text}`).join('\n'));
    }
    case '/hp': {
      const q = byNick(arg[0]);
      if (!q) return notice(p, '/hp ник — вылечить');
      send(q, { t: 'act', from: p.id, name: p.acc.nick, kind: 'admin_heal' });
      audit('лечение', `${q.acc.nick} — админ ${p.acc.nick}`, [q.acc.nick, p.acc.nick]);
      return notice(p, 'Готово');
    }
    case '/freeze': {
      const q = byNick(arg[0]);
      if (!q || admin(q) >= lvl) return notice(p, '/freeze ник — заморозить / разморозить');
      q.frozen = !q.frozen;
      send(q, { t: 'act', from: p.id, name: p.acc.nick, kind: q.frozen ? 'freeze' : 'unfreeze' });
      audit('заморозка', `${q.acc.nick}: ${q.frozen ? 'заморожен' : 'разморожен'} — админ ${p.acc.nick}`, [q.acc.nick, p.acc.nick]);
      return notice(p, q.frozen ? 'Заморожен' : 'Разморожен');
    }
  }
  return notice(p, 'Неизвестная команда. /help admin');
}

// ---------------------------------------------------------------- база данных милиции/КГБ и вызовы по рации
// Пульт в милиции и КГБ: кто сейчас в городе, где (район считает телефон по координатам), в розыске ли.
// Сотрудники КГБ для милиции «не числятся»: их фракция скрыта.
function onLookup(p) {
  if (!p.acc || !POLICE.includes(p.acc.faction)) return notice(p, 'Нет доступа к базе');
  if (Date.now() - (p.lookT || 0) < 3000) return;
  p.lookT = Date.now();
  const kgb = p.acc.faction === 'kgb';
  const list = [];
  for (const q of players.values()) {
    if (!q.name || !q.acc || q === p) continue;
    const s = q.s || [0, 0, 0];
    const fac = q.acc.faction === 'kgb' && !kgb ? '' : (q.acc.faction || '');
    list.push([q.acc.nick, fac, (s[8] | 0), (s[9] | 0), Math.round(s[0]), Math.round(s[2]), s[6] ? 1 : 0,
      Math.round((Date.now() - (q.joinT || Date.now())) / 60000)]);
  }
  list.sort((a, b) => b[2] - a[2] || a[0].localeCompare(b[0]));
  send(p, { t: 'lookup', list: list.slice(0, 60) });
}

// Вызов милиции по рации (мэрия, больница, пожарные, КГБ): всем милиционерам — точка на карте.
const CALLS = new Map();
let callSeq = 0;
function onCall(p, m) {
  if (!p.acc || !p.acc.faction || GANGS.includes(p.acc.faction)) return notice(p, 'Рация есть только у госслужб');
  if (Date.now() - (p.callT || 0) < 30000) return notice(p, 'Рация занята — подожди полминуты');
  p.callT = Date.now();
  const x = +m.x, z = +m.z;
  if (!Number.isFinite(x) || !Number.isFinite(z)) return;
  const id = ++callSeq;
  const text = String(m.text || '').slice(0, 120);
  CALLS.set(id, { id, from: p.acc.nick, fac: p.acc.faction, x, z, text, t: Date.now(), taken: '' });
  for (const [k, c] of CALLS) if (Date.now() - c.t > 15 * 60000) CALLS.delete(k);
  let cops = 0;
  for (const q of players.values()) if (q.acc && POLICE.includes(q.acc.faction) && q !== p) {
    send(q, { t: 'call', id, from: p.acc.nick, fac: p.acc.faction, x, z, text });
    cops++;
  }
  audit('вызов', `${p.acc.nick} (${p.acc.faction}): ${text || 'без текста'}`, [p.acc.nick]);
  notice(p, cops ? `Вызов передан. Милиционеров в городе: ${cops}` : 'Вызов записан, но сейчас в городе нет милиции');
}
function onCallTake(p, m) {
  const c = CALLS.get(m.id | 0);
  if (!p.acc || !(POLICE.includes(p.acc.faction) || MEDIC.includes(p.acc.faction)) || !c) return;
  if (c.taken) return notice(p, `Вызов уже принял ${c.taken}`);
  c.taken = p.acc.nick;
  for (const q of players.values()) if (q.acc && (q.acc.nick === c.from || POLICE.includes(q.acc.faction) || MEDIC.includes(q.acc.faction)))
    send(q, { t: 'call_taken', id: c.id, by: p.acc.nick, from: c.from });
}

// ---------------------------------------------------------------- RP-команды (как на CRMP)
// Ник — Имя_Фамилия. Чаты: /b (OOC), /s (крик), /w (шёпот), /todo, /r (рация фракции), /d (госволна), /ad (газета).
// Документы: /pass /lic /med ник — показать; врач выдаёт медкарту (/givemed), милиция — лицензию на оружие (/givegun).
// Милиция и КГБ: /cuff /uncuff /follow /search /ticket /su. Врачи поднимают раненых (/revive), вызовы приходят по рации.
const STATE = ['mayor', 'police', 'police_p', 'hospital', 'hospital_p', 'fire', 'kgb'];
const RP_NICK = /^[A-ZА-ЯЁ][a-zа-яё]{1,14}_[A-ZА-ЯЁ][a-zа-яё]{1,16}$/;
const FAC_TAG = { mayor: 'Мэрия', police: 'Милиция', police_p: 'Милиция ПТГ', hospital: 'Больница', hospital_p: 'Больница ПТГ',
  fire: 'Пожарные', kgb: 'КГБ', tyap: 'Тяп-Ляп', universam: 'Универсам', solnce: 'Солнечные', kavkaz: 'Кавказ' };
world.budget = world.budget || 0;

// игрок по нику или по ID (как на CRMP: /cuff 12)
function target(s) {
  const t = String(s || '');
  if (/^\d+$/.test(t)) { const q = players.get(+t); return q && q.acc ? q : null; }
  return byNick(t);
}
function addBudget(n, why) {
  world.budget = (world.budget || 0) + n;
  dbLater('world', { budget: world.budget });
  if (why) audit('казна', `+${n} ₽: ${why}`, []);
}
function docCard(p) {
  const d = p.docs || {};
  return d;
}
function rpCommand(p, cmd, arg, rest, lvl) {
  const nick = p.acc.nick;
  const fac = p.acc.faction || '';
  const q = target(arg[0]);
  const tail = rest.slice((arg[0] || '').length).trim();
  switch (cmd) {
    case '/b': return rest ? (localChat(p, `(( ${nick} [${p.id}]: ${rest} ))`, 'ooc', CHAT_DIST), true) : (notice(p, '/b текст — OOC-чат (не от лица персонажа)'), true);
    case '/s': return rest ? (localChat(p, `${nick} кричит: ${rest}!`, 'say', CHAT_DIST * 2), true) : true;
    case '/w': return rest ? (localChat(p, `${nick} шепчет: ${rest}`, 'whisper', 4), true) : true;
    case '/todo': {
      const i = rest.indexOf('*');
      if (i < 1) return notice(p, '/todo фраза*действие — например: /todo Держи*протягивая паспорт'), true;
      localChat(p, `«${rest.slice(0, i).trim()}» — сказал ${nick}, ${rest.slice(i + 1).trim()}`, 'me', CHAT_DIST);
      return true;
    }
    case '/r':
      if (!fac) return notice(p, 'Ты не в организации'), true;
      if (rest) factionChat(fac, `[R] ${nick}`, rest);
      return true;
    case '/d': {
      if (!STATE.includes(fac)) return notice(p, 'Госволна — только для госслужб'), true;
      if (!rest) return true;
      for (const r of players.values()) if (r.acc && STATE.includes(r.acc.faction))
        send(r, { t: 'chat', n: `[${FAC_TAG[fac]}] ${nick}`, x: rest, k: 'dep' });
      return true;
    }
    case '/ad': {
      if (!rest) return notice(p, '/ad текст — объявление в газету «Вечерний город» (200 ₽)'), true;
      if (Date.now() - (p.adT || 0) < 60000) return notice(p, 'Новое объявление — не чаще раза в минуту'), true;
      if ((p.acc.cash || 0) < 200) return notice(p, 'Объявление стоит 200 ₽ наличными'), true;
      p.adT = Date.now();
      setMoney(p, p.acc.cash - 200, p.acc.bank || 0, 'Объявление в газету: −200 ₽');
      addBudget(200, '');
      sendAll({ t: 'chat', n: `Объявление (${nick})`, x: rest.slice(0, 150), k: 'ad' });
      return true;
    }
    case '/id': {
      const list = [...players.values()].filter(r => r.acc && r.name && r.acc.nick.toLowerCase().includes(String(arg[0] || '').toLowerCase()));
      notice(p, list.length ? list.slice(0, 8).map(r => `${r.acc.nick} [${r.id}]`).join(' · ') : 'Никого не нашёл');
      return true;
    }
    case '/budget': notice(p, `Казна города: ${world.budget || 0} ₽ (штрафы, налоги, объявления)`); return true;
    // ---------------- документы
    case '/pass': case '/lic': case '/med': {
      if (!q || q === p) return notice(p, `${cmd} ник или ID — показать документ игроку рядом`), true;
      if (!near(p, q, 5)) return notice(p, 'Подойди ближе'), true;
      const d = p.docs || {};
      let text;
      if (cmd === '/pass') text = `Паспорт гражданина СССР: ${d.name || nick}. Прописка: ${d.city || 'Казань'}. Организация: ${FAC_TAG[fac] || 'не работает'}`;
      else if (cmd === '/lic') text = `Права: ${(d.lic || []).length ? d.lic.join(', ') : 'нет'}. Лицензия на оружие: ${d.gun ? 'есть' : 'нет'}`;
      else text = `Медкарта: ${d.med ? 'здоров, годен' : 'нет медкарты'}`;
      localChat(p, `* ${nick} показал документ ${q.acc.nick}`, 'me', 15);
      send(q, { t: 'chat', n: `Документ ${nick}`, x: text, k: 'doc' });
      send(p, { t: 'chat', n: `Ты показал ${q.acc.nick}`, x: text, k: 'doc' });
      return true;
    }
    case '/givemed': {
      if (!MEDIC.includes(fac)) return notice(p, 'Медкарту выдаёт врач'), true;
      if (!q || !near(p, q, 5)) return notice(p, '/givemed ник или ID (игрок рядом)'), true;
      askPlayer(p, q, 'med', `Врач ${nick} проводит медосмотр и оформляет медкарту (500 ₽). Согласен?`);
      return true;
    }
    case '/givegun': {
      if (!POLICE.includes(fac) || (p.acc.rank | 0) < 3) return notice(p, 'Лицензию выдаёт милиция с 3 ранга'), true;
      if (!q || !near(p, q, 5)) return notice(p, '/givegun ник или ID (игрок рядом)'), true;
      askPlayer(p, q, 'gun', `${nick} оформляет лицензию на оружие (3000 ₽). Согласен?`);
      return true;
    }
    // ---------------- милиция
    case '/cuff': case '/uncuff': case '/follow': case '/search': case '/su': case '/ticket': {
      if (!POLICE.includes(fac)) return notice(p, 'Это может только милиция или КГБ'), true;
      if (!q || q === p) return notice(p, `${cmd} ник или ID`), true;
      if (cmd !== '/su' && !near(p, q, 4)) return notice(p, 'Подойди ближе'), true;
      if (cmd === '/cuff') { q.cuffed = p.id; send(q, { t: 'act', from: p.id, name: nick, kind: 'cuff' }); localChat(p, `* ${nick} надел наручники на ${q.acc.nick}`, 'me', 20); }
      else if (cmd === '/uncuff') { q.cuffed = 0; q.follow = 0; send(q, { t: 'act', from: p.id, name: nick, kind: 'uncuff' }); localChat(p, `* ${nick} снял наручники с ${q.acc.nick}`, 'me', 20); }
      else if (cmd === '/follow') {
        if (q.cuffed !== p.id) return notice(p, 'Сначала надень наручники (/cuff)'), true;
        q.follow = q.follow === p.id ? 0 : p.id;
        send(q, { t: 'act', from: p.id, name: nick, kind: q.follow ? 'follow' : 'unfollow' });
        localChat(p, `* ${nick} ${q.follow ? 'повёл за собой' : 'отпустил'} ${q.acc.nick}`, 'me', 20);
      } else if (cmd === '/search') {
        p.searchT = Date.now();
        send(q, { t: 'act', from: p.id, name: nick, kind: 'search' });
        localChat(p, `* ${nick} обыскивает ${q.acc.nick}`, 'me', 20);
      } else if (cmd === '/su') {
        const st = Math.max(1, Math.min(5, parseInt(arg[1], 10) || 1));
        const why = rest.split(/\s+/).slice(2).join(' ') || 'нарушение';
        send(q, { t: 'act', from: p.id, name: nick, kind: 'su', stars: st, why });
        sendAll({ t: 'chat', n: '', x: `${nick} объявил в розыск ${q.acc.nick} (${'★'.repeat(st)}): ${why}`, k: 'faction' }, r => r.acc && POLICE.includes(r.acc.faction));
        audit('розыск', `${nick} → ${q.acc.nick} ${st}★: ${why}`, [nick, q.acc.nick]);
      } else if (cmd === '/ticket') {
        const sum = parseInt(arg[1], 10);
        const why = rest.split(/\s+/).slice(2).join(' ') || 'нарушение';
        if (!(sum >= 100 && sum <= 5000)) return notice(p, '/ticket ник сумма(100–5000) причина'), true;
        askPlayer(p, q, 'ticket', `${nick} выписал штраф ${sum} ₽: ${why}. Оплатить? (Отказ — розыск)`, { sum, why });
      }
      return true;
    }
    case '/revive': {
      if (!MEDIC.includes(fac)) return notice(p, 'Поднимает раненых только врач'), true;
      if (!q || !near(p, q, 4)) return notice(p, '/revive ник или ID (раненый рядом)'), true;
      if (!q.injured) return notice(p, 'Этот человек не ранен'), true;
      q.injured = false;
      send(q, { t: 'act', from: p.id, name: nick, kind: 'revive' });
      setMoney(p, p.acc.cash || 0, (p.acc.bank || 0) + 500, `Помощь раненому ${q.acc.nick}: +500 ₽ на карту`);
      localChat(p, `* ${nick} оказал первую помощь ${q.acc.nick}`, 'me', 20);
      audit('реанимация', `${nick} поднял ${q.acc.nick}`, [nick, q.acc.nick]);
      return true;
    }
  }
  return false;
}

// Телефон сообщает: здоровье кончилось — ранен и лежит. Врачи получают вызов.
function onInjured(p, m) {
  if (!p.acc) return;
  p.injured = !!m.on;
  if (!p.injured) return;
  const x = +m.x, z = +m.z;
  if (!Number.isFinite(x) || !Number.isFinite(z)) return;
  const id = ++callSeq;
  CALLS.set(id, { id, from: p.acc.nick, fac: 'hospital', x, z, text: `Ранен ${p.acc.nick} [${p.id}]`, t: Date.now(), taken: '' });
  for (const q of players.values()) if (q.acc && MEDIC.includes(q.acc.faction))
    send(q, { t: 'call', id, from: p.acc.nick, fac: 'hospital', x, z, text: `Ранен ${p.acc.nick} [${p.id}] — нужна помощь`, med: true });
}
// Ответ телефона на обыск: что нашли — милиционеру.
function onSearchRes(p, m) {
  const cop = players.get(m.to | 0);
  if (!cop || !cop.acc || Date.now() - (cop.searchT || 0) > 15000) return;
  const items = Array.isArray(m.items) ? m.items.slice(0, 12).map(s => String(s).slice(0, 40)) : [];
  send(cop, { t: 'chat', n: `Обыск ${p.acc.nick}`, x: items.length ? items.join(', ') : 'ничего запрещённого', k: 'doc' });
}
// Документы с телефона (паспорт, права, лицензии, медкарта) — чтобы показывать их другим.
function onDocs(p, m) {
  if (!p.acc) return;
  p.docs = { name: String(m.name || '').slice(0, 40), city: String(m.city || '').slice(0, 20),
    lic: Array.isArray(m.lic) ? m.lic.slice(0, 4).map(s => String(s).slice(0, 2)) : [], gun: !!m.gun, med: !!m.med };
}

// ---------------------------------------------------------------- семьи, суд и тюрьма, выборы мэра, налоги, телефон, торговля
world.families = world.families || {};
world.tax = world.tax || 0;
let election = null;   // { until, cands: {key: {nick, votes}}, voters: {key: true} }

function famOf(p) { return p.acc && p.acc.family ? world.families[p.acc.family] : null; }
function saveFam(fid) { dbLater('world/families', { [fid]: world.families[fid] || null }); }
function famChat(fid, from, x) {
  for (const q of players.values()) if (q.acc && q.acc.family === fid) send(q, { t: 'chat', n: from, x, k: 'family' });
}
function isJudge(p) {
  return (p.acc.faction === 'mayor' && (p.acc.rank | 0) >= 3) || admin(p) >= 2;
}
function jailMsg(q) {
  const left = Math.ceil(((q.acc.jail_until || 0) - Date.now()) / 1000);
  if (left > 0) send(q, { t: 'act', from: 0, name: 'Народный суд', kind: 'jail', sec: left, why: q.acc.jail_why || '' });
}
function finishElection() {
  if (!election) return;
  const list = Object.entries(election.cands).sort((a, b) => b[1].votes - a[1].votes);
  election = null;
  for (const [key, c] of list) {
    const w = [...players.values()].find(q => q.acc && q.acc.key === key);
    if (!w) continue;
    setFaction(w, 'mayor', 99);
    world.leaders.mayor = key;
    dbLater('world/leaders', { mayor: key });
    send(w, { t: 'faction_set', fid: 'mayor', rank: 99, leader: true, msg: 'Ты избран мэром города!' });
    audit('выборы', `мэр — ${c.nick} (${c.votes} голосов)`, [c.nick]);
    return sendAll({ t: 'chat', n: 'Избирком', x: `Выборы окончены. Мэр города — ${c.nick} (${c.votes} голосов)!`, k: 'ad' });
  }
  sendAll({ t: 'chat', n: 'Избирком', x: 'Выборы не состоялись: никого из кандидатов нет в городе', k: 'ad' });
}
setInterval(() => { if (election && Date.now() > election.until) finishElection(); }, 5000);

function rpCommand2(p, cmd, arg, rest, lvl) {
  const nick = p.acc.nick;
  const q = target(arg[0]);
  const tail = rest.slice((arg[0] || '').length).trim();
  const fam = famOf(p);
  switch (cmd) {
    // ---------------- семьи
    case '/fcreate': {
      if (fam) return notice(p, 'Ты уже в семье (/fleave — выйти)'), true;
      const name = rest.replace(/[^A-Za-zА-Яа-яЁё0-9 _-]/g, '').trim().slice(0, 20);
      if (name.length < 3) return notice(p, '/fcreate Название — создать семью (30 000 ₽ наличными)'), true;
      if (Object.values(world.families).some(f => f.name.toLowerCase() === name.toLowerCase())) return notice(p, 'Семья с таким названием уже есть'), true;
      if ((p.acc.cash || 0) < 30000) return notice(p, 'Создание семьи стоит 30 000 ₽ наличными'), true;
      setMoney(p, p.acc.cash - 30000, p.acc.bank || 0, `Семья «${name}» создана: −30 000 ₽`);
      const fid = 'f' + Date.now().toString(36);
      world.families[fid] = { name, leader: p.acc.key, members: { [p.acc.key]: nick }, bank: 0 };
      p.acc.family = fid; persist(p, { family: fid }); saveFam(fid);
      send(p, { t: 'prof', prof: profile(p) });
      audit('семья', `${nick} создал семью «${name}»`, [nick]);
      sendAll({ t: 'chat', n: '', x: `В городе новая семья — «${name}» (глава ${nick})`, k: 'family' });
      return true;
    }
    case '/finvite':
      if (!fam || fam.leader !== p.acc.key) return notice(p, 'Приглашать может глава семьи'), true;
      if (!q || q === p || q.acc.family) return notice(p, '/finvite ID — игрок без семьи'), true;
      if (!near(p, q, 6)) return notice(p, 'Подойди ближе'), true;
      askPlayer(p, q, 'family', `${nick} зовёт тебя в семью «${fam.name}». Вступить?`, { fid: p.acc.family });
      return true;
    case '/fleave': {
      if (!fam) return notice(p, 'Ты не в семье'), true;
      const fid = p.acc.family;
      delete fam.members[p.acc.key];
      p.acc.family = ''; persist(p, { family: '' });
      send(p, { t: 'prof', prof: profile(p) });
      const rest_ = Object.keys(fam.members);
      if (!rest_.length) { delete world.families[fid]; famChat(fid, '', ''); }
      else if (fam.leader === p.acc.key) { fam.leader = rest_[0]; famChat(fid, '', `${nick} ушёл, глава семьи теперь — ${fam.members[rest_[0]]}`); }
      else famChat(fid, '', `${nick} ушёл из семьи`);
      saveFam(fid);
      return notice(p, 'Ты вышел из семьи'), true;
    }
    case '/fkick': {
      if (!fam || fam.leader !== p.acc.key) return notice(p, 'Выгонять может глава семьи'), true;
      const key = Object.keys(fam.members).find(k => fam.members[k].toLowerCase() === String(arg[0] || '').toLowerCase());
      if (!key || key === p.acc.key) return notice(p, '/fkick ник'), true;
      const who = fam.members[key];
      delete fam.members[key];
      const qq = [...players.values()].find(r => r.acc && r.acc.key === key);
      if (qq) { qq.acc.family = ''; notice(qq, `Тебя исключили из семьи «${fam.name}»`); send(qq, { t: 'prof', prof: profile(qq) }); }
      dbLater('accounts/' + key, { family: '' });
      saveFam(p.acc.family);
      famChat(p.acc.family, '', `${who} исключён из семьи`);
      return true;
    }
    case '/fam':
      if (!fam) return notice(p, 'Ты не в семье'), true;
      if (rest) famChat(p.acc.family, `[${fam.name}] ${nick}`, rest);
      return true;
    case '/finfo':
      if (!fam) return notice(p, 'Ты не в семье. /fcreate Название — создать (30 000 ₽)'), true;
      notice(p, `Семья «${fam.name}». Глава: ${fam.members[fam.leader] || '?'}. Состав (${Object.keys(fam.members).length}): ${Object.values(fam.members).slice(0, 15).join(', ')}. Казна семьи: ${fam.bank} ₽`);
      return true;
    case '/fput': case '/ftake': {
      if (!fam) return notice(p, 'Ты не в семье'), true;
      const n = parseInt(arg[0], 10);
      if (!(n > 0)) return notice(p, `${cmd} сумма`), true;
      if (cmd === '/fput') {
        if ((p.acc.cash || 0) < n) return notice(p, 'Не хватает наличных'), true;
        setMoney(p, p.acc.cash - n, p.acc.bank || 0, `В казну семьи: −${n} ₽`);
        fam.bank += n;
      } else {
        if (fam.leader !== p.acc.key) return notice(p, 'Брать из казны может глава'), true;
        if (fam.bank < n) return notice(p, `В казне только ${fam.bank} ₽`), true;
        fam.bank -= n;
        setMoney(p, (p.acc.cash || 0) + n, p.acc.bank || 0, `Из казны семьи: +${n} ₽`);
      }
      saveFam(p.acc.family);
      famChat(p.acc.family, '', `${nick} ${cmd === '/fput' ? 'положил в казну' : 'взял из казны'} ${n} ₽ (в казне ${fam.bank} ₽)`);
      return true;
    }
    // ---------------- суд и тюрьма
    case '/sentence': {
      if (!isJudge(p)) return notice(p, 'Приговор выносит судья (мэрия с 3 ранга) или администрация'), true;
      const min = Math.max(1, Math.min(30, parseInt(arg[1], 10) || 0));
      const why = rest.split(/\s+/).slice(2).join(' ') || 'по решению суда';
      if (!q || !parseInt(arg[1], 10)) return notice(p, '/sentence ID минуты(1–30) статья'), true;
      q.acc.jail_until = Date.now() + min * 60000; q.acc.jail_why = why;
      persist(q, { jail_until: q.acc.jail_until, jail_why: why });
      jailMsg(q);
      audit('приговор', `${nick}: ${q.acc.nick} — ${min} мин (${why})`, [nick, q.acc.nick]);
      sendAll({ t: 'chat', n: 'Народный суд', x: `${q.acc.nick} приговорён к ${min} мин колонии: ${why}`, k: 'ad' });
      return true;
    }
    case '/free':
      if (!isJudge(p) && !POLICE.includes(p.acc.faction)) return notice(p, 'Освобождает суд или милиция'), true;
      if (!q) return notice(p, '/free ID'), true;
      q.acc.jail_until = 0; persist(q, { jail_until: 0 });
      send(q, { t: 'act', from: p.id, name: nick, kind: 'free' });
      notice(p, `${q.acc.nick} освобождён`);
      return true;
    // ---------------- выборы и бюджет
    case '/election': {
      if (arg[0] === 'start') {
        if (lvl < 3) return notice(p, 'Выборы объявляет администрация (3+)'), true;
        const min = Math.max(2, Math.min(60, parseInt(arg[1], 10) || 15));
        election = { until: Date.now() + min * 60000, cands: {}, voters: {} };
        sendAll({ t: 'chat', n: 'Избирком', x: `Объявлены выборы мэра! ${min} мин. Кандидаты: /candidate. Голосовать: /vote ник`, k: 'ad' });
        return true;
      }
      if (arg[0] === 'stop' && lvl >= 3) { finishElection(); return true; }
      if (!election) return notice(p, 'Выборов сейчас нет'), true;
      const l = Object.values(election.cands).map(c => `${c.nick}: ${c.votes}`).join(' · ') || 'кандидатов пока нет';
      notice(p, `Выборы мэра — осталось ${Math.ceil((election.until - Date.now()) / 60000)} мин. ${l}`);
      return true;
    }
    case '/candidate':
      if (!election) return notice(p, 'Выборов сейчас нет'), true;
      if (GANGS.includes(p.acc.faction)) return notice(p, 'Члены ОПГ не могут баллотироваться'), true;
      election.cands[p.acc.key] = election.cands[p.acc.key] || { nick, votes: 0 };
      sendAll({ t: 'chat', n: 'Избирком', x: `${nick} выдвинул свою кандидатуру в мэры`, k: 'ad' });
      return true;
    case '/vote': {
      if (!election) return notice(p, 'Выборов сейчас нет'), true;
      if (election.voters[p.acc.key]) return notice(p, 'Ты уже проголосовал'), true;
      const key = Object.keys(election.cands).find(k => election.cands[k].nick.toLowerCase() === String(arg[0] || '').toLowerCase());
      if (!key) return notice(p, '/vote ник кандидата (/election — список)'), true;
      election.voters[p.acc.key] = true;
      election.cands[key].votes++;
      notice(p, `Голос за ${election.cands[key].nick} принят`);
      return true;
    }
    case '/tax': {
      if (world.leaders.mayor !== p.acc.key && lvl < 3) return notice(p, 'Налог устанавливает мэр'), true;
      const n = Math.max(0, Math.min(20, parseInt(arg[0], 10)));
      if (!Number.isFinite(n)) return notice(p, `/tax 0–20 (сейчас ${world.tax}%)`), true;
      world.tax = n; dbLater('world', { tax: n });
      sendAll(worldMsg());
      sendAll({ t: 'chat', n: 'Мэрия', x: `Подоходный налог теперь ${n}% — с зарплат во фракциях`, k: 'ad' });
      return true;
    }
    case '/payout': {
      if (world.leaders.mayor !== p.acc.key && lvl < 3) return notice(p, 'Распределяет бюджет мэр'), true;
      const fid = arg[0]; const n = parseInt(arg[1], 10);
      if (!FACTIONS.includes(fid) || !(n > 0)) return notice(p, '/payout фракция сумма — премия лидеру из казны'), true;
      if ((world.budget || 0) < n) return notice(p, `В казне только ${world.budget || 0} ₽`), true;
      const lead = [...players.values()].find(r => r.acc && r.acc.key === world.leaders[fid]);
      if (!lead) return notice(p, 'Лидера этой организации нет в городе'), true;
      world.budget -= n; dbLater('world', { budget: world.budget });
      setMoney(lead, lead.acc.cash || 0, (lead.acc.bank || 0) + n, `Мэрия перечислила ${n} ₽ на нужды организации`);
      audit('бюджет', `${nick}: ${n} ₽ → ${fid} (${lead.acc.nick})`, [nick, lead.acc.nick]);
      notice(p, `Перечислено ${n} ₽. В казне осталось ${world.budget} ₽`);
      return true;
    }
    // ---------------- телефон
    case '/sms': {
      if (!q || q === p || !tail) return notice(p, '/sms ID текст'), true;
      send(q, { t: 'sms', from: nick, x: tail.slice(0, 200) });
      notice(p, `СМС для ${q.acc.nick} отправлено`);
      return true;
    }
    case '/call':
      if (!q || q === p) return notice(p, '/call ID — позвонить'), true;
      if (p.callWith || q.callWith) return notice(p, 'Линия занята'), true;
      askPlayer(p, q, 'call', `Входящий звонок: ${nick}. Ответить?`);
      return true;
    case '/t': {
      const o = players.get(p.callWith | 0);
      if (!o) { p.callWith = 0; return notice(p, 'Ты ни с кем не говоришь (/call ID)'), true; }
      if (rest) for (const r of [p, o]) send(r, { t: 'chat', n: `📞 ${nick}`, x: rest, k: 'call' });
      localChat(p, `* ${nick} говорит по телефону`, 'me', 8);
      return true;
    }
    case '/h': {
      const o = players.get(p.callWith | 0);
      p.callWith = 0;
      if (o) { o.callWith = 0; notice(o, `${nick} положил трубку`); }
      return notice(p, 'Разговор окончен'), true;
    }
  }
  return false;
}

// Торговля между игроками: продать или подарить вещь из сумки.
function onTrade(p, m) {
  const q = players.get(m.to | 0);
  const item = String(m.item || '').slice(0, 40);
  const price = Math.max(0, Math.min(200000, Math.trunc(+m.price || 0)));
  if (!p.acc || !q || !q.acc || q === p || !item) return;
  if (!near(p, q, 5)) return notice(p, 'Подойди ближе');
  askPlayer(p, q, 'trade', price ? `${p.acc.nick} продаёт «${item}» за ${price} ₽. Купить?` : `${p.acc.nick} дарит тебе «${item}». Принять?`, { item, price });
}
// Налог с зарплаты (телефон сам вычитает и сообщает)
function onTax(p, m) {
  const n = Math.max(0, Math.min(5000, Math.trunc(+m.n || 0)));
  if (!p.acc || !n || Date.now() - (p.taxT || 0) < 60000) return;
  p.taxT = Date.now();
  addBudget(n, '');
}

// ---------------------------------------------------------------- события сервера
// Раз в 25–40 минут где-то в городе появляется «находка»: кто первым добежит или доедет — получает награду.
// Точки — дворы и подъезды из city_builder (город строится одинаково у всех, seed 1977).
const EVENT_SPOTS = [[-3.1, 0.1, 73.5], [-1286, 0.1, -175.5], [358.9, 0.1, -356.5], [-358, 0.1, -346.5],
  [-910, 0.1, 184.5], [93, 0, 538.1], [-351, 0.1, 374], [369.6, 0.1, 184.5], [-1272, 0.1, 183.5], [-359, 0.1, 15.5],
  [1.8, 0.1, -336], [-993, 0.1, -116], [258, 0.1, -86.9], [-79, 0.1, 336], [-179.4, 0.1, -156.5], [151, 0.1, 273.5]];
const EVENT_KINDS = [
  { title: 'Потерянная сумка инкассатора', text: 'Инкассаторская машина потеряла сумку с выручкой! Кто первым найдёт — получит', reward: 4000 },
  { title: 'Посылка из Москвы', text: 'Курьер оставил дефицитную посылку без адреса. Нашедшему — вознаграждение', reward: 3000 },
  { title: 'Клад во дворе', text: 'Дворник откопал старую жестянку с червонцами. Кто успеет первым — заберёт', reward: 3500 },
  { title: 'Лотерея «Спортлото»', text: 'Выигрышный билет «Спортлото» уронили во дворе! Нашедшему —', reward: 5000 },
];
const EVENT_MIN = 25, EVENT_MAX = 40, EVENT_LIVE = 10;   // минуты
let ev = null, evSeq = 0, evNext = Date.now() + 5 * 60000, evLast = -1;

function eventMsg() {
  return { t: 'event', id: ev.id, title: ev.title, text: ev.text, reward: ev.reward, x: ev.pos[0], y: ev.pos[1], z: ev.pos[2],
    left: Math.max(0, Math.round((ev.until - Date.now()) / 1000)) };
}
function startEvent() {
  let i;
  do i = Math.floor(Math.random() * EVENT_SPOTS.length); while (i === evLast && EVENT_SPOTS.length > 1);
  evLast = i;
  const k = EVENT_KINDS[Math.floor(Math.random() * EVENT_KINDS.length)];
  ev = { id: ++evSeq, pos: EVENT_SPOTS[i], title: k.title, text: `${k.text} ${k.reward} ₽.`, reward: k.reward, until: Date.now() + EVENT_LIVE * 60000 };
  sendAll(eventMsg());
  audit('событие', `${k.title} — точка ${i}`, []);
}
function endEvent(winner) {
  if (!ev) return;
  sendAll({ t: 'event_end', id: ev.id, win: winner ? winner.acc.nick : '', title: ev.title });
  ev = null;
  evNext = Date.now() + (EVENT_MIN + Math.random() * (EVENT_MAX - EVENT_MIN)) * 60000;
}
function onEventClaim(p, m) {
  if (!ev || (m.id | 0) !== ev.id || !p.s) return;
  const d = Math.hypot(p.s[0] - ev.pos[0], p.s[2] - ev.pos[2]);
  if (d > 7) return notice(p, 'Подойди ближе к находке');
  if ((p.flags || 0) >= 3) return notice(p, 'Награда недоступна: античит заметил подозрительные перемещения');
  const reward = ev.reward;
  setMoney(p, (p.acc.cash || 0) + reward, p.acc.bank || 0, `${ev.title}: +${reward} ₽`);
  audit('находка', `${p.acc.nick} нашёл «${ev.title}» (+${reward} ₽)`, [p.acc.nick]);
  endEvent(p);
}
setInterval(() => {
  const now = Date.now();
  if (ev && now > ev.until) endEvent(null);
  else if (!ev && now >= evNext) {
    if (online() >= 1) startEvent();
    else evNext = now + 60000;       // никого нет — подождём
  }
}, 10000);

function localChat(p, x, k, d) {
  for (const q of players.values()) if (q.name && (q === p || !p.s || !q.s || dist(p.s, q.s) < d)) send(q, { t: 'chat', n: '', x, k });
}

// ---------------------------------------------------------------- маршрутизация
function onMessage(p, m) {
  if (m.t === 'auth') return onAuth(p, m);
  if (!p.acc) return;   // всё остальное — только после входа
  switch (m.t) {
    case 'hello': {
      if (p.name) return;
      p.name = p.acc.nick;
      p.info = { look: (m.look && typeof m.look === 'object') ? m.look : {}, sex: p.acc.sex || 'm' };   // пол — по аккаунту
      const list = [];
      for (const q of players.values()) if (q !== p && q.name) list.push([q.id, q.name, q.info]);
      send(p, { t: 'welcome', id: p.id, name: p.name, list });
      send(p, { t: 'turf', map: world.turf });
      send(p, { t: 'homes', taken: takenHomes(p) });
      send(p, { t: 'bizs', map: bizMap(p) });
      send(p, worldMsg());
      if (ev) send(p, eventMsg());
      p.joinT = Date.now();
      jailMsg(p);
      send(p, portMsg(p)); send(p, bankMsg(p)); loanOverdue(p);
      for (const q of players.values()) if (q !== p && q.name) send(q, { t: 'join', id: p.id, name: p.name, info: p.info });
      for (const q of players.values()) if (q !== p && q.name && q.pcars && q.pcars.length) send(p, { t: 'pcars', id: q.id, l: q.pcars });
      return log(`вошёл ${p.name} (#${p.id}), онлайн ${online()}`);
    }
    case 'st':
      if (Array.isArray(m.s) && m.s.length >= 8 && m.s.length <= 16 && [0, 1, 2].every(i => Number.isFinite(m.s[i]))) {
        m.s[10] = p.acc.faction;       // фракцию на нике показываем по данным сервера
        if (m.s.length > 11 && !players.has(m.s[11] | 0)) m.s[11] = 0;
        moveCheck(p, m.s);
        p.s = m.s; p.sN = (p.sN || 0) + 1;
      }
      return;
    case 'save': if (typeof m.d === 'string' && m.d.length < 300000) p.pendingSave = m.d; return;
    case 'say': return onSay(p, m);
    case 'adm': return onAdminPanel(p);
    case 'event_claim': return onEventClaim(p, m);
    case 'lookup': return onLookup(p);
    case 'call': return onCall(p, m);
    case 'call_take': return onCallTake(p, m);
    case 'injured': return onInjured(p, m);
    case 'search_res': return onSearchRes(p, m);
    case 'docs': return onDocs(p, m);
    case 'trade': return onTrade(p, m);
    case 'tax': return onTax(p, m);
    case 'money': return onMoney(p, m);
    case 'give': return onGive(p, m);
    case 'faction': return onFaction(p, m);
    case 'roster': return onRoster(p);
    case 'act': return onAct(p, m);
    case 'answer': return onAnswer(p, m);
    case 'turf': return onTurf(p, m);
    case 'port': return onPort(p, m);
    case 'bank': return onBank(p, m);
    case 'lotto': return onLotto(p, m);
    case 'home': return onHome(p, m);
    case 'biz': return onBiz(p, m);
    case 'crash': {   // журнал вылета с телефона игрока — в лог сервера (Render → Logs)
      const txt = String(m.log || '').slice(-6000);
      log(`ВЫЛЕТ у ${p.acc.nick} (${String(m.dev || '').slice(0, 60)}):\n${txt}`);
      dbLater('crashes/' + p.acc.key, { [Date.now()]: { dev: String(m.dev || '').slice(0, 60), log: txt } });
      return;
    }
    case 'pcars': {   // свои припаркованные машины — показать другим
      if (!Array.isArray(m.l) || m.l.length > 6) return;
      const l = m.l.filter(a => Array.isArray(a) && a.length === 8 && a.slice(4).every(Number.isFinite))
        .map(a => [String(a[0]).slice(0, 12), String(a[1]).slice(0, 24), String(a[2]).slice(0, 8), String(a[3]).slice(0, 32), ...a.slice(4)]);
      p.pcars = l;
      return sendAll({ t: 'pcars', id: p.id, l }, q => q !== p);
    }
    case 'refund': {   // продажа бизнеса государству: не чаще 3 раз в час, до 1 млн
      const now = Date.now();
      p.refunds = (p.refunds || []).filter(t => now - t < 3600000);
      if (p.refunds.length >= 3) return;
      p.refunds.push(now);
      p.sale += Math.min(Math.max(0, m.amount | 0), 1000000);
      return;
    }
  }
}

// Античит перемещения. Прыжки на сотни метров бывают честными (метро, вход в здание, больница),
// поэтому смотрим на частоту прыжков и на долгую скорость выше, чем у любой машины в игре.
const MAX_SPEED = 75;                   // м/с (270 км/ч) — дольше 2 с подряд = спидхак
function moveCheck(p, s) {
  const now = Date.now();
  if (p.s && p.stT) {
    const dt = (now - p.stT) / 1000;
    const d = Math.hypot(s[0] - p.s[0], s[2] - p.s[2]);
    if (dt > 0.05 && dt < 3) {
      if (d > 120) {
        p.jumps = (p.jumps || []).filter(t => now - t < 120000); p.jumps.push(now);
        if (p.jumps.length > 10) suspect(p, `телепорты: ${p.jumps.length} за 2 мин`);
      } else if (d / dt > MAX_SPEED) {
        p.fastT = (p.fastT || 0) + dt;
        if (p.fastT > 2) { suspect(p, `скорость ${Math.round(d / dt * 3.6)} км/ч`); p.fastT = 0; }
      } else p.fastT = Math.max(0, (p.fastT || 0) - dt);
    }
  }
  p.stT = now;
}
function suspect(p, why) {
  const now = Date.now();
  if (now - (p.suspT || 0) < 30000) return;
  p.suspT = now;
  p.flags = (p.flags || 0) + 1;
  audit('античит', `${p.acc.nick} — ${why}`, [p.acc.nick]);
  for (const q of players.values()) if (admin(q) >= 1) notice(q, `[античит] ${p.acc.nick}: ${why} (/tp ${p.acc.nick} — проверить)`);
}

function drop(p) {
  if (!players.has(p.id)) return;
  const peer = players.get(p.callWith | 0);
  if (peer) { peer.callWith = 0; notice(peer, 'Связь прервалась'); }
  if (p.acc && memo.has(p.acc.key)) memo.get(p.acc.key).sale = p.sale;
  flushSave(p);
  if (p.acc && p.acc.cash != null) persist(p, { cash: p.acc.cash, bank: p.acc.bank, last_seen: Date.now() });
  players.delete(p.id);
  try { p.sock.destroy(); } catch (e) {}
  if (p.name) {
    for (const q of players.values()) if (q.name) send(q, { t: 'left', id: p.id });
    log(`вышел ${p.name} (#${p.id}), онлайн ${online()}`);
  }
}

// Рассылка положений: совсем рядом (до 40 м) — 8 раз в секунду, до 100 м — 4, до 200 — 2, дальше — 1;
// только изменившиеся состояния и не больше MAX_SEEN ближайших. Так трафик почти не растёт с онлайном:
// в толпе из 100 человек телефон получает данные о 40 ближайших, а дальние обновляются реже.
const MAX_SEEN = 40;
let tick = 0;
setInterval(() => {
  tick++;
  for (const p of players.values()) {
    if (!p.name) continue;
    if (!p.seen) p.seen = new Map();
    const near = [];
    for (const q of players.values()) {
      if (q === p || !q.s) continue;
      const d = p.s ? dist(p.s, q.s) : 0;
      if (d <= VIEW_DIST) near.push([d, q]);
    }
    if (near.length > MAX_SEEN) {
      near.sort((a, b) => a[0] - b[0]);
      near.length = MAX_SEEN;
    }
    const l = [];
    for (const [d, q] of near) {
      const every = d < 40 ? 1 : d < 100 ? 2 : d < 200 ? 4 : 8;
      if ((tick + q.id) % every) continue;
      if (p.seen.get(q.id) === q.sN) continue;
      p.seen.set(q.id, q.sN);
      l.push([q.id, q.s]);
    }
    if (l.length) send(p, { t: 'sts', l });
  }
}, SEND_MS);

loadWorld().then(() => server.listen(PORT, () =>
  log(`СССР РП: сервер запущен, порт ${PORT}; база: ${USE_FB ? 'Firebase' : 'в памяти (FIREBASE_URL/FIREBASE_SECRET не заданы)'}`)));
