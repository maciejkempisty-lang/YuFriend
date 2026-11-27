"""Export the selected HD art to separate pixel-native editor PNGs.

This is a deterministic nearest-neighbor packaging step: source artwork is
preserved in warm-v1/, while warm-v1-native/ contains 480×160 backgrounds and
individual transparent sprites sized to the scene's 1 px = 3 world-unit grid.
"""

from __future__ import annotations

import json
from pathlib import Path

from build_level_editor_art import Canvas, load_png
from build_warm_editor_project import ROOT, alpha_bounds

SOURCE = ROOT / "level-editor/projects/art-kit-warm.json"
OUT = ROOT / "level-editor/assets/warm-v1-native"
PROJECT = ROOT / "level-editor/projects/art-kit-warm-native.json"
TOP_EXTRA = 20
BOTTOM_EXTRA = 20
SCENE_WIDTH = 480
SCENE_HEIGHT = 120 + TOP_EXTRA + BOTTOM_EXTRA


def crop_resize(sprite: Canvas, box: tuple[int, int, int, int], w: int, h: int) -> Canvas:
    x0, y0, x1, y1 = box
    result = Canvas(w, h)
    for y in range(h):
        sy = min(y1 - 1, y0 + (y * (y1 - y0)) // h)
        for x in range(w):
            sx = min(x1 - 1, x0 + (x * (x1 - x0)) // w)
            source = (sy * sprite.w + sx) * 4
            target = (y * w + x) * 4
            result.p[target:target + 4] = sprite.p[source:source + 4]
    return result


def extend_background(center: Canvas) -> Canvas:
    """Add wall/sky above and floor/grass below without scaling the old scene."""
    result = Canvas(SCENE_WIDTH, SCENE_HEIGHT)
    stride = SCENE_WIDTH * 4
    for y in range(SCENE_HEIGHT):
        if y < TOP_EXTRA:
            source_y = TOP_EXTRA - 1 - y
        elif y < TOP_EXTRA + center.h:
            source_y = y - TOP_EXTRA
        else:
            source_y = center.h - 1 - (y - TOP_EXTRA - center.h)
        result.p[y * stride:(y + 1) * stride] = center.p[source_y * stride:(source_y + 1) * stride]
    return result


def main() -> None:
    project = json.loads(SOURCE.read_text())
    original_assets = {asset["id"]: asset for asset in project["assets"]}
    native_assets = {}
    sprite_cache = {}
    bounds_cache = {}
    for level in project["levels"]:
        for element in level["elements"]:
            original = original_assets[element["asset"]]
            original_path = ROOT / original["source"].removeprefix("res://")
            source_rel = original_path.relative_to(ROOT / "level-editor/assets/warm-v1")
            basename = source_rel.name.replace("-hd.png", ".png")
            native_rel = Path(level["id"]) / basename
            native_key = native_rel.as_posix()
            w0, h0 = original["width"], original["height"]
            if element["id"].endswith("background"):
                box = (0, 0, w0, h0)
                native_w, native_h = SCENE_WIDTH, 120
            else:
                source_for_bounds = original_path
                if basename.endswith("-on.png"):
                    source_for_bounds = original_path.with_name(original_path.name.replace("-on-hd", "-off-hd"))
                if source_for_bounds not in bounds_cache:
                    bounds_cache[source_for_bounds] = alpha_bounds(source_for_bounds)
                box = bounds_cache[source_for_bounds]
                native_w = max(1, round((box[2] - box[0]) * element["width"] / w0 / 3))
                native_h = max(1, round((box[3] - box[1]) * element["height"] / h0 / 3))

            if native_key not in native_assets:
                if original_path not in sprite_cache:
                    sprite_cache[original_path] = load_png(original_path)
                native = crop_resize(sprite_cache[original_path], box, native_w, native_h)
                if element["id"].endswith("background"):
                    native = extend_background(native)
                    native_h = SCENE_HEIGHT
                native.save_path(OUT / native_rel)
                aid = "warm-v1-native-" + native_key.removesuffix(".png").replace("/", "-")
                native_assets[native_key] = {"id": aid, "name": element["name"],
                    "source": "res://level-editor/assets/warm-v1-native/" + native_key,
                    "width": native_w, "height": native_h}
            asset = native_assets[native_key]

            if element["id"].endswith("background"):
                element.update(asset=asset["id"], x=0, y=0, width=SCENE_WIDTH * 3, height=SCENE_HEIGHT * 3,
                               pivot={"x": 0, "y": 0})
            else:
                sx, sy = element["width"] / w0, element["height"] / h0
                left = element["x"] - element["pivot"]["x"] * sx + box[0] * sx
                top = element["y"] - element["pivot"]["y"] * sy + box[1] * sy
                if element["layer"] == "middle":
                    pivot = {"x": asset["width"] / 2, "y": asset["height"]}
                    element.update(asset=asset["id"], x=round(left + asset["width"] * 3 / 2, 3),
                                   y=round(top + asset["height"] * 3, 3),
                                   width=asset["width"] * 3, height=asset["height"] * 3, pivot=pivot)
                else:
                    element.update(asset=asset["id"], x=round(left, 3), y=round(top, 3),
                                   width=asset["width"] * 3, height=asset["height"] * 3,
                                   pivot={"x": 0, "y": 0})
                element["y"] = round(element["y"] + TOP_EXTRA * 3, 3)
        level["height"] = SCENE_HEIGHT * 3
        level["spawn"]["y"] += TOP_EXTRA * 3
        level["walk"]["y"] += TOP_EXTRA * 3
    project["name"] = "Ciepły dom i ogród · grafiki 480×160"
    project["assets"] = list(native_assets.values())
    PROJECT.write_text(json.dumps(project, ensure_ascii=False, indent=2) + "\n")
    asset_map = {asset["id"]: asset for asset in project["assets"]}
    for level in project["levels"]:
        for night in ((False, True) if level["id"] == "home" else (False,)):
            scene = Canvas(SCENE_WIDTH, SCENE_HEIGHT)
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
                asset = asset_map[element["asset"]]
                sprite = load_png(ROOT / asset["source"].removeprefix("res://"))
                x = (element["x"] - element["pivot"]["x"] * element["width"] / asset["width"]) / 3
                y = (element["y"] - element["pivot"]["y"] * element["height"] / asset["height"]) / 3
                scene.blit(sprite, round(x), round(y), round(element["width"] / 3), round(element["height"] / 3))
            preview = Canvas(SCENE_WIDTH * 3, SCENE_HEIGHT * 3)
            preview.blit(scene, 0, 0, SCENE_WIDTH * 3, SCENE_HEIGHT * 3)
            label = f"warm-native-{level['id']}{'-night' if night else ''}.png"
            preview.save_path(ROOT / "docs/images" / label)
    print(f"Wrote {len(native_assets)} native PNGs and {PROJECT}")


if __name__ == "__main__":
    main()
