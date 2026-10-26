#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成 T01 导入测试夹具（tests/fixtures/，TEST_ONLY，非正式素材）。"""
import json, os

PALETTE = {str(k): [round(r / 255, 5), round(g / 255, 5), round(b / 255, 5), 1.0]
	for k, (r, g, b) in {
		1: (0x4C, 0xAF, 0x50), 2: (0xF4, 0x43, 0x36), 3: (0x21, 0x96, 0xF3),
		4: (0xFF, 0xEB, 0x3B), 5: (0x9C, 0x27, 0xB0), 6: (0xFA, 0xFA, 0xFA),
		7: (0x21, 0x21, 0x21)}.items()}


def make_doc(voxels):
	return {'schema_version': 2, 'voxel_size': 1.0, 'palette': PALETTE, 'voxels': voxels}


def grid_voxels(n):
	"""紧凑填充 n 块的合法体素集。"""
	out = []
	x = y = z = 0
	while len(out) < n:
		out.append({'x': x, 'y': y, 'z': z, 'color_id': (len(out) % 5) + 1})
		x += 1
		if x >= 12:
			x = 0; y += 1
			if y >= 10:
				y = 0; z += 1
	return out


def main():
	d = os.path.join(os.path.dirname(__file__), '..', '..', 'tests', 'fixtures')
	def w(name, doc):
		with open(os.path.join(d, name), 'w') as f:
			json.dump(doc, f, separators=(',', ':'))
		print('written', name, len(doc['voxels']))
	w('model_300.json', make_doc(grid_voxels(300)))
	w('model_1200.json', make_doc(grid_voxels(1200)))
	w('model_6000.json', make_doc(grid_voxels(6000)))  # CQ-20261026：新上限边界合法
	bad_dup = grid_voxels(300); bad_dup[5] = dict(bad_dup[4])
	w('bad_dup.json', make_doc(bad_dup))
	bad_color = grid_voxels(300); bad_color[7]['color_id'] = 99
	w('bad_color.json', make_doc(bad_color))
	w('bad_count.json', make_doc(grid_voxels(10)))
	w('bad_count_high.json', make_doc(grid_voxels(6001)))  # CQ-20261026：超 6000 拒绝
	bad_schema = make_doc(grid_voxels(300)); bad_schema['schema_version'] = 1
	w('bad_schema.json', bad_schema)


if __name__ == '__main__':
	main()
