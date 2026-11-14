// City Alpha — онлайн-сервер. Node.js 18+, без внешних библиотек (свой WebSocket по RFC 6455).
//
// Запуск:            node server.js            (порт из переменной PORT, иначе 7777)
// Render.com:        Web Service → Root Directory: tools/server → Start Command: node server.js
// Проверка в браузере: открой адрес сервера — увидишь «City Alpha server: online N».
//
// Протокол — JSON в текстовых кадрах WebSocket:
//   клиент → сервер  {"t":"hello","name":"Имя","look":{...}}
//                    {"t":"st","s":[x,y,z,yaw,anim,aspeed,car,xf]}   car = 0 или [kind,model,paint,name], xf = 12 чисел
//                    {"t":"say","x":"текст"}                         «/g текст» — всем на сервере
//   сервер → клиент  {"t":"welcome","id":1,"name":"Имя","list":[[id,name,info],...]}
//                    {"t":"join","id":2,"name":"...","info":{...}}   {"t":"left","id":2}
//                    {"t":"sts","l":[[id,s],...]}                   — только игроки в радиусе VIEW_DIST
//                    {"t":"chat","n":"Имя","x":"текст","g":false}
'use strict';
const http = require('http');
const crypto = require('crypto');

const PORT = parseInt(process.env.PORT || '7777', 10);
const SEND_MS = 125;          // 8 раз в секунду
const VIEW_DIST = 350;
const CHAT_DIST = 60;
const MAX_PLAYERS = 200;
const GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

let nextId = 1;
const players = new Map();    // id -> {sock, name, info, s, chatT, buf, alive}

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end(`City Alpha server: online ${[...players.values()].filter(p => p.name).length}\n`);
});

server.on('upgrade', (req, sock) => {
  const key = req.headers['sec-websocket-key'];
  if (!key || players.size >= MAX_PLAYERS) { sock.destroy(); return; }
  const accept = crypto.createHash('sha1').update(key + GUID).digest('base64');
  sock.write('HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n' +
             `Sec-WebSocket-Accept: ${accept}\r\n\r\n`);
  sock.setNoDelay(true);
  const id = nextId++;
  const p = { id, sock, name: '', info: {}, s: null, chatT: 0, buf: Buffer.alloc(0), frags: [] };
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
  if (p.sock.destroyed) return;
  try { p.sock.write(frame(1, Buffer.from(JSON.stringify(obj)))); } catch (e) { /* закрылся */ }
}

function readFrames(p) {
  while (p.buf.length >= 2) {
    const b0 = p.buf[0], b1 = p.buf[1];
    const fin = (b0 & 0x80) !== 0, op = b0 & 0x0f, masked = (b1 & 0x80) !== 0;
    let len = b1 & 0x7f, off = 2;
    if (len === 126) { if (p.buf.length < 4) return; len = p.buf.readUInt16BE(2); off = 4; }
    else if (len === 127) { if (p.buf.length < 10) return; len = Number(p.buf.readBigUInt64BE(2)); off = 10; }
    if (len > 65536) { p.sock.destroy(); return; }
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
      if (obj && typeof obj === 'object') onMessage(p, obj);
    }
  }
}

function cleanName(s) {
  return String(s || '').replace(/[\x00-\x1f\[\]<>]/g, '').trim().slice(0, 24);
}

function onMessage(p, m) {
  if (m.t === 'hello' && !p.name) {
    let nm = cleanName(m.name) || `Игрок_${p.id}`;
    for (const q of players.values()) if (q !== p && q.name === nm) nm = `${nm.slice(0, 18)}_${p.id}`;
    p.name = nm;
    p.info = { look: (m.look && typeof m.look === 'object') ? m.look : {} };
    const list = [];
    for (const q of players.values()) if (q !== p && q.name) list.push([q.id, q.name, q.info]);
    send(p, { t: 'welcome', id: p.id, name: nm, list });
    for (const q of players.values()) if (q !== p && q.name) send(q, { t: 'join', id: p.id, name: nm, info: p.info });
    log(`вошёл ${nm} (#${p.id}), онлайн ${online()}`);
  } else if (m.t === 'st' && p.name && Array.isArray(m.s) && m.s.length >= 8) {
    p.s = m.s;
  } else if (m.t === 'say' && p.name) {
    const now = Date.now();
    if (now - p.chatT < 800) return;
    p.chatT = now;
    let x = String(m.x || '').replace(/[\[\]]/g, '').trim().slice(0, 140);
    if (!x) return;
    const g = x.startsWith('/g ');
    if (g) x = x.slice(3);
    log(`[chat] ${g ? '(всем) ' : ''}${p.name}: ${x}`);
    for (const q of players.values()) {
      if (!q.name) continue;
      if (g || q === p || !p.s || !q.s || dist(p.s, q.s) < CHAT_DIST) send(q, { t: 'chat', n: p.name, x, g });
    }
  }
}

function dist(a, b) { return Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]); }
function online() { let n = 0; for (const p of players.values()) if (p.name) n++; return n; }
function log(s) { console.log(new Date().toISOString().slice(0, 19).replace('T', ' ') + ' ' + s); }

function drop(p) {
  if (!players.has(p.id)) return;
  players.delete(p.id);
  try { p.sock.destroy(); } catch (e) {}
  if (p.name) {
    for (const q of players.values()) if (q.name) send(q, { t: 'left', id: p.id });
    log(`вышел ${p.name} (#${p.id}), онлайн ${online()}`);
  }
}

setInterval(() => {
  for (const p of players.values()) {
    if (!p.name) continue;
    const l = [];
    for (const q of players.values()) {
      if (q === p || !q.s) continue;
      if (p.s && dist(p.s, q.s) > VIEW_DIST) continue;
      l.push([q.id, q.s]);
    }
    if (l.length) send(p, { t: 'sts', l });
  }
}, SEND_MS);

server.listen(PORT, () => log(`City Alpha сервер запущен, порт ${PORT}`));
