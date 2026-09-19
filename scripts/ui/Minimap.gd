## =============================================================
## 《汇界星痕》T2.3 小地图（HUD 右上占位）
## -------------------------------------------------------------
## 架构 §2.6：箱庭线框缩小版 + 主角白点 + 神像金点（亮/暗），
## 每 0.4s 刷新一次（主角移动跟随）。出怪/任务点标注 T6.x 扩展。
## =============================================================
extends Node2D

const _MS := preload("res://scripts/core/MapSystem.gd")

const VIEW_SIZE := Vector2(160.0, 120.0)
const REFRESH_INTERVAL := 0.4

var _xform := Transform2D.IDENTITY
var _font: Font
var _acc := 0.0


func _ready() -> void:
	_font = ThemeDB.fallback_font
	queue_redraw()


func _process(delta: float) -> void:
	_acc += delta
	if _acc >= REFRESH_INTERVAL:
		_acc = 0.0
		queue_redraw()


func _draw() -> void:
	var ms := get_node("/root/MapSystem")
	# 底板
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0.05, 0.06, 0.09, 0.72))
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0.85, 0.9, 1.0, 0.3), false, 1.0)

	var loops: Array = ms.get_outline_loops()
	if loops.is_empty():
		return
	var bounds: Rect2 = _MS.bounds_of(loops)
	var inner := Rect2(Vector2(6.0, 6.0), VIEW_SIZE - Vector2(12.0, 12.0))
	_xform = _MS.fit_transform(bounds, inner)

	# 可行走区线框
	for loop in loops:
		var pts := _xform_points(loop)
		pts.append(pts[0])
		draw_polyline(pts, Color(0.8, 0.86, 1.0, 0.55), 1.0)

	var tml: TileMapLayer = ms.get_ground_layer()

	# 神像
	for s: Dictionary in ms.get_current_scene_shrines():
		var local := s.pos as Vector2
		if tml != null:
			local = tml.to_local(s.pos)
		var pos: Vector2 = _xform * local
		draw_circle(pos, 3.0 if s.lit else 2.0, Color(1.0, 0.84, 0.3) if s.lit else Color(0.4, 0.4, 0.46))

	# 主角
	var player := get_tree().current_scene.get_node_or_null("Player")
	if player != null:
		var local: Vector2 = player.global_position
		if tml != null:
			local = tml.to_local(local)
		var pos: Vector2 = _xform * local
		draw_circle(pos, 2.5, Color(0.95, 0.97, 1.0))
		draw_circle(pos, 4.5, Color(0.95, 0.97, 1.0, 0.25))


func _xform_points(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(points.size())
	for i in points.size():
		out[i] = _xform * points[i]
	return out
