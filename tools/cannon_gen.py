#!/usr/bin/env python3
"""CQ-20261026/S06：程序化自制卡通炮台素材（CC0，作者：本项目，2026-10-26）。

方法：Pillow 矢量分层绘制（圆角梯形底座 / 圆润炮身 / 带深色炮口的炮管），
透明背景 PNG，256x256。炮身主体为白色+明暗描边，运行时按 palette color_id
用 modulate 染色（模型唯一颜色源）。炮管独立图层，运行时绕炮身中心旋转瞄准。

输出：
  assets/cannons/cannon_base.png    底座
  assets/cannons/cannon_body.png    炮身（白色待染色）
  assets/cannons/cannon_barrel.png  炮管（朝上，枢轴=图中心，炮口深色）

运行：python3 tools/cannon_gen.py
"""

import math
import os

from PIL import Image, ImageDraw

SIZE = 256
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "cannons")

OUTLINE = (38, 38, 46, 255)        # 深描边
METAL = (150, 156, 168, 255)       # 炮管金属灰
METAL_DARK = (96, 100, 112, 255)
MUZZLE = (30, 30, 36, 255)         # 炮口深色
BASE_C = (66, 70, 82, 255)         # 底座
BASE_HI = (96, 101, 116, 255)
WHITE = (255, 255, 255, 255)
SHADE = (208, 212, 220, 255)       # 炮身暗部（染色后仍可读）


def _canvas() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def _rounded_trapezoid(d: ImageDraw.ImageDraw, cx: int, y0: int, y1: int,
                       w_top: int, w_bot: int, fill: tuple, outline: tuple, wd: int = 6) -> None:
    pts = [(cx - w_top // 2, y0), (cx + w_top // 2, y0),
           (cx + w_bot // 2, y1), (cx - w_bot // 2, y1)]
    d.polygon(pts, fill=fill, outline=outline, width=wd)


def gen_base() -> None:
    img, d = _canvas()
    cx = SIZE // 2
    # 两层圆角梯形底座 + 顶部高光条
    _rounded_trapezoid(d, cx, 176, 236, 150, 206, BASE_C, OUTLINE)
    _rounded_trapezoid(d, cx, 150, 182, 120, 156, BASE_HI, OUTLINE)
    d.rounded_rectangle([cx - 58, 146, cx + 58, 162], radius=8, fill=(120, 126, 142, 255))
    img.save(os.path.join(OUT, "cannon_base.png"))


def gen_body() -> None:
    img, d = _canvas()
    cx, cy, r = SIZE // 2, 150, 86
    # 炮身：圆球 hull，白色主体（待染色）+ 下侧暗部 + 深描边 + 高光
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=WHITE, outline=OUTLINE, width=7)
    # 暗部（下半球弧形带）
    d.arc([cx - r + 10, cy - r + 26, cx + r - 10, cy + r + 18], 20, 160,
          fill=SHADE, width=22)
    # 高光点
    d.ellipse([cx - 44, cy - 56, cx - 8, cy - 26], fill=(255, 255, 255, 200))
    # 炮耳（两侧轴钉）
    for sx in (-1, 1):
        ex = cx + sx * (r - 6)
        d.ellipse([ex - 12, cy - 22, ex + 12, cy + 2], fill=SHADE, outline=OUTLINE, width=4)
    img.save(os.path.join(OUT, "cannon_body.png"))


def gen_barrel() -> None:
    img, d = _canvas()
    # 枢轴 = 图中心 (128,150) 与炮身圆心对齐；炮管朝上（-y）
    px, py = SIZE // 2, 150
    w, length = 46, 118
    x0, x1 = px - w // 2, px + w // 2
    y1 = py + 26          # 管尾没入炮身
    y0 = py - length      # 管口
    # 管身（金属灰渐变三段）
    d.rounded_rectangle([x0, y0, x1, y1], radius=14, fill=METAL, outline=OUTLINE, width=6)
    d.rectangle([x0 + 8, y0 + 10, x0 + 16, y1 - 8], fill=(178, 184, 196, 255))  # 亮棱
    d.rectangle([x1 - 16, y0 + 10, x1 - 8, y1 - 8], fill=METAL_DARK)            # 暗棱
    # 加强环
    d.rounded_rectangle([x0 - 5, py - 40, x1 + 5, py - 22], radius=8,
                        fill=METAL_DARK, outline=OUTLINE, width=4)
    # 炮口（深色外箍 + 内孔）
    d.rounded_rectangle([x0 - 7, y0 - 10, x1 + 7, y0 + 22], radius=12,
                        fill=METAL_DARK, outline=OUTLINE, width=5)
    d.ellipse([px - 13, y0 - 6, px + 13, y0 + 12], fill=MUZZLE)
    img.save(os.path.join(OUT, "cannon_barrel.png"))


def gen_flash() -> None:
    # 炮口闪光：64x64 径向渐变星芒（加色叠加用，白色核心）
    s = 64
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    px = img.load()
    cx = cy = s / 2 - 0.5
    for y in range(s):
        for x in range(s):
            dx, dy = (x - cx) / (s / 2), (y - cy) / (s / 2)
            r = math.sqrt(dx * dx + dy * dy)
            star = max(0.0, 1.0 - abs(dx) * 3.2) + max(0.0, 1.0 - abs(dy) * 3.2)
            a = max(0.0, 1.0 - r) * 0.85 + min(1.0, star) * max(0.0, 1.0 - r) * 0.6
            a = min(1.0, a)
            if a > 0.01:
                px[x, y] = (255, 244, 200, int(255 * a))
    img.save(os.path.join(OUT, "cannon_flash.png"))


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    gen_base()
    gen_body()
    gen_barrel()
    gen_flash()
    for name in ("cannon_base", "cannon_body", "cannon_barrel", "cannon_flash"):
        p = os.path.join(OUT, name + ".png")
        img = Image.open(p)
        assert img.mode == "RGBA"
        bbox = img.getbbox()
        assert bbox is not None
        print("%s bbox=%s" % (name, bbox))
    print("CANNON_GEN_OK")


if __name__ == "__main__":
    main()
