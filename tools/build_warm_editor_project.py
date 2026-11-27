"""Register the selected warm home and matching garden as layered editor art.

HD source sprites stay untouched. Each editor element is scaled to the
1440×360 world using its visible alpha bounds, so transparent margins do not
change the intended placement. This script only writes project metadata.
"""

from __future__ import annotations

import json
import struct
from pathlib import Path

from build_level_editor_art import Canvas, load_png

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "level-editor/assets/warm-v1"
PROJECTS = ROOT / "level-editor/projects"


def dimensions(path: Path) -> tuple[int, int]:
    data = path.read_bytes()[:24]
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    return struct.unpack(">II", data[16:24])


def alpha_bounds(path: Path) -> tuple[int, int, int, int]:
    if path.read_bytes()[25] == 2:  # Opaque RGB view behind a window.
        w, h = dimensions(path)
        return 0, 0, w, h
    sprite = load_png(path)
    xs, ys = [], []
    for i, alpha in enumerate(sprite.p[3::4]):
        if alpha >= 128:
            xs.append(i % sprite.w)
            ys.append(i // sprite.w)
    if not xs:
        raise ValueError(f"No visible pixels in {path}")
    return min(xs), min(ys), max(xs) + 1, max(ys) + 1


def asset_id(rel: str) -> str:
    return "warm-v1-" + rel.removesuffix(".png").replace("/", "-")


def main() -> None:
    starter = json.loads((PROJECTS / "starter.json").read_text())
    project = {key: starter[key] for key in ("format", "version", "startLevel")}
    project["name"] = "Ciepły dom i ogród · wariant 1"
    project["assets"] = []
    project["levels"] = []
    for level in starter["levels"]:
        copy = {key: value for key, value in level.items() if key != "elements"}
        copy["elements"] = []
        project["levels"].append(copy)
    home, yard = project["levels"]

    sources = {}
    for path in sorted(ART.rglob("*.png")):
        rel = path.relative_to(ART).as_posix()
        w, h = dimensions(path)
        aid = asset_id(rel)
        project["assets"].append({"id": aid, "name": rel.removesuffix(".png").replace("-hd", "").replace("/", " · ").replace("-", " "),
                                  "source": "res://level-editor/assets/warm-v1/" + rel,
                                  "width": w, "height": h})
        sources[rel] = (aid, w, h, path)

    bounds = {}

    def add(level, rel, name, rect, layer="background", visible=True,
            script="none", params=None, static=True, align_to=None):
        aid, width, height, path = sources[rel]
        if rect == "full":
            element = {"id": "warm-" + level["id"] + "-background", "name": name, "asset": aid,
                       "layer": "background", "x": 0, "y": 0, "width": 1440, "height": 360,
                       "pivot": {"x": 0, "y": 0}, "visible": True, "locked": False,
                       "static": True, "script": "none", "params": {}}
        else:
            key = align_to or rel
            if key not in bounds:
                bounds[key] = alpha_bounds(sources[key][3])
            left, top, right, bottom = bounds[key]
            bw, bh = right - left, bottom - top
            x, y, w, h = rect
            sx, sy = w / bw, h / bh
            out_w, out_h = width * sx * 3, height * sy * 3
            if layer == "middle":
                pivot = {"x": left + bw / 2, "y": top + bh}
                px, py = (x + w / 2) * 3, (y + h) * 3
            else:
                pivot = {"x": 0, "y": 0}
                px, py = (x - left * sx) * 3, (y - top * sy) * 3
            element = {"id": "warm-" + level["id"] + "-" + rel.removesuffix(".png").split("/")[-1],
                       "name": name, "asset": aid, "layer": layer,
                       "x": round(px, 3), "y": round(py, 3),
                       "width": round(out_w, 3), "height": round(out_h, 3),
                       "pivot": pivot, "visible": visible, "locked": False,
                       "static": static, "script": script, "params": params or {}}
        level["elements"].append(element)

    add(home, "home/background-hd.png", "Ściana i podłoga", "full")
    add(home, "home/kitchen-window-day-hd.png", "Za oknem kuchni · dzień", (135, 21, 28, 23))
    add(home, "home/kitchen-window-night-hd.png", "Za oknem kuchni · noc", (135, 21, 28, 23), visible=False)
    add(home, "home/main-window-day-hd.png", "Za dużym oknem · dzień", (233, 25, 69, 51))
    add(home, "home/main-window-night-hd.png", "Za dużym oknem · noc", (233, 25, 69, 51), visible=False)
    add(home, "home/plant-hd.png", "Roślina", (7, 43, 39, 44))
    add(home, "home/portrait-hd.png", "Obraz", (52, 28, 34, 30))
    add(home, "home/chest-hd.png", "Wiklinowa skrzynia", (67, 63, 46, 24))
    add(home, "home/kitchen-hd.png", "Kuchnia", (109, 42, 99, 45))
    add(home, "home/kitchen-window-frame-hd.png", "Okno kuchenne · rama", (133, 18, 32, 30))
    add(home, "home/pendant-lamp-off-hd.png", "Lampka wisząca · off", (176, 17, 22, 27))
    add(home, "home/pendant-lamp-on-hd.png", "Lampka wisząca · on", (176, 17, 22, 27), visible=False,
        align_to="home/pendant-lamp-off-hd.png")
    add(home, "home/clock-hd.png", "Zegar", (211, 35, 21, 22))
    add(home, "home/main-window-frame-hd.png", "Duże okno · rama i firanki", (230, 22, 75, 56))
    add(home, "home/floor-lamp-off-hd.png", "Lampa stojąca · off", (312, 37, 31, 51))
    add(home, "home/floor-lamp-on-hd.png", "Lampa stojąca · on", (312, 37, 31, 51), visible=False,
        align_to="home/floor-lamp-off-hd.png")
    add(home, "home/gramophone-hd.png", "Komoda i gramofon", (346, 47, 60, 40))
    add(home, "home/shelf-hd.png", "Półka", (342, 23, 70, 23))
    add(home, "home/guitar-hd.png", "Gitara", (413, 40, 27, 47))
    add(home, "home/door-hd.png", "Drzwi do ogrodu", (444, 44, 30, 43),
        script="portal", params={"target": "yard", "message": "Idziemy do ogrodu!"})
    add(home, "home/rug-hd.png", "Dywan", (192, 91, 117, 22))
    add(home, "yard/bed-hd.png", "Legowisko", (38, 87, 68, 25),
        script="rest", params={"energy": 15, "message": "Pora odpocząć.", "clip": "sleep"})
    add(home, "home/food-hd.png", "Miska z jedzeniem", (130, 96, 51, 18), layer="middle",
        script="feed", params={"fullness": 22, "message": "Mniam!", "clip": "eat_loop"})
    add(home, "home/toy-basket-hd.png", "Kosz z zabawkami", (352, 91, 48, 23), layer="middle",
        script="message", params={"text": "W koszu czekają zabawki.", "duration": 4})
    add(home, "yard/ball-hd.png", "Piłka", (303, 102, 12, 12), layer="middle",
        static=False, script="ball", params={"play": 15, "contact": 5, "arc": 100})

    add(yard, "yard/background-hd.png", "Tło ogrodu z domem", "full")
    add(yard, "yard/window-hd.png", "Okno domu", (40, 42, 24, 25))
    add(yard, "yard/door-hd.png", "Drzwi do domu", (7, 44, 29, 43),
        script="portal", params={"target": "home", "message": "Wracamy do domu."})
    add(yard, "yard/bush-hd.png", "Krzak 1", (258, 50, 34, 32))
    add(yard, "yard/bush-hd.png", "Krzak 2", (343, 50, 36, 32))
    add(yard, "yard/fetch-hd.png", "Mata do aportowania", (294, 91, 59, 17))
    add(yard, "yard/puddle-hd.png", "Kałuża", (355, 87, 46, 12))
    add(yard, "yard/dig-hd.png", "Miejsce kopania", (229, 79, 44, 16))
    add(yard, "yard/bed-hd.png", "Legowisko ogrodowe", (88, 70, 45, 23),
        script="rest", params={"energy": 15, "message": "Pora odpocząć.", "clip": "sleep"})
    add(yard, "yard/pergola-hd.png", "Pergola", (72, 29, 92, 64), layer="middle")
    add(yard, "yard/bowl-hd.png", "Miska z wodą", (135, 80, 20, 12), layer="middle")
    add(yard, "yard/garden-hd.png", "Grządka", (167, 55, 61, 38), layer="middle")
    add(yard, "yard/watering-can-hd.png", "Konewka", (209, 79, 17, 15), layer="middle")
    add(yard, "yard/ball-hd.png", "Piłka", (290, 84, 13, 13), layer="middle",
        static=False, script="ball", params={"play": 15, "contact": 5, "arc": 100})
    add(yard, "yard/agility-hd.png", "Przeszkoda", (310, 71, 43, 22), layer="middle")
    add(yard, "yard/sprinkler-hd.png", "Zraszacz", (402, 69, 42, 26), layer="middle")
    add(yard, "yard/sign-hd.png", "Tabliczka", (450, 63, 24, 35), layer="middle")

    # Two placements of the same bush need distinct element IDs.
    seen = set()
    for level in project["levels"]:
        for element in level["elements"]:
            base = element["id"]
            suffix = 2
            while element["id"] in seen:
                element["id"] = f"{base}-{suffix}"
                suffix += 1
            seen.add(element["id"])
    path = PROJECTS / "art-kit-warm.json"
    path.write_text(json.dumps(project, ensure_ascii=False, indent=2) + "\n")
    asset_info = {asset["id"]: asset for asset in project["assets"]}
    cache = {}
    for level in project["levels"]:
        for night in ((False, True) if level["id"] == "home" else (False,)):
            scene = Canvas(480, 120)
            ordered = sorted(enumerate(level["elements"]), key=lambda item: (
                ("background", "middle", "foreground").index(item[1]["layer"]),
                item[1]["y"] if item[1]["layer"] == "middle" else 0, item[0]))
            for _, element in ordered:
                eid = element["id"]
                if night:
                    if eid.endswith(("-day-hd", "-off-hd")):
                        continue
                    if not element["visible"] and not eid.endswith(("-night-hd", "-on-hd")):
                        continue
                elif not element["visible"]:
                    continue
                asset = asset_info[element["asset"]]
                if element["asset"] not in cache:
                    cache[element["asset"]] = load_png(ROOT / asset["source"].removeprefix("res://"))
                sprite = cache[element["asset"]]
                x = (element["x"] - element["pivot"]["x"] * element["width"] / asset["width"]) / 3
                y = (element["y"] - element["pivot"]["y"] * element["height"] / asset["height"]) / 3
                scene.blit(sprite, round(x), round(y), max(1, round(element["width"] / 3)),
                           max(1, round(element["height"] / 3)))
            preview = Canvas(1440, 360)
            preview.blit(scene, 0, 0, 1440, 360)
            label = f"warm-art-{level['id']}{'-night' if night else ''}.png"
            preview.save_path(ROOT / "docs/images" / label)
    print(f"Wrote {path} with {len(project['assets'])} assets")


if __name__ == "__main__":
    main()
