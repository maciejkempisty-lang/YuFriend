"""Generate a pixel-native, layered home and garden kit for YuFriend Studio.

All art is authored on the 1 px = 3 world-unit grid. No external packages.
The existing GameUI assets are left untouched; outputs live under
level-editor/assets/production/ and are registered in a separate project.
"""

from __future__ import annotations

import json
import math
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "level-editor/assets/production"
PROJECTS = ROOT / "level-editor/projects"

CREAM = "#f3efdc"
WALL = "#e9ead5"
SAGE = "#aebc9b"
GREEN = "#718d69"
DARK_GREEN = "#526e55"
WOOD = "#bd8c58"
WOOD_LIGHT = "#dfb678"
WOOD_DARK = "#805b3d"
INK = "#594638"
SKY = "#a9d6dc"
WATER = "#75aeb7"


def rgba(value: str | tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    if isinstance(value, tuple):
        return value
    value = value.removeprefix("#")
    return tuple(bytes.fromhex(value)) + (255,) if len(value) == 6 else tuple(bytes.fromhex(value))


class Canvas:
    def __init__(self, width: int, height: int, color=(0, 0, 0, 0)):
        self.w, self.h = width, height
        self.p = bytearray(bytes(rgba(color)) * (width * height))

    def px(self, x: int, y: int, color):
        if not (0 <= x < self.w and 0 <= y < self.h):
            return
        c = rgba(color)
        i = (y * self.w + x) * 4
        if c[3] == 255:
            self.p[i:i + 4] = bytes(c)
        elif c[3]:
            a = c[3] / 255
            old = self.p[i:i + 4]
            self.p[i:i + 4] = bytes((round(c[k] * a + old[k] * (1 - a)) for k in range(3))) + bytes([min(255, round(c[3] + old[3] * (1 - a)))])

    def rect(self, x: int, y: int, w: int, h: int, color):
        for yy in range(max(0, y), min(self.h, y + h)):
            for xx in range(max(0, x), min(self.w, x + w)):
                self.px(xx, yy, color)

    def ellipse(self, cx: int, cy: int, rx: int, ry: int, color):
        for y in range(cy - ry, cy + ry + 1):
            for x in range(cx - rx, cx + rx + 1):
                if (x - cx) ** 2 / max(1, rx * rx) + (y - cy) ** 2 / max(1, ry * ry) <= 1:
                    self.px(x, y, color)

    def line(self, x1: int, y1: int, x2: int, y2: int, color, width=1):
        steps = max(abs(x2 - x1), abs(y2 - y1), 1)
        for i in range(steps + 1):
            x = round(x1 + (x2 - x1) * i / steps)
            y = round(y1 + (y2 - y1) * i / steps)
            self.rect(x - width // 2, y - width // 2, width, width, color)

    def blit(self, other: "Canvas", x: int, y: int, width=None, height=None):
        width, height = width or other.w, height or other.h
        for yy in range(height):
            sy = min(other.h - 1, yy * other.h // height)
            for xx in range(width):
                sx = min(other.w - 1, xx * other.w // width)
                i = (sy * other.w + sx) * 4
                self.px(x + xx, y + yy, tuple(other.p[i:i + 4]))

    def save(self, rel: str):
        return self.save_path(OUT / rel)

    def save_path(self, path: Path):
        path.parent.mkdir(parents=True, exist_ok=True)
        raw = b"".join(b"\0" + bytes(self.p[y * self.w * 4:(y + 1) * self.w * 4]) for y in range(self.h))

        def chunk(kind: bytes, data: bytes):
            return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)

        path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
        return path


def load_png(path: Path) -> Canvas:
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    pos, compressed, w, h, color_type = 8, bytearray(), 0, 0, 0
    while pos < len(data):
        size = struct.unpack_from(">I", data, pos)[0]
        kind = data[pos + 4:pos + 8]
        payload = data[pos + 8:pos + 8 + size]
        pos += size + 12
        if kind == b"IHDR":
            w, h, depth, color_type, *_ = struct.unpack(">IIBBBBB", payload)
            assert depth == 8 and color_type in (2, 6)
        elif kind == b"IDAT":
            compressed.extend(payload)
        elif kind == b"IEND":
            break
    raw = zlib.decompress(compressed)
    canvas = Canvas(w, h)
    channels = 4 if color_type == 6 else 3
    stride, offset, previous = w * channels, 0, bytearray(w * channels)
    for y in range(h):
        filt = raw[offset]
        row = bytearray(raw[offset + 1:offset + 1 + stride])
        offset += stride + 1
        for i in range(stride):
            left = row[i - channels] if i >= channels else 0
            above = previous[i]
            upper_left = previous[i - channels] if i >= channels else 0
            if filt == 1:
                row[i] = (row[i] + left) & 255
            elif filt == 2:
                row[i] = (row[i] + above) & 255
            elif filt == 3:
                row[i] = (row[i] + ((left + above) // 2)) & 255
            elif filt == 4:
                p = left + above - upper_left
                distances = (abs(p - left), abs(p - above), abs(p - upper_left))
                row[i] = (row[i] + (left, above, upper_left)[distances.index(min(distances))]) & 255
            else:
                assert filt == 0
        if channels == 4:
            canvas.p[y * stride:(y + 1) * stride] = row
        else:
            canvas.p[y * w * 4:(y + 1) * w * 4] = b"".join(bytes(row[i:i + 3]) + b"\xff" for i in range(0, stride, 3))
        previous = row
    return canvas


def home_background():
    c = Canvas(480, 120, CREAM)
    c.rect(0, 0, 480, 70, WALL)
    for y in (17, 43, 63):
        for x in range(5 + (y % 7), 480, 57):
            c.rect(x, y, 7, 1, "#e4e4cd")
    c.rect(0, 70, 480, 16, "#c4cba8")
    c.rect(0, 69, 480, 2, "#e1dfb9")
    for x in range(0, 480, 24):
        c.rect(x, 73, 1, 12, "#aab790")
        c.rect(x + 1, 73, 1, 12, "#d1d5af")
    c.rect(0, 85, 480, 3, WOOD_DARK)
    c.rect(0, 86, 480, 2, WOOD_LIGHT)
    c.rect(0, 88, 480, 32, "#d6a365")
    for y, offset in ((88, 0), (96, 28), (104, 12), (112, 39)):
        c.rect(0, y, 480, 1, "#e8ba78")
        c.rect(0, y + 7, 480, 1, "#b98b58")
        for x in range(-offset, 480, 64):
            c.rect(x, y + 1, 1, 7, "#bd8e59")
            c.rect(x + 11, y + 3, 13, 1, "#dda96d")
    return c


def yard_background():
    c = Canvas(480, 120, SKY)
    c.rect(0, 0, 480, 35, "#acd8df")
    # Distant treetops and two soft clouds remain behind the fence.
    for x, y, r in ((100, 53, 24), (135, 52, 17), (179, 50, 23), (224, 53, 28), (276, 51, 22), (324, 52, 25), (381, 50, 21), (432, 53, 28)):
        c.ellipse(x, y, r, 13, "#8fae79")
        c.ellipse(x - 5, y - 3, max(4, r - 8), 9, "#a6bd83")
    for x in (144, 330):
        c.ellipse(x, 17, 17, 5, "#f2efdb")
        c.ellipse(x + 8, 14, 9, 7, "#f2efdb")
    c.rect(0, 82, 480, 38, "#a8bd79")
    c.rect(0, 88, 480, 4, "#92ad70")
    # The house is part of the background; its matching door remains separate.
    c.rect(0, 23, 72, 65, "#eee2c3")
    c.rect(0, 23, 72, 3, WOOD_DARK)
    for y in range(14, 24, 3):
        c.rect(0, y, 78 - (y - 14), 3, "#8b6648" if y % 2 else "#b28158")
    c.rect(0, 26, 3, 62, WOOD_DARK)
    c.rect(70, 26, 3, 62, WOOD_DARK)
    c.rect(0, 68, 72, 18, "#bec8a3")
    c.rect(0, 67, 72, 2, "#8fa47e")
    for x in (10, 66):
        c.rect(x, 69, 1, 16, "#aab690")
    # Door recess: exactly the 28x43 door sprite footprint at (26,45).
    c.rect(24, 43, 32, 47, "#79583e")
    c.rect(26, 45, 28, 43, "#584636")
    c.rect(21, 89, 38, 3, "#c69a65")
    c.rect(30, 92, 18, 5, "#c8ad78")
    c.rect(74, 61, 406, 27, "#cfa76e")
    for x in range(76, 480, 7):
        c.rect(x, 57, 6, 27, "#e6bd80")
        c.rect(x, 58, 1, 24, "#f3d09a")
        c.rect(x + 1, 57, 4, 1, "#f3d09a")
    c.rect(74, 67, 406, 2, "#976e49")
    c.rect(74, 80, 406, 2, "#976e49")
    # A tree frames the right edge without obscuring the playable stations.
    c.rect(460, 5, 9, 83, "#8e6b48")
    c.rect(463, 5, 2, 83, "#b58455")
    for x, y, rx in ((455, 18, 25), (470, 13, 26), (479, 27, 22)):
        c.ellipse(x, y, rx, 17, "#648b61")
        c.ellipse(x - 4, y - 4, rx - 5, 11, "#94b275")
    for x in range(83, 456, 19):
        c.rect(x, 99 + x % 4, 3, 1, "#789c66")
        c.rect(x + 5, 103 + x % 3, 2, 2, "#789c66")
    for x in (88, 238, 393):
        c.rect(x, 106, 2, 2, "#f3edcd")
        c.rect(x + 3, 107, 2, 2, "#f3edcd")
        c.rect(x + 2, 108, 1, 2, "#d3ad59")
    return c


def door():
    c = Canvas(28, 43)
    c.rect(0, 0, 28, 43, WOOD_DARK)
    c.rect(2, 2, 24, 39, WOOD)
    c.rect(4, 4, 20, 35, "#d8a86c")
    for y, h in ((6, 11), (21, 14)):
        c.rect(6, y, 16, h, "#8a6647")
        c.rect(8, y + 2, 12, h - 4, "#bd8f5d")
    c.rect(21, 22, 3, 3, "#ead7a9")
    c.rect(0, 40, 28, 3, "#715039")
    return c


def window_view(night=False, small=False):
    w, h = (30, 30) if small else (64, 60)
    c = Canvas(w, h)
    left, top, right, bottom = (5, 5, 25, 25) if small else (8, 8, 56, 51)
    c.rect(left, top, right - left, bottom - top, "#334c67" if night else "#a5d3d5")
    c.rect(left, bottom - (7 if small else 12), right - left, 7 if small else 12, "#526c5f" if night else "#9ebc79")
    for dx, dy in ((0, 2), (7, -2), (14, 1), (23, -1), (34, 2)):
        x = left + dx * (0.45 if small else 1)
        c.ellipse(round(x), bottom - (7 if small else 12) + dy, 4 if small else 7, 4 if small else 6, "#3e605b" if night else "#759966")
    if night:
        c.ellipse(right - (7 if small else 13), top + 7, 3 if small else 5, 3 if small else 5, "#f5e9b4")
        for x, y in ((12, 13), (24, 10), (40, 15), (18, 27), (43, 29)):
            if x < right - left:
                c.rect(left + x, top + y // (2 if small else 1), 1, 1, "#f1e6bf")
    else:
        for x, y in ((16, 15), (37, 20)):
            if small:
                x //= 2; y //= 2
            c.ellipse(left + x, top + y, 5 if small else 8, 2 if small else 3, "#eff0db")
    return c


def window_frame(small=False):
    w, h = (30, 30) if small else (64, 60)
    c = Canvas(w, h)
    left, top, right, bottom = (3, 3, 27, 27) if small else (4, 4, 60, 55)
    c.rect(left, top, right - left, 3, WOOD_DARK)
    c.rect(left, bottom - 3, right - left, 3, WOOD_DARK)
    c.rect(left, top, 3, bottom - top, WOOD_DARK)
    c.rect(right - 3, top, 3, bottom - top, WOOD_DARK)
    c.rect(left + 1, top + 1, right - left - 2, 1, WOOD_LIGHT)
    mid = w // 2
    c.rect(mid - 1, top + 3, 2, bottom - top - 6, "#9a704a")
    c.rect(left + 3, h // 2, right - left - 6, 2, "#9a704a")
    c.rect(left - 2, bottom, right - left + 4, 3, WOOD)
    c.rect(left, bottom, right - left, 1, WOOD_LIGHT)
    if not small:
        c.rect(1, 1, 62, 2, "#a37952")
        for x in (6, 49):
            c.rect(x, 7, 8, 32, "#f7efd5")
            c.rect(x + 2, 10, 2, 24, "#e5d7b9")
            c.rect(x, 38, 8, 3, "#7c956d")
    return c


def floor_lamp(on=False):
    c = Canvas(32, 57)
    if on:
        c.ellipse(16, 26, 15, 24, (255, 231, 165, 38))
        c.ellipse(16, 18, 13, 15, (255, 238, 180, 45))
    c.rect(14, 19, 4, 32, WOOD_DARK)
    c.rect(15, 19, 1, 31, "#d3b684")
    c.rect(8, 50, 16, 3, "#675840")
    c.rect(4, 53, 24, 2, "#b1976b")
    for y, width in ((3, 11), (6, 13), (9, 15), (12, 17), (15, 19)):
        c.rect(16 - width // 2, y, width, 4, WOOD_DARK)
        c.rect(17 - width // 2, y + 1, width - 2, 2, "#ffe5a6" if on else "#e2cb9a")
    c.rect(5, 18, 22, 2, WOOD)
    return c


def pendant(on=False):
    c = Canvas(20, 30)
    if on:
        c.ellipse(10, 22, 9, 8, (255, 229, 157, 45))
    c.rect(9, 0, 2, 12, WOOD_DARK)
    c.rect(5, 11, 10, 2, DARK_GREEN)
    c.rect(3, 13, 14, 4, GREEN)
    c.rect(5, 17, 10, 2, "#f6de9e" if on else "#c5ae7b")
    return c


def rug():
    c = Canvas(108, 19)
    c.ellipse(54, 10, 52, 8, "#768d66")
    c.ellipse(54, 9, 47, 7, "#a5b686")
    c.ellipse(54, 8, 42, 5, "#c9c9a1")
    for x in (24, 83):
        c.rect(x, 8, 8, 1, "#e0d8b0")
    return c


def plant():
    c = Canvas(28, 39)
    c.rect(13, 7, 2, 20, DARK_GREEN)
    for x, y, rx, ry in ((7, 16, 7, 4), (20, 10, 6, 5), (20, 22, 6, 4), (6, 8, 5, 5)):
        c.ellipse(x, y, rx, ry, DARK_GREEN)
        c.ellipse(x - 1, y - 1, max(2, rx - 2), max(2, ry - 1), "#94b478")
    c.rect(3, 26, 22, 3, WOOD_DARK)
    c.rect(5, 29, 18, 9, "#b9784d")
    c.rect(7, 30, 14, 6, "#d69b67")
    return c


def chest():
    c = Canvas(40, 23)
    c.ellipse(20, 21, 19, 2, (90, 67, 43, 75))
    c.rect(2, 5, 36, 16, WOOD_DARK)
    c.rect(4, 8, 32, 10, "#c79a65")
    c.rect(0, 3, 40, 5, "#a8794c")
    c.rect(2, 3, 36, 1, WOOD_LIGHT)
    c.rect(17, 8, 6, 3, "#819381")
    c.rect(17, 11, 6, 4, "#b8c7a2")
    return c


def kitchen():
    c = Canvas(88, 49)
    c.rect(0, 0, 88, 3, "#eee9d3")
    c.rect(0, 3, 88, 18, "#f5eedb")
    for x in range(0, 88, 8):
        c.rect(x, 3, 1, 18, "#ddd4b7")
    for y in (8, 16):
        c.rect(0, y, 88, 1, "#ddd4b7")
    c.rect(0, 20, 88, 4, WOOD_DARK)
    c.rect(0, 20, 88, 2, WOOD_LIGHT)
    c.rect(5, 24, 77, 24, DARK_GREEN)
    for x in (8, 32, 56):
        c.rect(x, 26, 22, 18, GREEN)
        c.rect(x + 2, 28, 18, 14, "#afc398")
        c.rect(x + 17, 34, 2, 2, WOOD_DARK)
    c.rect(2, 46, 84, 3, "#53694d")
    c.rect(33, 18, 22, 2, "#e5d2ad")
    c.rect(36, 20, 16, 2, "#95aaa0")
    c.rect(43, 11, 2, 9, WOOD_DARK)
    c.rect(43, 10, 7, 2, WOOD_DARK)
    return c


def gramophone():
    c = Canvas(58, 41)
    c.rect(2, 15, 54, 23, WOOD_DARK)
    c.rect(5, 18, 48, 17, "#bf925e")
    c.rect(8, 21, 18, 12, "#d5aa70")
    c.rect(29, 21, 20, 12, "#97734e")
    for i, col in enumerate(("#90a38b", "#dfc48e", "#b67c5f", "#d0bb8c")):
        c.rect(31 + 4 * i, 23, 3, 10, col)
    c.rect(0, 12, 58, 4, WOOD_DARK)
    c.rect(2, 12, 54, 1, WOOD_LIGHT)
    c.rect(7, 3, 35, 9, "#735a47")
    c.rect(9, 5, 31, 6, "#a8845b")
    c.rect(9, 10, 36, 3, "#614d3c")
    c.ellipse(24, 11, 10, 2, "#46574e")
    c.rect(1, 38, 6, 3, WOOD_DARK)
    c.rect(51, 38, 6, 3, WOOD_DARK)
    return c


def shelf():
    c = Canvas(62, 22)
    c.rect(0, 16, 62, 4, WOOD_DARK)
    c.rect(0, 16, 62, 1, WOOD_LIGHT)
    c.rect(5, 20, 3, 2, WOOD)
    c.rect(54, 20, 3, 2, WOOD)
    c.rect(7, 1, 16, 15, "#698478")
    c.rect(9, 3, 12, 11, "#bacbac")
    c.ellipse(15, 9, 4, 4, "#587161")
    c.ellipse(15, 9, 2, 2, "#e0c58d")
    for x, col in ((28, "#c5855c"), (34, "#d0b381"), (40, "#819884")):
        c.rect(x, 5, 5, 11, col)
        c.rect(x, 13, 5, 1, "#f1dcaa")
    c.ellipse(53, 9, 6, 5, DARK_GREEN)
    c.rect(50, 13, 6, 3, "#b37d56")
    return c


def guitar():
    c = Canvas(28, 58)
    c.ellipse(14, 55, 12, 2, (90, 67, 43, 75))
    c.rect(12, 1, 4, 31, WOOD_DARK)
    c.rect(13, 2, 2, 28, "#a7774b")
    for y in (5, 10, 15, 20, 25):
        c.rect(12, y, 4, 1, "#d9bd8a")
    c.ellipse(14, 44, 12, 11, WOOD_DARK)
    c.ellipse(14, 42, 10, 10, "#e2a866")
    c.ellipse(14, 34, 7, 7, WOOD_DARK)
    c.ellipse(14, 34, 6, 6, "#e2a866")
    c.ellipse(14, 37, 4, 4, WOOD_DARK)
    c.rect(9, 48, 10, 3, WOOD_DARK)
    for x in (12, 14, 16):
        c.rect(x, 4, 1, 44, "#f0d49d")
    c.rect(5, 51, 3, 6, DARK_GREEN)
    c.rect(20, 51, 3, 6, DARK_GREEN)
    return c


def portrait():
    c = Canvas(24, 25)
    c.rect(1, 2, 22, 21, WOOD_DARK)
    c.rect(3, 4, 18, 17, "#f3dfba")
    c.rect(5, 6, 14, 13, "#c1d0a7")
    c.ellipse(12, 12, 5, 5, "#d9a065")
    c.ellipse(8, 12, 3, 5, "#b67b4e")
    c.rect(15, 12, 2, 1, "#443b33")
    c.rect(17, 14, 2, 1, "#443b33")
    c.rect(3, 21, 18, 1, WOOD_LIGHT)
    return c


def clock():
    c = Canvas(18, 18)
    c.rect(1, 1, 16, 16, WOOD_DARK)
    c.rect(3, 3, 12, 12, "#f1e5c5")
    c.ellipse(9, 9, 5, 5, "#f8eed4")
    c.line(9, 9, 9, 5, INK)
    c.line(9, 9, 12, 10, INK)
    c.rect(8, 8, 2, 2, INK)
    return c


def canopy():
    c = Canvas(71, 49)
    c.rect(5, 6, 61, 3, DARK_GREEN)
    c.rect(9, 9, 53, 10, "#eee0bb")
    for x in range(10, 63, 10):
        c.ellipse(x + 4, 17, 5, 3, "#f4e7c9")
    c.rect(6, 18, 3, 30, WOOD_DARK)
    c.rect(62, 18, 3, 30, WOOD_DARK)
    c.rect(6, 18, 2, 28, WOOD_LIGHT)
    c.rect(63, 18, 1, 28, WOOD_LIGHT)
    c.rect(4, 47, 7, 2, WOOD_DARK)
    c.rect(60, 47, 7, 2, WOOD_DARK)
    return c


def yard_bed():
    c = Canvas(39, 16)
    c.ellipse(19, 11, 18, 5, WOOD_DARK)
    c.ellipse(19, 9, 17, 6, "#a7825d")
    c.ellipse(19, 7, 14, 4, "#e4d2a8")
    c.ellipse(19, 7, 10, 3, "#f3e6c6")
    return c


def water_bowl():
    c = Canvas(20, 10)
    c.rect(1, 2, 18, 6, "#628b87")
    c.rect(3, 2, 14, 3, "#b5dcda")
    c.rect(4, 4, 12, 1, WATER)
    c.rect(4, 8, 12, 1, "#4b7773")
    return c


def generate():
    assets = {
        "home/background.png": home_background(),
        "yard/background.png": yard_background(),
        "home/door.png": door(),
        "yard/door.png": door(),
        "home/window-view-day.png": window_view(),
        "home/window-view-night.png": window_view(True),
        "home/window-frame.png": window_frame(),
        "home/kitchen-window-view-day.png": window_view(False, True),
        "home/kitchen-window-view-night.png": window_view(True, True),
        "home/kitchen-window-frame.png": window_frame(True),
        "home/floor-lamp-off.png": floor_lamp(),
        "home/floor-lamp-on.png": floor_lamp(True),
        "home/pendant-lamp-off.png": pendant(),
        "home/pendant-lamp-on.png": pendant(True),
        "home/rug.png": rug(),
        "home/plant.png": plant(),
        "home/chest.png": chest(),
        "home/kitchen.png": kitchen(),
        "home/gramophone.png": gramophone(),
        "home/shelf.png": shelf(),
        "home/guitar.png": guitar(),
        "home/portrait.png": portrait(),
        "home/clock.png": clock(),
        "yard/canopy.png": canopy(),
        "yard/bed.png": yard_bed(),
        "yard/water-bowl.png": water_bowl(),
    }
    for rel, canvas in assets.items():
        canvas.save(rel)
    return assets


def build_project(assets):
    starter = json.loads((PROJECTS / "starter.json").read_text())
    project = json.loads(json.dumps(starter))
    project["name"] = "YuFriend · Zestaw graficzny domu i ogrodu"
    amap = {a["id"]: a for a in project["assets"]}
    for key, rel, level in (("home-background", "home/background.png", project["levels"][0]),
                            ("yard-background", "yard/background.png", project["levels"][1])):
        a = amap[key]
        a["id"] = "production-" + rel.removesuffix(".png").replace("/", "-")
        a["source"] = "res://level-editor/assets/production/" + rel
        a["width"], a["height"] = assets[rel].w, assets[rel].h
        level["elements"][0]["asset"] = a["id"]

    def register(rel, name):
        canvas = assets[rel]
        aid = "production-" + rel.removesuffix(".png").replace("/", "-")
        project["assets"].append(dict(id=aid, name=name, source="res://level-editor/assets/production/" + rel, width=canvas.w, height=canvas.h))
        return aid

    def add(level, rel, name, x, y, layer="middle", visible=True, script="none", params=None):
        aid = register(rel, name)
        canvas = assets[rel]
        level["elements"].append(dict(id=aid, name=name, asset=aid, layer=layer,
                                      x=x * 3, y=y * 3, width=canvas.w * 3, height=canvas.h * 3,
                                      pivot=dict(x=0, y=0), visible=visible, locked=False,
                                      static=True, script=script, params=params or {}))

    home, yard = project["levels"]
    # Replace the old door with the same production sprite in both locations.
    home["elements"] = [e for e in home["elements"] if e["id"] != "door"]
    yard["elements"] = [e for e in yard["elements"] if e["id"] not in ("gate", "shade")]
    home_positions = {"bed": (67, 95), "food": (162, 104), "toys": (365, 92), "ball": (297, 104)}
    yard_positions = {
        "ball": (319, 101), "garden": (169, 92), "dig": (220, 98),
        "fetch": (275, 92), "bush_0": (151, 58), "bush_1": (251, 58),
        "bush_2": (389, 58), "outing": (429, 96), "course": (367, 94),
        "puddle": (145, 101), "sprinkler": (440, 91),
    }
    for level, positions in ((home, home_positions), (yard, yard_positions)):
        for element in level["elements"]:
            if element["id"] in positions:
                x, y = positions[element["id"]]
                element["x"], element["y"] = x * 3, y * 3
    add(home, "home/rug.png", "Dywan", 201, 94, "background")
    add(home, "home/plant.png", "Roślina", 19, 49, "background")
    add(home, "home/portrait.png", "Portret Glorii", 65, 27, "background")
    add(home, "home/chest.png", "Skrzynia", 96, 64, "background")
    add(home, "home/kitchen.png", "Szafki kuchenne", 133, 40, "background")
    add(home, "home/kitchen-window-view-day.png", "Widok kuchnia dzień", 152, 14, "background")
    add(home, "home/kitchen-window-view-night.png", "Widok kuchnia noc", 152, 14, "background", False)
    add(home, "home/kitchen-window-frame.png", "Okno kuchenne", 152, 14, "background")
    add(home, "home/pendant-lamp-off.png", "Lampka kuchenna wyłączona", 188, 17, "background")
    add(home, "home/pendant-lamp-on.png", "Lampka kuchenna włączona", 188, 17, "background", False)
    add(home, "home/clock.png", "Zegar", 233, 35, "background")
    add(home, "home/window-view-day.png", "Widok za oknem dzień", 249, 23, "background")
    add(home, "home/window-view-night.png", "Widok za oknem noc", 249, 23, "background", False)
    add(home, "home/window-frame.png", "Okno i firanki", 249, 23, "background")
    add(home, "home/floor-lamp-off.png", "Lampa stojąca wyłączona", 318, 32, "background")
    add(home, "home/floor-lamp-on.png", "Lampa stojąca włączona", 318, 32, "background", False)
    add(home, "home/gramophone.png", "Komoda z gramofonem", 354, 47, "background")
    add(home, "home/shelf.png", "Półka", 350, 22, "background")
    add(home, "home/guitar.png", "Gitara", 408, 32, "middle")
    add(home, "home/door.png", "Drzwi domu", 444, 45, "background", True, "portal", {"target": "yard", "message": "Idziemy do ogrodu!"})
    add(yard, "yard/door.png", "Drzwi ogrodu — do domu", 26, 45, "middle", True, "portal", {"target": "home", "message": "Wracamy do domu."})
    add(yard, "yard/canopy.png", "Zadaszenie", 72, 47, "middle")
    add(yard, "yard/bed.png", "Legowisko ogrodowe", 87, 78, "background", True, "rest", {"energy": 15, "message": "Pora odpocząć.", "clip": "sleep"})
    add(yard, "yard/water-bowl.png", "Miska z wodą", 117, 84, "middle")
    # Preserve the original yard station assets in the library. Their positions
    # can be adjusted freely in Studio; the complete layered kit is editable.
    path = PROJECTS / "art-kit.json"
    path.write_text(json.dumps(project, ensure_ascii=False, indent=2) + "\n")
    return path


def render_preview(project_path: Path, level_id: str, night=False):
    project = json.loads(project_path.read_text())
    level = next(level for level in project["levels"] if level["id"] == level_id)
    sources = {asset["id"]: ROOT / asset["source"].removeprefix("res://") for asset in project["assets"]}
    scene = Canvas(480, 120)
    for layer in ("background", "middle", "foreground"):
        for element in level["elements"]:
            if element["layer"] != layer or not element["visible"] and not night:
                continue
            name = element["id"]
            if night:
                if name.endswith(("-day", "-off")):
                    continue
            elif name.endswith(("-night", "-on")):
                continue
            if not element["visible"] and not name.endswith(("-night", "-on")):
                continue
            sprite = load_png(sources[element["asset"]])
            scene.blit(sprite, round(element["x"] / 3), round(element["y"] / 3),
                       round(element["width"] / 3), round(element["height"] / 3))
    preview = Canvas(1440, 360)
    preview.blit(scene, 0, 0, 1440, 360)
    path = ROOT / "docs/images" / f"level-art-{level_id}{'-night' if night else ''}.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    raw = b"".join(b"\0" + bytes(preview.p[y * preview.w * 4:(y + 1) * preview.w * 4]) for y in range(preview.h))
    def chunk(kind, payload):
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xffffffff)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", preview.w, preview.h, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
    return path


if __name__ == "__main__":
    made = generate()
    project = build_project(made)
    for level_name, after_dark in (("home", False), ("home", True), ("yard", False)):
        render_preview(project, level_name, after_dark)
    print(f"Wrote {len(made)} PNG files to {OUT}")
    print(f"Wrote {project}")
