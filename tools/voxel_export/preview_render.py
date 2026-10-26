#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""模型 JSON 正交投影预览（ painter's algorithm ），用于 S01 交付证据。
用法: python3 preview_render.py 模型.json 输出前缀
"""
import json
import sys

from PIL import Image, ImageDraw

SCALE = 18


def render(voxels, palette, path, axis_h, axis_v, axis_depth, flip_h=False, depth_reverse=False):
	# axis_h/axis_v/axis_depth: 0=x,1=y,2=z；depth_reverse=True 表示观察方向为轴负向（深度越大越远）
	pts = []
	for v in voxels:
		p = (v['x'], v['y'], v['z'])
		pts.append((p[axis_h], p[axis_v], p[axis_depth], v['color_id']))
	hs = [p[0] for p in pts]
	vs = [p[1] for p in pts]
	w = (max(hs) - min(hs) + 2) * SCALE
	h = (max(vs) - min(vs) + 2) * SCALE
	img = Image.new('RGB', (w, h), (18, 18, 24))
	draw = ImageDraw.Draw(img)
	# 深度排序：远的先画
	for hh, vv, dd, cid in sorted(pts, key=lambda p: p[2], reverse=depth_reverse):
		rgb = palette[str(cid)]
		color = (int(rgb[0] * 255), int(rgb[1] * 255), int(rgb[2] * 255))
		x = (hh - min(hs)) * SCALE
		if flip_h:
			x = w - x - SCALE
		y = h - (vv - min(vs)) * SCALE - SCALE
		draw.rectangle([x, y, x + SCALE - 1, y + SCALE - 1], fill=color)
	img.save(path)
	return img.size


def main():
	src, prefix = sys.argv[1], sys.argv[2]
	doc = json.load(open(src))
	voxels = doc['voxels']
	palette = doc['palette']
	# godot 坐标：x 右、y 上、z 朝相机（frog 正面 = -z 方向）
	s1 = render(voxels, palette, prefix + '_front.png', 0, 1, 2, depth_reverse=True)   # 正面：观察者位于 -z，远=+z 先画
	s2 = render(voxels, palette, prefix + '_side.png', 2, 1, 0, flip_h=True, depth_reverse=False)  # 侧面：观察者位于 +x，远=-x 先画
	print('front %s, side %s' % (s1, s2))


if __name__ == '__main__':
	main()
