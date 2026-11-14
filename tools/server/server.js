// City Alpha — онлайн-сервер. Node.js 18+, без внешних библиотек (свой WebSocket по RFC 6455).
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
    world.members = (await dbGet('world/members')) || {};
    world.owner = (await dbGet('world/owner')) || '';
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
function byNick(nick) {
  const k = accKey(String(nick || ''));
  for (const p of players.values()) if (p.acc && p.acc.key === k) return p;
  return null;
}
function near(p, q, d) { return p.s && q.s && dist(p.s, q.s) <= d; }
function isLeader(p) { return !!(p.acc && p.acc.faction && world.leaders[p.acc.faction] === p.acc.key); }
function admin(p) { return p.acc ? (p.acc.admin | 0) : 0; }

// ---------------------------------------------------------------- WebSocket
const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end(`City Alpha server: online ${online()}\n`);
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
           leader: isLeader(p), ver: p.ver, sex: a.sex || 'm' };
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
  log(`перевод ${p.acc.nick} → ${q.acc.nick}: ${amount}`);
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
  if (!m.ok) return notice(p, `${q.acc.nick} отказался`);
  if (a.kind === 'heal') {
    if ((q.acc.cash || 0) < 300) return notice(q, 'Нужно 300 ₽ наличными');
    setMoney(q, q.acc.cash - 300, q.acc.bank || 0, 'Оплата лечения 300 ₽');
    setMoney(p, (p.acc.cash || 0) + 300, p.acc.bank || 0, `${q.acc.nick} оплатил лечение`);
    send(q, { t: 'act', from: p.id, name: p.acc.nick, kind: 'heal' });
  } else if (a.kind === 'invite') {
    if (q.acc.faction || p.acc.faction !== a.fid) return;
    setFaction(q, a.fid, 1, 'Ты принят в организацию');
    factionChat(a.fid, '', `${q.acc.nick} принят в организацию (пригласил ${p.acc.nick})`);
  } else if (a.kind === 'passport') {
    send(p, { t: 'chat', n: '', x: `Паспорт: ${q.acc.nick}. Организация: ${q.acc.faction || 'нет'}, ранг ${q.acc.rank}`, k: 'info' });
  }
}

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
const WEATHERS = ['clear', 'clear', 'clear', 'cloudy', 'cloudy', 'rain', 'rain', 'snow'];
function worldMsg() {
  const s = Date.now() / 1000;
  const min = s % 1440;            // 1 реальная секунда = 1 игровая минута
  const day = Math.floor((s - DAY_EPOCH) / 1440) + 1;
  const period = Math.floor(s / 420);
  const h = crypto.createHash('md5').update('w' + period).digest()[0];
  return { t: 'world', min, day, weather: WEATHERS[h % WEATHERS.length] };
}
setInterval(() => sendAll(worldMsg()), 15000);

// ---------------------------------------------------------------- чат и команды
const HELP = [
  '/g текст — всем на сервере · /f текст — рация фракции · /pm ник текст — личное',
  '/me действие · /do описание · /try действие (удачно/неудачно) · /report текст — админам',
  'Лидер: /rank ник N · /uninvite ник · /roster.  Админ: /help admin',
].join('\n');
const HELP_ADMIN = [
  '/a текст — админ-чат · /ann текст — объявление · /kick ник · /ban ник причина · /unban ник',
  '/givemoney ник сумма · /tp ник · /tphere ник · /makeleader ник фракция · /setadmin ник 0-5 · /mute ник минуты',
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
      log(`[репорт] ${p.acc.nick}: ${rest}`);
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
  if (!lvl) return notice(p, 'Неизвестная команда. /help — список');
  switch (cmd) {
    case '/a': return sendAll({ t: 'chat', n: `[A] ${p.acc.nick}`, x: rest, k: 'admin' }, q => admin(q) >= 1);
    case '/ann': return rest && sendAll({ t: 'chat', n: 'ОБЪЯВЛЕНИЕ', x: rest, k: 'admin' });
    case '/kick': {
      const q = byNick(arg[0]);
      if (!q || admin(q) >= lvl) return notice(p, 'Нельзя');
      send(q, { t: 'kicked', msg: `Кик от администратора ${p.acc.nick}` });
      log(`кик ${q.acc.nick} (${p.acc.nick})`);
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
      log(`бан ${arg[0]} (${p.acc.nick}): ${reason}`);
      return sendAll({ t: 'chat', n: '', x: `${arg[0]} забанен администратором ${p.acc.nick}: ${reason}`, k: 'admin' });
    }
    case '/unban':
      if (lvl < 2) return notice(p, 'Нужен 2 уровень админки');
      await dbPatch('accounts/' + accKey(arg[0] || ''), { banned: null, ban_reason: null }).catch(() => {});
      return notice(p, `${arg[0]} разбанен`);
    case '/mute': {
      const q = byNick(arg[0]); const mins = Math.max(1, Math.min(1440, parseInt(arg[1], 10) || 10));
      if (!q || admin(q) >= lvl) return notice(p, 'Нельзя');
      q.acc.muted = Date.now() + mins * 60000;
      persist(q, { muted: q.acc.muted });
      notice(q, `Чат заблокирован на ${mins} мин администратором ${p.acc.nick}`);
      return notice(p, 'Готово');
    }
    case '/givemoney': {
      if (lvl < 4) return notice(p, 'Нужен 4 уровень админки');
      const q = byNick(arg[0]); const sum = parseInt(arg[1], 10);
      if (!q || !sum) return notice(p, '/givemoney ник сумма (игрок онлайн)');
      setMoney(q, Math.max(0, (q.acc.cash || 0) + sum), q.acc.bank || 0, `Администратор выдал ${sum} ₽`);
      log(`выдача ${sum} → ${q.acc.nick} (${p.acc.nick})`);
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
      dbLater('world/leaders', { [fid]: q.acc.key });
      send(q, { t: 'faction_set', fid, rank: 99, leader: true, msg: 'Ты назначен лидером организации!' });
      return sendAll({ t: 'chat', n: '', x: `${q.acc.nick} назначен лидером «${fid}»`, k: 'admin' });
    }
    case '/setadmin': {
      if (lvl < 5) return notice(p, 'Только владелец сервера');
      const q = byNick(arg[0]); const l = Math.max(0, Math.min(4, parseInt(arg[1], 10) || 0));
      if (!q) return notice(p, 'Игрок должен быть онлайн');
      q.acc.admin = l;
      persist(q, { admin: l });
      send(q, { t: 'prof', prof: profile(q) });
      return notice(p, `${q.acc.nick}: админка ${l}`);
    }
  }
  return notice(p, 'Неизвестная команда. /help admin');
}

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
    case 'money': return onMoney(p, m);
    case 'give': return onGive(p, m);
    case 'faction': return onFaction(p, m);
    case 'roster': return onRoster(p);
    case 'act': return onAct(p, m);
    case 'answer': return onAnswer(p, m);
    case 'turf': return onTurf(p, m);
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
  log(`подозрение: ${p.acc.nick} — ${why}`);
  for (const q of players.values()) if (admin(q) >= 1) notice(q, `[античит] ${p.acc.nick}: ${why} (/tp ${p.acc.nick} — проверить)`);
}

function drop(p) {
  if (!players.has(p.id)) return;
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

// Рассылка положений: рядом (до 60 м) — 8 раз в секунду, до 150 м — 4, дальше — 2;
// только изменившиеся состояния. Так трафик растёт медленнее числа игроков.
let tick = 0;
setInterval(() => {
  tick++;
  for (const p of players.values()) {
    if (!p.name) continue;
    if (!p.seen) p.seen = new Map();
    const l = [];
    for (const q of players.values()) {
      if (q === p || !q.s) continue;
      const d = p.s ? dist(p.s, q.s) : 0;
      if (d > VIEW_DIST) continue;
      const every = d < 60 ? 1 : d < 150 ? 2 : 4;
      if ((tick + q.id) % every) continue;
      if (p.seen.get(q.id) === q.sN) continue;
      p.seen.set(q.id, q.sN);
      l.push([q.id, q.s]);
    }
    if (l.length) send(p, { t: 'sts', l });
  }
}, SEND_MS);

loadWorld().then(() => server.listen(PORT, () =>
  log(`City Alpha сервер запущен, порт ${PORT}; база: ${USE_FB ? 'Firebase' : 'в памяти (FIREBASE_URL/FIREBASE_SECRET не заданы)'}`)));
