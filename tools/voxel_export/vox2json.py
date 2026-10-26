#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""vox -> 模型 JSON（schema_version=2）导出工具。

用法: python3 vox2json.py 输入.vox 输出.json
坐标映射：godot(x, y, z) = (vox.x, vox.z, -vox.y)，再按最小角归一为非负。
颜色：按精确 RGB 匹配 GDD D05 七色调色板，未知颜色报错拒绝。
校验：重复坐标 / 未知颜色 / 数量越界（夹具可用 --no-range-check 跳过数量校验）。
"""
import json, struct, sys

PALETTE = {
	1: (0x4C, 0xAF, 0x50), 2: (0xF4, 0x43, 0x36), 3: (0x21, 0x96, 0xF3),
	4: (0xFF, 0xEB, 0x3B), 5: (0x9C, 0x27, 0xB0), 6: (0xFA, 0xFA, 0xFA),
	7: (0x21, 0x21, 0x21),
	8: (0x8B, 0xC3, 0x4A), 9: (0xFF, 0x98, 0x00),  # CQ-20261026 frog_02：浅绿/橙
}
RGB_TO_ID = {v: k for k, v in PALETTE.items()}
MIN_VOXELS, MAX_VOXELS = 300, 6000  # CQ-20261026：容量上限 1200→6000（frog_02 目标 4000~5000）


def fail(msg):
	sys.exit('导出拒绝: ' + msg)


def read_vox(path):
	data = open(path, 'rb').read()
	if data[:4] != b'VOX ':
		fail('不是有效 .vox 文件: ' + path)
	pos, voxels, file_palette, n_models = 8, [], None, 0
	while pos + 12 <= len(data):
		cid = data[pos:pos + 4]
		size = struct.unpack_from('<i', data, pos + 4)[0]
		body = pos + 12
		if cid == b'XYZI':
			n_models += 1
			n = struct.unpack_from('<i', data, body)[0]
			for i in range(n):
				x, y, z, c = struct.unpack_from('<4B', data, body + 4 + i * 4)
				voxels.append((x, y, z, c))
		elif cid == b'RGBA':
			file_palette = [tuple(data[body + i * 4: body + i * 4 + 3]) for i in range(256)]
		pos = body + size
	if file_palette is None:
		fail('文件缺少 RGBA 调色板')
	if n_models != 1:
		fail('仅支持单模型文件，实际 %d 个' % n_models)
	return voxels, file_palette


def main():
	args = [a for a in sys.argv[1:] if not a.startswith('--')]
	src, dst = args[0], args[1]
	check_range = '--no-range-check' not in sys.argv
	voxels, file_palette = read_vox(src)
	seen = {}
	out = []
	for i, (vx, vy, vz, ci) in enumerate(voxels):
		gx, gy, gz = vx, vz, -vy  # vox -> godot 轴向
		if (gx, gy, gz) in seen:
			fail('voxels[%d] 重复坐标 (%d,%d,%d)，首次出现于 voxels[%d]' % (i, gx, gy, gz, seen[(gx, gy, gz)]))
		seen[(gx, gy, gz)] = i
		rgb = file_palette[ci - 1] if 1 <= ci <= 256 else None
		if rgb not in RGB_TO_ID:
			fail('voxels[%d] 颜色索引 %d RGB%s 不在 D05 调色板' % (i, ci, str(rgb)))
		out.append((gx, gy, gz, RGB_TO_ID[rgb]))
	if check_range and not (MIN_VOXELS <= len(out) <= MAX_VOXELS):
		fail('方块数 %d 超出 %d~%d' % (len(out), MIN_VOXELS, MAX_VOXELS))
	# 最小角归一
	mx = min(v[0] for v in out); my = min(v[1] for v in out); mz = min(v[2] for v in out)
	out = sorted((x - mx, y - my, z - mz, c) for x, y, z, c in out)
	doc = {
		'schema_version': 2,
		'voxel_size': 1.0,
		'palette': {str(k): [round(r / 255, 5), round(g / 255, 5), round(b / 255, 5), 1.0]
			for k, (r, g, b) in sorted(PALETTE.items())},
		'voxels': [{'x': x, 'y': y, 'z': z, 'color_id': c} for x, y, z, c in out],
	}
	with open(dst, 'w') as f:
		json.dump(doc, f, separators=(',', ':'))
	colors = {}
	for v in out:
		colors[v[3]] = colors.get(v[3], 0) + 1
	print('完成: %s -> %s, %d 块, 逐色 %s' % (src, dst, len(out), dict(sorted(colors.items()))))


if __name__ == '__main__':
	main()
