extends Node
## Журнал вылетов. Godot пишет всё (print, ошибки) в user://logs/godot.log, при каждом запуске прошлый журнал
## переименовывается в godot<дата>.log. Если прошлый запуск не закрылся сам (не было выхода или паузы) —
## считаем, что игра вылетела: report — хвост прошлого журнала. main.gd показывает его игроку и отправляет
## на сервер (видно в Render → Logs), чтобы найти, на чём падает игра на конкретном телефоне/планшете.

const FLAG := "user://running.flag"
const TAIL_LINES := 60

var report := ""        # хвост журнала прошлого (оборвавшегося) запуска, "" — всё было нормально


func _enter_tree() -> void:
    if FileAccess.file_exists(FLAG):
        report = _previous_log_tail()
    _set_flag(true)


func _ready() -> void:
    print("[старт] %s, %s, Godot %s, видеокарта: %s %s" % [OS.get_model_name(), OS.get_name(),
            Engine.get_version_info().string, RenderingServer.get_video_adapter_vendor(),
            RenderingServer.get_video_adapter_name()])


## Короткая отметка в журнале: где была игра перед вылетом.
func mark(text: String) -> void:
    print("[%.1f] %s" % [Time.get_ticks_msec() / 1000.0, text])


func _notification(what: int) -> void:
    match what:
        NOTIFICATION_WM_CLOSE_REQUEST:
            print("[выход]")
            _set_flag(false)
        NOTIFICATION_APPLICATION_PAUSED:
            print("[пауза]")      # свернули: если система потом закроет игру — это не вылет
            _set_flag(false)
        NOTIFICATION_APPLICATION_RESUMED:
            print("[продолжение]")
            _set_flag(true)


func _set_flag(on: bool) -> void:
    if on:
        var f := FileAccess.open(FLAG, FileAccess.WRITE)
        if f:
            f.store_string(Time.get_datetime_string_from_system())
    elif FileAccess.file_exists(FLAG):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(FLAG))


func _previous_log_tail() -> String:
    var d := DirAccess.open("user://logs")
    if d == null:
        return "(журнал не найден)"
    var best := ""
    var best_t := 0
    for fn: String in d.get_files():
        if fn == "godot.log" or not fn.ends_with(".log"):
            continue
        var t := FileAccess.get_modified_time("user://logs/" + fn)
        if t >= best_t:
            best_t = t
            best = fn
    if best == "":
        return "(журнал прошлого запуска не найден)"
    var txt := FileAccess.get_file_as_string("user://logs/" + best)
    var lines := txt.split("\n")
    var start := maxi(0, lines.size() - TAIL_LINES)
    return "\n".join(lines.slice(start)).strip_edges()
