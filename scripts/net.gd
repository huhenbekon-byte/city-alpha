extends Node
## Онлайн. Глобальный объект Net (autoload) — клиент сервера City Alpha.
## Сам сервер — tools/server/server.js (Node.js): его можно бесплатно запустить на Render.com,
## на любом VPS или на компьютере. Связь — WebSocket, сообщения в JSON (протокол описан в server.js).
##
## Адрес сервера:  "city-alpha.onrender.com"  → wss://city-alpha.onrender.com
##                 "1.2.3.4:7777"             → ws://1.2.3.4:7777
##                 "ws://..." / "wss://..."   → как есть

signal player_joined(id: int, pname: String, info: Dictionary)
signal player_left(id: int)
signal states_received(list: Array)
signal chat_received(pname: String, text: String, global: bool)
signal lost
signal auth_result(ok: bool, msg: String, nick: String, save: String)
signal server_msg(m: Dictionary)   # всё остальное от сервера (деньги, фракция, действия игроков...)
signal reconnected                 # связь восстановлена после обрыва (вход по токену сессии)
signal reconnect_failed(msg: String)

const SEND_INTERVAL := 0.125
const CONNECT_TIMEOUT := 90.0    # бесплатный сервер может «просыпаться» до минуты

var is_server := false           # серверный режим теперь в server.js; оставлено для main.gd
var online := false
var my_id := 0
var host_text := ""
var waking := false              # идёт подключение (для подписи на экране загрузки)
var cancel_join := false         # игрок нажал «Играть офлайн» во время подключения
var authed := false              # вошёл в аккаунт
var nick := ""                   # ник аккаунта
var kick_msg := ""
var reconnecting := false        # связь оборвалась — пробуем вернуться сами
var _token := ""                 # токен сессии с сервера — вход без пароля после обрыва
var profile := {}                 # с сервера при входе: cash, bank, faction, rank, admin, home, leader, ver

var _save_text := ""
var _save_dirty := false
var _save_t := 0.0

var _ws: WebSocketPeer
var _send_t := 0.0
var _last_st := ""
var _idle_t := 0.0


static func url_for(host: String) -> String:
    var h := host.strip_edges()
    if h.begins_with("ws://") or h.begins_with("wss://"):
        return h
    if h.begins_with("http://"):
        return "ws://" + h.substr(7)
    if h.begins_with("https://"):
        return "wss://" + h.substr(8)
    var colon := h.rfind(":")
    if colon > 0 and h.substr(colon + 1).is_valid_int():
        return "ws://" + h     # адрес с портом — свой сервер без шифрования
    return "wss://" + h        # домен (Render и т.п.) — защищённое соединение


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS


## Подключиться. Возвращает true, когда сервер принял соединение.
func join(host: String) -> bool:
    leave()
    host_text = host.strip_edges()
    if host_text == "":
        return false
    var url := url_for(host_text)
    var t := 0.0
    waking = true
    cancel_join = false
    while t < CONNECT_TIMEOUT and not cancel_join:
        _ws = WebSocketPeer.new()
        _ws.inbound_buffer_size = 1 << 20
        _ws.outbound_buffer_size = 1 << 20
        if _ws.connect_to_url(url) != OK:
            break
        var tries := 0.0
        while tries < 15.0 and not cancel_join:
            await get_tree().create_timer(0.1).timeout
            tries += 0.1
            t += 0.1
            _ws.poll()
            var s := _ws.get_ready_state()
            if s == WebSocketPeer.STATE_OPEN:
                online = true
                waking = false
                return true
            if s == WebSocketPeer.STATE_CLOSED:
                break
        _ws.close()
        if cancel_join:
            break
        await get_tree().create_timer(2.0).timeout   # сервер просыпается — пробуем ещё
        t += 2.0
    waking = false
    leave()
    return false


func leave() -> void:
    if _save_dirty and _ws and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
        _flush_save()   # связь уже оборвалась — сохранение уйдёт после переподключения
    online = false
    authed = false
    my_id = 0
    if _ws:
        _ws.close()
    _ws = null


func _send(obj: Dictionary) -> void:
    if online and _ws and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
        _ws.send_text(JSON.stringify(obj))


func hello(pname: String, info: Dictionary) -> void:
    _send({"t": "hello", "name": pname, "look": info.get("look", {}), "sex": String(info.get("sex", "m"))})


## Отправить серверу любое сообщение (для main.gd).
func send_msg(obj: Dictionary) -> void:
    _send(obj)


## st = [pos: Vector3, yaw, anim, anim_speed, car: Array, car_xf: Transform3D, wanted, hp, ride]; не чаще SEND_INTERVAL.
## ride — id игрока, в чьей машине едешь пассажиром (0 — нет).
func send_state(delta: float, st: Array) -> void:
    if not online:
        return
    _send_t += delta
    if _send_t < SEND_INTERVAL:
        return
    _send_t = 0.0
    var p: Vector3 = st[0]
    var car: Array = st[4]
    var xf_out: Variant = 0
    if not car.is_empty():
        var xf: Transform3D = st[5]
        var e := xf.basis.get_euler()   # поворот машины — 3 угла в градусах вместо матрицы 3×3 (меньше трафика)
        xf_out = [roundi(rad_to_deg(e.x)), roundi(rad_to_deg(e.y)), roundi(rad_to_deg(e.z)),
                _r(xf.origin.x), _r(xf.origin.y), _r(xf.origin.z)]
    var msg := JSON.stringify({"t": "st", "s": [_r(p.x), _r(p.y), _r(p.z), _r(float(st[1])), String(st[2]), _r(float(st[3])),
            car if not car.is_empty() else 0, xf_out, int(st[6]) if st.size() > 6 else 0,
            int(st[7]) if st.size() > 7 else 100, "", int(st[8]) if st.size() > 8 else 0]})
    _idle_t += SEND_INTERVAL
    if msg == _last_st and _idle_t < 1.0:   # стоим на месте — не шлём одно и то же 8 раз в секунду
        return
    _last_st = msg
    _idle_t = 0.0
    if online and _ws and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
        _ws.send_text(msg)


## Обрыв связи (метро, лифт, смена вышки): несколько попыток войти обратно по токену сессии.
func _reconnect() -> void:
    var host := host_text
    for attempt in 8:
        await get_tree().create_timer(2.0 + attempt * 1.5).timeout
        if not reconnecting:
            return
        if await join(host):
            _send({"t": "auth", "mode": "token", "token": _token})
            return   # дальше — auth_ok / auth_err в _on_message
    reconnecting = false
    reconnect_failed.emit("Сервер недоступен")


## Сокет открыт прямо сейчас (online может отставать на кадр от обрыва).
func is_open() -> bool:
    return online and _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN


## Вход или регистрация. Ответ — сигнал auth_result.
func auth(mode: String, nick_text: String, password: String, sex := "m") -> void:
    _send({"t": "auth", "mode": mode, "nick": nick_text, "pass": password, "sex": sex})


## Облачное сохранение: отправляется не чаще раза в 5 секунд (последняя версия).
func cloud_save(text: String) -> void:
    if not authed:
        return
    _save_text = text
    _save_dirty = true


func _flush_save() -> void:
    _save_dirty = false
    _save_t = 0.0
    _send({"t": "save", "d": _save_text})


func say(text: String) -> void:
    if text.strip_edges() != "":
        _send({"t": "say", "x": text})


static func _r(v: float) -> float:
    return snappedf(v, 0.01)


func _process(delta: float) -> void:
    if _ws == null or not online:
        return
    _save_t += delta
    if _save_dirty and _save_t >= 5.0:
        _flush_save()
    _ws.poll()
    if _ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
        var can_back := authed and _token != "" and kick_msg == ""
        leave()
        if can_back:
            reconnecting = true
        lost.emit()
        if can_back:
            _reconnect()
        return
    while _ws.get_available_packet_count() > 0:
        var txt := _ws.get_packet().get_string_from_utf8()
        var m: Variant = JSON.parse_string(txt)
        if m is Dictionary:
            _on_message(m)


var _sts_seen := 0


func _on_message(m: Dictionary) -> void:
    var mt := String(m.get("t", ""))
    if mt != "sts":
        Crash.mark("сеть ← " + mt)
    elif _sts_seen < 3:
        _sts_seen += 1
        Crash.mark("сеть ← sts (%d игроков)" % (m.get("l", []) as Array).size())
    match mt:
        "auth_ok":
            authed = true
            nick = String(m.get("nick", ""))
            _token = String(m.get("token", ""))
            profile = m.get("prof", {}) if m.get("prof", {}) is Dictionary else {}
            if reconnecting:
                reconnecting = false
                reconnected.emit()
            else:
                auth_result.emit(true, "", nick, String(m.get("save", "")))
        "auth_err":
            if reconnecting:
                reconnecting = false
                leave()
                reconnect_failed.emit(String(m.get("msg", "Ошибка")))
            else:
                auth_result.emit(false, String(m.get("msg", "Ошибка")), "", "")
        "kicked":
            kick_msg = String(m.get("msg", ""))
        "welcome":
            my_id = int(m.get("id", 0))
            chat_received.emit("", "Вы вошли на сервер как %s." % m.get("name", ""), true)
            for e: Variant in m.get("list", []):
                if e is Array and (e as Array).size() >= 3:
                    player_joined.emit(int(e[0]), String(e[1]), e[2] if e[2] is Dictionary else {})
        "join":
            var info: Variant = m.get("info", {})
            player_joined.emit(int(m.get("id", 0)), String(m.get("name", "")), info if info is Dictionary else {})
        "left":
            player_left.emit(int(m.get("id", 0)))
        "chat":
            server_msg.emit(m)
        "sts":
            var out := []
            for e: Variant in m.get("l", []):
                if not e is Array or (e as Array).size() < 2 or not e[1] is Array:
                    continue
                var s: Array = e[1]
                if s.size() < 8:
                    continue
                var car: Array = s[6] if s[6] is Array else []
                var xf := Transform3D()
                if s[7] is Array and (s[7] as Array).size() >= 12:
                    var a: Array = s[7]
                    xf = Transform3D(Basis(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]), Vector3(a[6], a[7], a[8])),
                            Vector3(a[9], a[10], a[11]))
                elif s[7] is Array and (s[7] as Array).size() >= 6:
                    var a: Array = s[7]
                    xf = Transform3D(Basis.from_euler(Vector3(deg_to_rad(float(a[0])), deg_to_rad(float(a[1])), deg_to_rad(float(a[2])))),
                            Vector3(float(a[3]), float(a[4]), float(a[5])))
                out.append([int(e[0]), [Vector3(float(s[0]), float(s[1]), float(s[2])), float(s[3]), String(s[4]),
                        float(s[5]), car, xf, int(s[8]) if s.size() > 8 and s[8] is float else 0,
                        int(s[9]) if s.size() > 9 and s[9] is float else 100,
                        String(s[10]) if s.size() > 10 and s[10] is String else "",
                        int(s[11]) if s.size() > 11 and s[11] is float else 0]])
            if not out.is_empty():
                states_received.emit(out)
        _:
            server_msg.emit(m)
