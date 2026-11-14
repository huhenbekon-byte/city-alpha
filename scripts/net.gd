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

const SEND_INTERVAL := 0.125
const CONNECT_TIMEOUT := 90.0    # бесплатный сервер может «просыпаться» до минуты

var is_server := false           # серверный режим теперь в server.js; оставлено для main.gd
var online := false
var my_id := 0
var host_text := ""
var waking := false              # идёт подключение (для подписи на экране загрузки)

var _ws: WebSocketPeer
var _send_t := 0.0


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
    while t < CONNECT_TIMEOUT:
        _ws = WebSocketPeer.new()
        _ws.inbound_buffer_size = 1 << 20
        _ws.outbound_buffer_size = 1 << 20
        if _ws.connect_to_url(url) != OK:
            break
        var tries := 0.0
        while tries < 15.0:
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
        await get_tree().create_timer(2.0).timeout   # сервер просыпается — пробуем ещё
        t += 2.0
    waking = false
    leave()
    return false


func leave() -> void:
    online = false
    my_id = 0
    if _ws:
        _ws.close()
    _ws = null


func _send(obj: Dictionary) -> void:
    if online and _ws and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
        _ws.send_text(JSON.stringify(obj))


func hello(pname: String, info: Dictionary) -> void:
    _send({"t": "hello", "name": pname, "look": info.get("look", {})})


## st = [pos: Vector3, yaw, anim, anim_speed, car: Array, car_xf: Transform3D]; не чаще SEND_INTERVAL.
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
        var b := xf.basis
        xf_out = [_r(b.x.x), _r(b.x.y), _r(b.x.z), _r(b.y.x), _r(b.y.y), _r(b.y.z),
                _r(b.z.x), _r(b.z.y), _r(b.z.z), _r(xf.origin.x), _r(xf.origin.y), _r(xf.origin.z)]
    _send({"t": "st", "s": [_r(p.x), _r(p.y), _r(p.z), _r(float(st[1])), String(st[2]), _r(float(st[3])),
            car if not car.is_empty() else 0, xf_out]})


func say(text: String) -> void:
    if text.strip_edges() != "":
        _send({"t": "say", "x": text})


static func _r(v: float) -> float:
    return snappedf(v, 0.01)


func _process(_delta: float) -> void:
    if _ws == null or not online:
        return
    _ws.poll()
    if _ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
        leave()
        lost.emit()
        return
    while _ws.get_available_packet_count() > 0:
        var txt := _ws.get_packet().get_string_from_utf8()
        var m: Variant = JSON.parse_string(txt)
        if m is Dictionary:
            _on_message(m)


func _on_message(m: Dictionary) -> void:
    match String(m.get("t", "")):
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
            chat_received.emit(String(m.get("n", "")), String(m.get("x", "")), bool(m.get("g", false)))
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
                out.append([int(e[0]), [Vector3(float(s[0]), float(s[1]), float(s[2])), float(s[3]), String(s[4]),
                        float(s[5]), car, xf]])
            if not out.is_empty():
                states_received.emit(out)
