## =============================================================
## 《汇界星痕》T2.3 世界大地图视图
## -------------------------------------------------------------
## 架构 §2.3：区块按解锁态三档着色——未解锁=暗黑剪影 / 解锁=区块
## 体系色半透明 / 当前区块=加亮描边；区块名标注。
## 神像圆点（亮=金色可点击 / 暗=灰），点击已点亮神像由 MapUI 弹
## 确认框 → Transition.transition_portal（神像 id 反查目标场景）。
## hit_test 供 MapUI 左键命中查询（局部坐标，半径 16px）。
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
	var all_polys: Array = []
	for id: String in ms.REGIONS:
		all_polys.append(ms.REGIONS[id].world_poly)
	var bounds: Rect2 = _MS.bounds_of(all_polys)
	_xform = _MS.fit_transform(bounds, view_rect)
	var cur: String = ms.get_current_region_id()

	# 区块
	for id: String in ms.REGIONS:
		var info: Dictionary = ms.REGIONS[id]
		var pts := _xform_points(info.world_poly)
		var unlocked: bool = ms.is_region_unlocked(id)
		var base: Color = info.color
		var lp: Vector2 = _xform * (info.label_pos as Vector2)
		if unlocked:
			draw_colored_polygon(pts, Color(base.r, base.g, base.b, 0.28))
			var border := base
			border.a = 1.0 if id == cur else 0.7
			draw_polyline(_closed(pts), border, 2.5 if id == cur else 1.5)
			draw_string(_font, lp, str(info.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
					Color(1, 1, 1, 0.95) if id == cur else Color(1, 1, 1, 0.75))
		else:
			draw_colored_polygon(pts, Color(0.05, 0.05, 0.07, 0.95))
			draw_polyline(_closed(pts), Color(0.28, 0.28, 0.34, 0.9), 1.0)
			draw_string(_font, lp, str(info.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
					Color(1, 1, 1, 0.32))

	# 神像
	for id: String in ms.SHRINES:
		var s: Dictionary = ms.SHRINES[id]
		var pos: Vector2 = _xform * (s.world_pos as Vector2)
		var lit: bool = ms.is_region_unlocked(s.region)
		if lit:
			draw_circle(pos, 7.0, Color(1.0, 0.84, 0.3))
			draw_arc(pos, 12.0, 0.0, TAU, 32, Color(1.0, 0.84, 0.3, 0.55), 1.5)
		else:
			draw_circle(pos, 5.0, Color(0.3, 0.3, 0.36))
		draw_string(_font, pos + Vector2(13.0, 4.0), str(s.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
				Color(1, 1, 1, 0.9) if lit else Color(1, 1, 1, 0.4))


## 左键命中已点亮神像 → 返回神像 id（未命中 ""）
func hit_test(local: Vector2) -> String:
	var ms := get_node("/root/MapSystem")
	for id: String in ms.SHRINES:
		var s: Dictionary = ms.SHRINES[id]
		if not ms.is_region_unlocked(s.region):
			continue
		if (_xform * (s.world_pos as Vector2)).distance_to(local) <= 16.0:
			return id
	return ""


# ---------------------------------------------------------------
# 内部
# ---------------------------------------------------------------

func _xform_points(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(points.size())
	for i in points.size():
		out[i] = _xform * (points[i] as Vector2)
	return out


func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out
