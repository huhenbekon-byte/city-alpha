extends RefCounted

const FactionData := preload("res://scripts/faction_data.gd")
## Оружие. Обычный игрок: кулак и купленный пистолет.
## Милиция и КГБ — табельное, ОПГ — своё (выдаётся по рангу).

const LIST := {
    "fist": {"name": "Кулак", "short": "КУЛАК", "model": "", "damage": 15, "range": 1.7, "rate": 0.55},
    "pm": {"name": "Пистолет Макарова", "short": "ПМ", "model": "pistol", "damage": 34, "range": 40.0, "rate": 0.35,
            "muzzle": Vector3(0.16, 0.05, 0.0)},
    "nagant": {"name": "Револьвер «Наган»", "short": "НАГАН", "model": "revolver", "damage": 40, "range": 35.0, "rate": 0.5,
            "muzzle": Vector3(0.21, 0.04, 0.0)},
    "aks": {"name": "АКС-74У", "short": "АКС", "model": "aksu", "damage": 26, "range": 55.0, "rate": 0.12,
            "muzzle": Vector3(0.47, 0.08, 0.0)},
    "ak": {"name": "АК-74", "short": "АК", "model": "ak", "damage": 30, "range": 70.0, "rate": 0.12,
            "muzzle": Vector3(0.55, 0.10, 0.0)},
    "obrez": {"name": "Обрез", "short": "ОБРЕЗ", "model": "sawedoff", "damage": 80, "range": 14.0, "rate": 0.9,
            "muzzle": Vector3(0.49, 0.05, 0.0)},
}

## Пистолет на рынке для всех (кроме фракций у них своё).
const PISTOL_PRICE := 12000

## Что выдаёт фракция: [оружие, с какого ранга].
const FACTION_GUNS := {
    "police": [["pm", 1], ["aks", 3]],
    "kgb": [["pm", 1], ["aks", 2]],
    "tyap": [["nagant", 1], ["obrez", 2], ["ak", 4]],
    "universam": [["nagant", 1], ["obrez", 2], ["ak", 4]],
    "solnce": [["nagant", 1], ["obrez", 2], ["ak", 4]],
    "kavkaz": [["nagant", 1], ["obrez", 2], ["ak", 4]],
}


static func info(id: String) -> Dictionary:
    return LIST.get(id, LIST["fist"])


static func model_path(id: String) -> String:
    var m := String(info(id).get("model", ""))
    return "" if m == "" else "res://models/guns/%s.gltf" % m


## Доступное оружие: кулак, свой пистолет, выданное фракцией по рангу.
static func available(faction: String, rank: int, has_pistol: bool) -> Array[String]:
    var out: Array[String] = ["fist"]
    if has_pistol:
        out.append("pm")
    for g: Array in FACTION_GUNS.get(FactionData.base(faction) if faction != "" else "", []):
        var gid := String(g[0])
        if rank >= int(g[1]) and not gid in out:
            out.append(gid)
    return out
