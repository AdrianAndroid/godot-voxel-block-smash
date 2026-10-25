#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""自制体素资产生成器：第一关简易青蛙 + 非对称三轴标色夹具。
素材来源：程序化自制（等效 Goxel 手工绘制兜底），无版权问题。
坐标约定（MagicaVoxel .vox）：x 右、y 深、z 上；导出到 Godot 时映射 (x, z, -y)。
"""
import struct, os, sys

PALETTE = {  # color_id -> (r, g, b) 0-255，与 GDD 执行默认值 D05 一致
	1: (0x4C, 0xAF, 0x50),  # 绿
	2: (0xF4, 0x43, 0x36),  # 红
	3: (0x21, 0x96, 0xF3),  # 蓝
	4: (0xFF, 0xEB, 0x3B),  # 黄
	5: (0x9C, 0x27, 0xB0),  # 紫
	6: (0xFA, 0xFA, 0xFA),  # 白
	7: (0x21, 0x21, 0x21),  # 深灰
}
GREEN, RED, BLUE, YELLOW, WHITE, DARK = 1, 2, 3, 4, 6, 7


def write_vox(path, voxels):
	"""voxels: list of (x, y, z, color_id)，坐标须为 0..255。"""
	assert voxels, "空模型"
	for x, y, z, c in voxels:
		assert 0 <= x <= 255 and 0 <= y <= 255 and 0 <= z <= 255, "坐标越界"
		assert c in PALETTE, "未知颜色"
	sx = max(v[0] for v in voxels) + 1
	sy = max(v[1] for v in voxels) + 1
	sz = max(v[2] for v in voxels) + 1
	xyzi = struct.pack('<i', len(voxels)) + b''.join(
		struct.pack('<4B', x, y, z, c) for x, y, z, c in voxels)
	rgba = bytearray()
	for i in range(1, 257):
		rgb = PALETTE.get(i, (0, 0, 0))
		rgba += struct.pack('<4B', rgb[0], rgb[1], rgb[2], 255)
	children = (b'SIZE' + struct.pack('<ii', 12, 0) + struct.pack('<iii', sx, sy, sz)
		+ b'XYZI' + struct.pack('<ii', len(xyzi), 0) + xyzi
		+ b'RGBA' + struct.pack('<ii', len(rgba), 0) + bytes(rgba))
	data = b'VOX ' + struct.pack('<i', 150) + b'MAIN' + struct.pack('<ii', 0, len(children)) + children
	with open(path, 'wb') as f:
		f.write(data)
	return len(voxels), (sx, sy, sz)


def gen_frog():
	"""简易青蛙：绿色椭球身体、黄色腹部、白眼睛、深灰瞳孔、四条腿。"""
	voxels = {}
	def put(x, y, z, c):
		voxels[(x, y, z)] = c
	# 身体：中心(0,0,4)，半径(5,3.5,3.5)填充椭球
	for x in range(-5, 6):
		for y in range(-4, 5):
			for z in range(0, 9):
				if (x / 5.0) ** 2 + (y / 3.5) ** 2 + ((z - 4) / 3.5) ** 2 <= 1.0:
					put(x, y, z, GREEN)
	# 腹部：前下方改黄色（y>=2 且 z<=3 的身体块）
	for (x, y, z), c in list(voxels.items()):
		if c == GREEN and y >= 2 and z <= 3:
			put(x, y, z, YELLOW)
	# 眼睛：白色球 r=1.7，位于头顶前方两侧
	for sx in (-2.5, 2.5):
		for x in range(-5, 6):
			for y in range(-4, 5):
				for z in range(0, 10):
					if (x - sx) ** 2 + (y - 1.5) ** 2 + (z - 7.5) ** 2 <= 1.7 ** 2:
						put(x, y, z, WHITE)
	# 瞳孔：深灰小球，位于眼睛最前端
	for sx in (-2.5, 2.5):
		for x in range(-5, 6):
			for y in range(-4, 6):
				for z in range(0, 10):
					if (x - sx) ** 2 + (y - 2.9) ** 2 + (z - 7.5) ** 2 <= 0.9 ** 2:
						put(x, y, z, DARK)
	# 后腿：x ±[3,5]，y [-3,-1]，z [0,1]
	for sx in (1, -1):
		for x in range(3, 6):
			for y in range(-3, 0):
				for z in range(0, 2):
					put(sx * x, y, z, GREEN)
	# 前腿：x ±[3,4]，y [1,3]，z [0,1]
	for sx in (1, -1):
		for x in range(3, 5):
			for y in range(1, 4):
				for z in range(0, 2):
					put(sx * x, y, z, GREEN)
	# 平移到非负坐标
	mx = min(v[0] for v in voxels)
	my = min(v[1] for v in voxels)
	mz = min(v[2] for v in voxels)
	return [(x - mx, y - my, z - mz, c) for (x, y, z), c in sorted(voxels.items())]


def gen_axis_fixture():
	"""非对称三轴夹具：四色各一，轴跨度 3/4/5 互不相同，方向可判。"""
	return [
		(0, 0, 0, GREEN),   # 原点
		(3, 0, 0, RED),     # +x 3
		(0, 4, 0, BLUE),    # +y 4（vox 深度）
		(0, 0, 5, YELLOW),  # +z 5（vox 上）
	]


def main():
	root = os.path.join(os.path.dirname(__file__), '..', '..')
	frog = gen_frog()
	n, size = write_vox(os.path.join(root, 'assets/vox_source/frog_01.vox'), frog)
	print('frog_01.vox: %d voxels, size %dx%dx%d' % (n, size[0], size[1], size[2]))
	if not (300 <= n <= 1200):
		sys.exit('青蛙方块数 %d 超出 300~1200 约束' % n)
	colors = {}
	for v in frog:
		colors[v[3]] = colors.get(v[3], 0) + 1
	print('逐色计数:', {PALETTE and k: colors[k] for k in sorted(colors)})
	n2, size2 = write_vox(os.path.join(root, 'tests/fixtures/axis_fixture.vox'), gen_axis_fixture())
	print('axis_fixture.vox: %d voxels, size %dx%dx%d' % (n2, size2[0], size2[1], size2[2]))


if __name__ == '__main__':
	main()
