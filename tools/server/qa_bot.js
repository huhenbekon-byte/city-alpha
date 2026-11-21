// QA-бот для онлайн-проверки: node qa_bot.js [ник] — выполняет команды из ЛС «Иван_Тестов» (CMD:COME, CMD:LOOK, CMD:CALL, CMD:B, CMD:PASS, CMD:HITS, CMD:REVIVE, CMD:SMS, CMD:TRADE ...)
// QA-бот: выполняет команды из ЛС «Тестера» и отвечает, что видит.
const URL = 'ws://localhost:7777';
const NICK = process.argv[2] || 'Бот_Петя';
let MODE = process.argv[3] || 'register';
let ws, me = 0, client = -1, pos = [0, 0.4, 14], anim = 'Idle', wanted = 0, look = '0,0,0,0,0,0;;m';
const seen = {}; // id -> last state
const names = {};
const seenT = {};
let lastCall = null, cash = null, lastEvent = null;
function send(o) { ws.readyState === 1 && ws.send(JSON.stringify(o)); }
function pm(t) { send({ t: 'say', x: `/pm Иван_Тестов REPLY:${t}` }); }
function st() { send({ t: 'st', s: [pos[0], pos[1], pos[2], 0, anim, 1, 0, 0, wanted, 100, '', 0, look, '', 0, 0] }); }
function log(...a) { console.log('BOT', ...a); }
function connect() {
  ws = new WebSocket(URL);
  ws.onopen = () => send({ t: 'auth', mode: MODE, nick: NICK, pass: 'pass1234', sex: 'm' });
  ws.onclose = () => log('closed');
  ws.onmessage = ev => {
    const m = JSON.parse(ev.data);
    if (m.t === 'auth_ok') { cash = m.prof ? m.prof.cash : null; send({ t: 'hello', name: NICK, look: {}, sex: 'm' }); }
    else if (m.t === 'auth_err') log('auth_err', m.msg);
    else if (m.t === 'welcome') { me = m.id; for (const e of m.list || []) { names[e[0]] = e[1]; if (e[1] === "Иван_Тестов") client = e[0]; } log('welcome id', me); }
    else if (m.t === 'join') { names[m.id] = m.name; if (m.name === 'Иван_Тестов') client = m.id; }
    else if (m.t === 'sts') for (const [id, s] of m.l) { seen[id] = s; seenT[id] = Date.now(); if (names[id] === 'Иван_Тестов') client = id; }
    else if (m.t === 'money_set') { cash = m.cash; log('money_set', m.cash, m.bank, m.msg); }
    else if (m.t === 'ask') { log('ask', m.kind); send({ t: 'answer', id: m.id, ok: true }); }
    else if (m.t === 'act') { log('act', m.kind, m.name || ''); if (m.kind === 'search') send({ t: 'search_res', to: m.from, items: ['финский нож', 'товар: 3 шт.'] }); }
    else if (m.t === 'call_taken') log('call_taken by', m.by);
    else if (m.t === 'faction_set') log('faction_set', m.fid, m.rank);
    else if (m.t === 'event') { lastEvent = m; log('event', m.title); }
    else if (m.t === 'world') log('world min', m.min, m.weather);
    else if (m.t === 'chat') {
      if (m.k === 'pm' && String(m.x).startsWith('CMD:')) return cmd(String(m.x).slice(4).trim());
      log('chat', m.k, m.n, String(m.x).slice(0, 90));
    }
  };
}
function cmd(c) {
  const [k, ...a] = c.split(' ');
  log('CMD', c);
  const cs = client >= 0 ? seen[client] : null;
  switch (k) {
    case 'COME': if (cs) { pos = [cs[0] + 1.5, cs[1], cs[2]]; st(); } break;
    case 'GOTO': pos = [+a[0], 0.4, +a[1]]; st(); break;
    case 'ANIM': anim = a[0]; st(); break;
    case 'SAY': send({ t: 'say', x: a.join(' ') }); break;
    case 'G': send({ t: 'say', x: '/g ' + a.join(' ') }); break;
    case 'WANTED': wanted = +a[0]; st(); break;
    case 'HIT': send({ t: 'act', to: client, kind: 'hit', dmg: 10, melee: true }); break;
    case 'HEAL': send({ t: 'act', to: client, kind: 'heal' }); break;
    case 'CALL': send({ t: 'call', x: pos[0], z: pos[2], text: a.join(' ') || 'Помогите' }); break;
    case 'REPORT': send({ t: 'say', x: '/report ' + a.join(' ') }); break;
    case 'CLAIM': if (lastEvent) { pos = [lastEvent.x + 1, 0.4, lastEvent.z]; st(); setTimeout(() => send({ t: 'event_claim', id: lastEvent.id }), 300); } break;
    case 'LOOK': pm(`id=${client} age=${client>=0?Date.now()-(seenT[client]||0):-1} look=${cs ? cs[12] : 'none'} anim=${cs ? cs[4] : 'none'} yaw=${cs ? cs[3] : '?'} car=${cs ? JSON.stringify(cs[6]) : ''} wanted=${cs ? cs[8] : ''}`); break;
    case 'CASH': pm(`cash=${cash}`); break;
    case 'LOOKUP': send({ t: 'lookup' }); break;
    case 'B': send({ t: 'say', x: '/b ' + a.join(' ') }); break;
    case 'D': send({ t: 'say', x: '/d ' + a.join(' ') }); break;
    case 'PASS': send({ t: 'say', x: '/pass ' + client }); break;
    case 'REVIVE': send({ t: 'say', x: '/revive ' + client }); break;
    case 'HITS': { let n = +a[0] || 5; const iv = setInterval(() => { send({ t: 'act', to: client, kind: 'hit', dmg: 15, melee: true }); if (--n <= 0) clearInterval(iv); }, 350); break; }
    case 'SMS': send({ t: 'say', x: '/sms ' + client + ' ' + a.join(' ') }); break;
    case 'TRADE': send({ t: 'trade', to: client, item: a[0], price: +a[1] || 0 }); break;
    case 'QUIT': ws.close(); MODE = 'login'; setTimeout(connect, 1500); break;   // переподключение
  }
}
connect();
setInterval(st, 400);
