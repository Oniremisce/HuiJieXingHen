## =============================================================
## 《汇界星痕》T2.6 美术01：8 向占位帧条生成器（headless 工具脚本）
## -------------------------------------------------------------
## 运行（PowerShell，防 MCP 注册表污染）：
##   $env:GODOT_MCP_RUNTIME_PORT='abc'
##   Start-Process -Wait Godot.exe -ArgumentList '--headless','--path','<项目根>','--script','res://tools/gen_8dir_strips.gd'
## 产出：assets/sprites/characters/<char_id>_<idle|walk>_<dir>.png 共 48 张
##   帧规格：48×48/帧，横条；idle 4 帧（192×48，0.75s/帧≈1.333fps）
##           walk 8 帧（384×48，0.075s/帧≈13.333fps）；足底=帧底边，
##           接入 AnimatedSprite2D 时 offset=(0,-24) 对齐"origin=脚底"Y-sort 约定。
##   动画名映射：CharacterAnimator "<state>_<dir>"，DIR_NAMES 顺时针 0=东。
## 颜色：架构 §五 NPC 三色（#00BFFF/#9370DB/#3CB371）。
## =============================================================
extends SceneTree

const FRAME := 48
const BODY_W := 20
const BODY_H := 28
const DIRS: Array[String] = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
const CHARS := {
	"awakened_mech_01": Color("00BFFF"),
	"awakened_arcane_01": Color("9370DB"),
	"awakened_xian_01": Color("3CB371"),
}
const STATES := {
	"idle": {"frames": 4, "bob": [0, -1, 0, 1]},
	"walk": {"frames": 8, "bob": [0, -1, -2, -1, 0, -1, -2, -1]},
}


func _initialize() -> void:
	var made := 0
	for id: String in CHARS:
		var col: Color = CHARS[id]
		for state: String in STATES:
			var n: int = STATES[state]["frames"]
			var bob: Array = STATES[state]["bob"]
			for di in DIRS.size():
				var v := Vector2(cos(di * PI / 4.0), sin(di * PI / 4.0))
				var img := Image.create(FRAME * n, FRAME, false, Image.FORMAT_RGBA8)
				for f in n:
					_draw_frame(img, f * FRAME, int(bob[f]), v, col, state, f)
				var path := "res://assets/sprites/characters/%s_%s_%s.png" % [id, state, DIRS[di]]
				img.save_png(path)
				made += 1
				print("[gen] %s %dx%d" % [path, img.get_width(), img.get_height()])
	var ok := true
	for id: String in CHARS:
		for state: String in STATES:
			var n2: int = STATES[state]["frames"]
			for di in DIRS.size():
				var p := "res://assets/sprites/characters/%s_%s_%s.png" % [id, state, DIRS[di]]
				var t := Image.load_from_file(ProjectSettings.globalize_path(p))
				if t == null or t.get_width() != FRAME * n2 or t.get_height() != FRAME:
					ok = false
					print("[gen][ERR] 回读校验失败: %s" % p)
	print("[gen] %s 共 %d 张（期望 48）" % ["OK" if ok else "FAIL", made])
	quit(0 if ok else 1)


func _draw_frame(img: Image, ox: int, bob: int, v: Vector2, col: Color, state: String, f: int) -> void:
	var cx := ox + FRAME / 2
	var feet_y := FRAME  # 足底=帧底边（bob 为负整体上抬）
	var top := feet_y - BODY_H + bob
	var left := cx - BODY_W / 2
	for y in range(top, feet_y + bob):
		for x in range(left, left + BODY_W):
			var c := col
			if y < top + 8:
				c = col.lightened(0.12)  # 头/肩带
			elif y >= feet_y + bob - 6:
				c = col.darkened(0.25)   # 腿/足带
			img.set_pixel(x, y, c)
	# 朝向楔形：尖朝 dir（0=东，顺时针），walk 摆动 ±1px 模拟迈步
	var center := Vector2(cx, top + BODY_H / 2.0)
	var perp := Vector2(-v.y, v.x)
	var swing := 0.0
	if state == "walk":
		swing = 1.0 if (f % 4) < 2 else -1.0
	var tip := center + v * 18.0
	var b1 := center + v * 10.0 + perp * (4.0 + swing)
	var b2 := center + v * 10.0 - perp * (4.0 + swing)
	_fill_tri(img, tip, b1, b2, col.darkened(0.45))


func _fill_tri(img: Image, a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	var minx := int(floor(min(a.x, min(b.x, c.x))))
	var maxx := int(ceil(max(a.x, max(b.x, c.x))))
	var miny := int(floor(min(a.y, min(b.y, c.y))))
	var maxy := int(ceil(max(a.y, max(b.y, c.y))))
	for y in range(miny, maxy + 1):
		for x in range(minx, maxx + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			if _in_tri(Vector2(x + 0.5, y + 0.5), a, b, c):
				img.set_pixel(x, y, col)


func _in_tri(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 := _sgn(p, a, b)
	var d2 := _sgn(p, b, c)
	var d3 := _sgn(p, c, a)
	var neg := d1 < 0.0 or d2 < 0.0 or d3 < 0.0
	var pos := d1 > 0.0 or d2 > 0.0 or d3 > 0.0
	return not (neg and pos)


func _sgn(p1: Vector2, p2: Vector2, p3: Vector2) -> float:
	return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y)
