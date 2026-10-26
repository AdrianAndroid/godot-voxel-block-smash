#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""CQ-20261026/S01：精细青蛙 frog_02 程序化自制生成器。

素材来源：程序化自制（本脚本即制作过程记录），无外部素材、无版权问题。
坐标约定（MagicaVoxel .vox）：x 右、y 深（+y=青蛙正面）、z 上；vox2json 映射 (x, z, -y)。
目标：4000~5000 体素；头部加厚、眼白/瞳孔、腹部、四肢、脚趾、背部轮廓、橙色嘴线。
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from gen_frog_vox import write_vox  # 复用 .vox 写出（含调色板/坐标校验）

# 调色板（color_id -> RGB）。1~7 沿用 D05；8/9 为本轮新增（浅绿/橙）
PALETTE = {
	1: (0x4C, 0xAF, 0x50),  # 绿（主体）
	2: (0xF4, 0x43, 0x36),  # 红（保留兼容）
	3: (0x21, 0x96, 0xF3),  # 蓝（保留兼容）
	4: (0xFF, 0xEB, 0x3B),  # 黄（腹部）
	5: (0x9C, 0x27, 0xB0),  # 紫（保留兼容）
	6: (0xFA, 0xFA, 0xFA),  # 白（眼白）
	7: (0x21, 0x21, 0x21),  # 深灰（瞳孔）
	8: (0x8B, 0xC3, 0x4A),  # 浅绿（背脊/四肢内侧）
	9: (0xFF, 0x98, 0x00),  # 橙（嘴线/脚趾）
}
GREEN, YELLOW, WHITE, DARK, LGREEN, ORANGE = 1, 4, 6, 7, 8, 9


def gen_frog02():
	voxels = {}

	def put(x, y, z, c):
		voxels[(x, y, z)] = c

	def fill_ellipsoid(cx, cy, cz, rx, ry, rz, color, only_if=None):
		x0, x1 = int(cx - rx - 1), int(cx + rx + 1)
		y0, y1 = int(cy - ry - 1), int(cy + ry + 1)
		z0, z1 = int(cz - rz - 1), int(cz + rz + 1)
		for x in range(x0, x1 + 1):
			for y in range(y0, y1 + 1):
				for z in range(z0, z1 + 1):
					if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 + ((z - cz) / rz) ** 2 <= 1.0:
						if only_if is None or only_if(x, y, z):
							put(x, y, z, color)

	# 1) 身体：实心椭球（允许实心，分层消除路径由外向内天然存在）
	fill_ellipsoid(0, 0, 9, 11.3, 8.2, 7.2, GREEN)
	# 2) 头部加厚：前上方第二椭球，与身体融合成蛙头轮廓
	fill_ellipsoid(0, 2.5, 13.0, 9.5, 6.0, 4.2, GREEN)
	# 3) 眼睛：白色球，头顶前方两侧
	fill_ellipsoid(-5.0, 4.0, 16.5, 3.2, 3.2, 3.2, WHITE)
	fill_ellipsoid(5.0, 4.0, 16.5, 3.2, 3.2, 3.2, WHITE)
	# 4) 瞳孔：深灰小球，位于眼睛最前端
	fill_ellipsoid(-5.0, 6.6, 16.8, 1.5, 1.5, 1.5, DARK)
	fill_ellipsoid(5.0, 6.6, 16.8, 1.5, 1.5, 1.5, DARK)
	# 5) 腹部：前下方身体块改黄色（y 前向、z 偏低）
	for (x, y, z), c in list(voxels.items()):
		if c == GREEN and y >= 3 and 3 <= z <= 8 and (x / 9.0) ** 2 + ((z - 5.5) / 4.5) ** 2 <= 1.0:
			put(x, y, z, YELLOW)
	# 6) 背部轮廓：背脊浅绿条纹（顶部中线带）
	for (x, y, z), c in list(voxels.items()):
		if c == GREEN and abs(x) <= 2 and -7 <= y <= 1 and z >= 13:
			put(x, y, z, LGREEN)
	# 7) 后腿大腿：两侧大椭球
	fill_ellipsoid(-10.5, -2.5, 4.0, 4.2, 5.5, 4.0, GREEN)
	fill_ellipsoid(10.5, -2.5, 4.0, 4.2, 5.5, 4.0, GREEN)
	# 8) 后脚掌：前伸扁块 + 三趾
	for sx in (-1, 1):
		fill_ellipsoid(sx * 10.0, 2.5, 1.2, 3.4, 4.2, 1.4, LGREEN)
		for toe in (-2, 0, 2):
			fill_ellipsoid(sx * 10.0 + toe, 6.0, 1.0, 1.0, 1.8, 1.0, ORANGE)
	# 9) 前腿：细柱 + 前掌 + 三趾
	for sx in (-1, 1):
		fill_ellipsoid(sx * 7.0, 4.0, 2.8, 1.7, 1.7, 3.0, GREEN)
		fill_ellipsoid(sx * 7.0, 5.5, 1.0, 2.2, 2.6, 1.1, LGREEN)
		for toe in (-1.6, 0, 1.6):
			fill_ellipsoid(sx * 7.0 + toe, 7.6, 0.9, 0.9, 1.5, 0.9, ORANGE)
	# 10) 嘴线：头部正面橙色弧线（最前排、嘴角略下弯）
	for (x, y, z), c in list(voxels.items()):
		if c == GREEN and 9 <= z <= 10 and y >= 7:
			put(x, y, z, ORANGE)

	# 平移到非负坐标
	mx = min(v[0] for v in voxels)
	my = min(v[1] for v in voxels)
	mz = min(v[2] for v in voxels)
	return [(x - mx, y - my, z - mz, c) for (x, y, z), c in sorted(voxels.items())]


def main():
	root = os.path.join(os.path.dirname(__file__), '..', '..')
	frog = gen_frog02()
	n, size = write_vox(os.path.join(root, 'assets/vox_source/frog_02.vox'), frog)
	print('frog_02.vox: %d voxels, size %dx%dx%d' % (n, size[0], size[1], size[2]))
	if not (4000 <= n <= 5000):
		sys.exit('frog_02 方块数 %d 超出 4000~5000 目标' % n)
	colors = {}
	for v in frog:
		colors[v[3]] = colors.get(v[3], 0) + 1
	print('逐色计数:', {k: colors[k] for k in sorted(colors)})


if __name__ == '__main__':
	main()
