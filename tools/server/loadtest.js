// Нагрузочный тест сервера «СССР РП»: N ботов заходят, бегают по городу кучей и болтают в чат.
// Запуск (сервер уже работает):  node loadtest.js ws://localhost:7777 100 60
//   аргументы: адрес, число ботов, секунд теста.
// Печатает: сколько ботов вошло, трафик к одному игроку (КБ/с), задержку ответа сервера.
// Нужен Node 22+ (встроенный WebSocket).
const URL = process.argv[2] || 'ws://localhost:7777';
const N = +process.argv[3] || 50;
const SECS = +process.argv[4] || 30;
const AREA = 220;                       // боты бегают по квадрату 220×220 м — почти все видят всех (худший случай)
const run = Math.random().toString(36).slice(2, 6);

const bots = [];
// RP-ник для бота: Бот_Ххххх (сервер принимает только Имя_Фамилия буквами)
const ABC = 'абвгдежзиклмнопрстуфхцчшэюя';
function rpNick(i) {
  let n = Math.floor(Math.random() * 1e6) * 1000 + i, t = '';
  for (let k = 0; k < 7; k++) { t += ABC[n % ABC.length]; n = Math.floor(n / ABC.length); }
  return 'Бот_Н' + t;
}
let joined = 0, errors = 0, bytesIn = 0, msgsIn = 0, pings = [], authErr = {};

function bot(i) {
  return new Promise(resolve => {
    const b = { i, x: Math.random() * AREA - AREA / 2, z: Math.random() * AREA - AREA / 2, a: Math.random() * 6.28, ok: false };
    const ws = new WebSocket(URL);
    b.ws = ws;
    const timer = setTimeout(() => resolve(b), 15000);
    ws.onopen = () => ws.send(JSON.stringify({ t: 'auth', mode: 'register', nick: rpNick(i), pass: 'test1234', sex: i % 3 ? 'm' : 'f' }));
    ws.onerror = () => { errors++; clearTimeout(timer); resolve(b); };
    ws.onmessage = ev => {
      const s = typeof ev.data === 'string' ? ev.data : '';
      bytesIn += s.length; msgsIn++;
      if (b.ok && b.measure) b.bytes = (b.bytes || 0) + s.length;
      let m; try { m = JSON.parse(s); } catch { return; }
      if (m.t === 'auth_ok') ws.send(JSON.stringify({ t: 'hello', name: '', look: { shirt: 'red' }, sex: 'm' }));
      else if (m.t === 'auth_err') { authErr[m.msg] = (authErr[m.msg] || 0) + 1; clearTimeout(timer); resolve(b); }
      else if (m.t === 'welcome') { b.ok = true; joined++; clearTimeout(timer); resolve(b); }
      else if (m.t === 'chat' && b.pingAt && String(m.x).includes(b.pingText)) { pings.push(Date.now() - b.pingAt); b.pingAt = 0; }
    };
  });
}

function step(b, dt) {
  b.a += (Math.random() - 0.5) * 0.6;
  b.x = Math.max(-AREA / 2, Math.min(AREA / 2, b.x + Math.sin(b.a) * 5 * dt));
  b.z = Math.max(-AREA / 2, Math.min(AREA / 2, b.z + Math.cos(b.a) * 5 * dt));
  const s = [+b.x.toFixed(2), 0.4, +b.z.toFixed(2), +b.a.toFixed(2), 'run', 1, 0, 0, 0, 100, '', 0, 'm|1|2|3', 'fist', 0, 0];
  if (b.ws.readyState === 1) b.ws.send(JSON.stringify({ t: 'st', s }));
}

(async () => {
  console.log(`подключаю ${N} ботов к ${URL}…`);
  for (let i = 0; i < N; i += 10) {     // заходят пачками по 10, как живые люди — не все в одну миллисекунду
    const part = await Promise.all(Array.from({ length: Math.min(10, N - i) }, (_, k) => bot(i + k)));
    bots.push(...part);
  }
  console.log(`вошли: ${joined}/${N}, ошибок соединения: ${errors}`, Object.keys(authErr).length ? authErr : '');
  const live = bots.filter(b => b.ok);
  const t0 = Date.now();
  const move = setInterval(() => live.forEach(b => step(b, 0.125)), 125);
  // каждые 2 с один случайный бот пишет в чат и замеряет, через сколько сообщение вернулось
  const chat = setInterval(() => {
    const b = live[Math.floor(Math.random() * live.length)];
    if (!b || b.pingAt) return;
    b.pingText = 'тест ' + Math.random().toString(36).slice(2, 7);
    b.pingAt = Date.now();
    b.ws.send(JSON.stringify({ t: 'say', x: b.pingText }));
  }, 2000);
  await new Promise(r => setTimeout(r, 3000));   // разогрев
  live.forEach(b => { b.measure = true; b.bytes = 0; });
  const m0 = Date.now();
  await new Promise(r => setTimeout(r, Math.max(1, SECS - 3) * 1000));
  const secs = (Date.now() - m0) / 1000;
  clearInterval(move); clearInterval(chat);
  const per = live.map(b => b.bytes / secs / 1024).sort((a, b) => a - b);
  const avg = per.reduce((a, b) => a + b, 0) / Math.max(1, per.length);
  pings.sort((a, b) => a - b);
  console.log(`за ${secs.toFixed(0)} с: входящий трафик на игрока — в среднем ${avg.toFixed(1)} КБ/с, максимум ${(per[per.length - 1] || 0).toFixed(1)} КБ/с`);
  console.log(`весь исходящий трафик сервера ≈ ${(avg * live.length).toFixed(0)} КБ/с (${(avg * live.length * 8 / 1024).toFixed(1)} Мбит/с)`);
  if (pings.length) console.log(`задержка чата: медиана ${pings[pings.length >> 1]} мс, худшая ${pings[pings.length - 1]} мс (${pings.length} замеров)`);
  live.forEach(b => b.ws.close());
  console.log(`итог: ${joined === N && errors === 0 ? 'OK' : 'ЕСТЬ ПРОБЛЕМЫ'} (${((Date.now() - t0) / 1000).toFixed(0)} с)`);
  setTimeout(() => process.exit(0), 500);
})();
