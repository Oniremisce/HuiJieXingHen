## =============================================================
## 《汇界星痕》T2.3 箱庭图视图
## -------------------------------------------------------------
## 架构 §2.3：半透明暗底（MapUI 面板底）+ 可行走区描边线框 +
## 标注层：主角体系色箭头（体系待定暂用白）/ 任务 NPC 金色菱形
##（组 quest_npc）/ 神像亮暗圆点 / 出口（MVP 预留）。
## 数据源：MapSystem.get_outline_loops / get_current_scene_shrines /
## get_current_scene_exits；fit_transform 等比映射到面板内区。
## =============================================================
extends Node2D

const _MS := preload("res://scripts/core/MapSystem.gd")

## 视图绘制区（MapUI 面板内区，局部坐标）
var view_rect := Rect2(0, 0, 100, 100)

var _xform := Transform2D.IDENTITY
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font


func _draw() -> void:
	var ms := get_node("/root/MapSystem")
	var loops: Array = ms.get_outline_loops()
	if loops.is_empty():
		draw_string(_font, Vector2(24.0, 60.0), "（当前场景无地面数据）",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.6))
		return
	var bounds: Rect2 = _MS.bounds_of(loops)
	_xform = _MS.fit_transform(bounds, view_rect)

	# 可行走区线框
	for loop in loops:
		var pts := _xform_points(loop)
		pts.append(pts[0])
		draw_polyline(pts, Color(0.85, 0.9, 1.0, 0.7), 1.5)

	var tml: TileMapLayer = ms.get_ground_layer()

	# 神像（亮=金色圆+外环 / 暗=灰色圆）
	for s: Dictionary in ms.get_current_scene_shrines():
		var pos := _to_view(s.pos, tml)
		if s.lit:
			draw_circle(pos, 6.0, Color(1.0, 0.84, 0.3))
			draw_arc(pos, 10.0, 0.0, TAU, 28, Color(1.0, 0.84, 0.3, 0.5), 1.0)
		else:
			draw_circle(pos, 5.0, Color(0.35, 0.35, 0.4))
		draw_string(_font, pos + Vector2(12.0, -6.0), str(s.name),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.85))

	# 任务 NPC（金色菱形，组 quest_npc）
	for n in get_tree().get_nodes_in_group("quest_npc"):
		var pos := _to_view(n.global_position, tml)
		_draw_diamond(pos, 6.0, Color(1.0, 0.84, 0.3))

	# 出口标注（MVP 空列表，预留）
	for _e in ms.get_current_scene_exits():
		pass

	# 主角（体系色待定 → 白色三角箭头，指向朝向）
	var player := get_tree().current_scene.get_node_or_null("Player")
	if player != null:
		var pos := _to_view(player.global_position, tml)
		_draw_arrow(pos)


# ---------------------------------------------------------------
# 内部
# ---------------------------------------------------------------

func _to_view(global_pos: Vector2, tml: TileMapLayer) -> Vector2:
	var local := global_pos
	if tml != null:
		local = tml.to_local(global_pos)
	return _xform * local


func _xform_points(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(points.size())
	for i in points.size():
		out[i] = _xform * points[i]
	return out


func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out


func _draw_diamond(center: Vector2, r: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -r), center + Vector2(r, 0),
		center + Vector2(0, r), center + Vector2(-r, 0),
	]), color)


func _draw_arrow(center: Vector2) -> void:
	var pts := PackedVector2Array([
		center + Vector2(0, -9), center + Vector2(7, 7), center + Vector2(0, 3), center + Vector2(-7, 7),
	])
	draw_colored_polygon(pts, Color(0.95, 0.97, 1.0))
	draw_polyline(_closed(pts), Color(0.1, 0.12, 0.16), 1.0)
