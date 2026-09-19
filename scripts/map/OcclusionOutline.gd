## =============================================================
## 《汇界星痕》T2.3 遮挡描边（架构 §1.2；bug 修复版）
## -------------------------------------------------------------
## 原理：作为宿主实体（玩家/NPC 实体根）的子节点，收集宿主的可见形状
## （Polygon2D/ColorRect/Sprite2D，跳过阴影/调试件），在自身（z_index=20，
## 压过前景遮挡物）上用 outline.gdshader 绘制纯白描边：
##   描边 = 逐边 2px 外扩条带（端部外延补角），并与前景遮挡物可见形状
##   求交（Geometry2D.intersect_polygons）——仅被遮挡部分的描边可见，
##   未被遮挡部分保持原样（修复：旧版 8 向实心印章会把整圈+内部画白）。
## 强度 = 前景遮挡面积占宿主视觉面积的比例（复用 Y-sort 排序数据：
## 仅当「遮挡项排序 y > 宿主脚部 y」且投影 AABB 重叠才计入，无射线检测），
## 指数平滑淡入淡出。玩家与 NPC 均适用。
## 挂载：PlayerController / Interactable 运行时自动安装（无需改 .tscn）。
## =============================================================
extends Node2D

const OUTLINE_PX := 2.0
const STRENGTH_GAIN := 1.6  # 遮挡比例 → 强度增益（约 62% 覆盖即全强度）
const FADE_SPEED := 10.0    # 指数平滑速度

## 不参与描边/遮挡判定的视觉件（阴影、调试可视化、头顶 UI）
const _SKIP_NAMES := ["Shade", "DebugVisual", "HintRoot", "NameTag", "AnimSprite"]

## 当前描边强度（0=无遮挡，1=完全遮挡；MCP 验证可读）
var strength := 0.0
## 本帧实际绘制的描边片段数（0=无可见描边；MCP 验证可读）
var piece_count := 0

var _material: ShaderMaterial
var _drawables: Array = []       # 宿主可见形状（Polygon2D/ColorRect/Sprite2D）
var _occluder_polys: Array = []  # 本帧前景遮挡物形状（全局坐标）


func _ready() -> void:
	z_index = 20  # 压过 z=0 的前景遮挡物（低于头顶提示 z=100）
	var sh: Shader = load("res://assets/shaders/outline.gdshader")
	_material = ShaderMaterial.new()
	_material.shader = sh
	material = _material
	_collect_drawables(get_parent())
	if _drawables.is_empty():
		# 无可见形状（如 TestMap 纯 Interactable 根）→ 不工作
		set_process(false)
		visible = false


func _process(delta: float) -> void:
	var my_root := get_parent()
	if my_root == null:
		return
	var my_rect := _visual_rect(my_root)
	if my_rect.size.x <= 0.0 or my_rect.size.y <= 0.0:
		return
	var feet_y: float = my_root.global_position.y
	var items: Array = []
	_collect_sort_items(my_root.get_parent(), items)
	var cover := 0.0
	_occluder_polys.clear()
	for it: Node2D in items:
		if it == my_root or my_root.is_ancestor_of(it):
			continue
		# 架构 §1.2 触发条件：前景元素 origin y > 角色脚部 y（Y-sort 排序数据复用）
		if it.global_position.y <= feet_y + 0.01:
			continue
		var r := _visual_rect(it)
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		var inter := my_rect.intersection(r)
		if inter.size.x > 0.0 and inter.size.y > 0.0:
			cover += inter.get_area()
			_collect_occluder_polys(it, _occluder_polys)
	var target := clampf(cover / my_rect.get_area() * STRENGTH_GAIN, 0.0, 1.0)
	strength = lerpf(strength, target, 1.0 - exp(-FADE_SPEED * delta))
	_material.set_shader_parameter("strength", strength)
	visible = strength > 0.01
	if visible:
		queue_redraw()


func _draw() -> void:
	piece_count = 0
	# 遮挡物形状一次性转本地坐标（宿主移动时每帧重建）
	var occs_local: Array = []
	for occ: PackedVector2Array in _occluder_polys:
		var lo := PackedVector2Array()
		lo.resize(occ.size())
		for k in occ.size():
			lo[k] = to_local(occ[k])
		occs_local.append(lo)
	for d in _drawables:
		var pts := _shape_points(d)  # 全局坐标
		if pts.size() < 3:
			continue
		var center := Vector2.ZERO
		for p: Vector2 in pts:
			center += p
		center /= pts.size()
		for i in pts.size():
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[(i + 1) % pts.size()]
			var edge := b - a
			if edge.length() < 0.01:
				continue
			var t := edge / edge.length()
			var n := Vector2(t.y, -t.x)
			if n.dot((a + b) * 0.5 - center) < 0.0:
				n = -n  # 法线朝外
			# 2px 外扩条带（端部各延 OUTLINE_PX 补角，凸角无缝）
			var quad := PackedVector2Array([
				to_local(a - t * OUTLINE_PX),
				to_local(b + t * OUTLINE_PX),
				to_local(b + (n + t) * OUTLINE_PX),
				to_local(a + (n - t) * OUTLINE_PX),
			])
			for lo: PackedVector2Array in occs_local:
				for piece in Geometry2D.intersect_polygons(quad, lo):
					if piece.size() >= 3:
						draw_colored_polygon(piece, Color.WHITE)
						piece_count += 1


# ---------------------------------------------------------------
# 内部
# ---------------------------------------------------------------

## 收集宿主可见形状（跳过阴影/调试件/自身）
func _collect_drawables(n: Node) -> void:
	if n == null or n == self:
		return
	if n.name in _SKIP_NAMES:
		return
	if n is Polygon2D or n is ColorRect or n is Sprite2D:
		_drawables.append(n)
	for c in n.get_children():
		_collect_drawables(c)


## 收集遮挡节点的可见形状（全局坐标，递归）
func _collect_occluder_polys(n: Node, out: Array) -> void:
	if n == null or n.name in _SKIP_NAMES:
		return
	if n is Polygon2D or n is ColorRect or n is Sprite2D:
		var pts := _shape_points(n)
		if pts.size() >= 3:
			out.append(pts)
	for c in n.get_children():
		_collect_occluder_polys(c, out)


## 节点视觉包围盒（全局坐标，递归合并）
func _visual_rect(n: Node) -> Rect2:
	var r := Rect2()
	if n == self or (n is Node and n.name in _SKIP_NAMES):
		return r
	if n is Polygon2D:
		var pg := n as Polygon2D
		if pg.polygon.size() >= 3:
			r = Rect2(pg.to_global(pg.polygon[0]), Vector2.ZERO)
			for i in range(1, pg.polygon.size()):
				r = r.expand(pg.to_global(pg.polygon[i]))
	elif n is ColorRect:
		var cr := n as ColorRect
		var xf := cr.get_global_transform()
		r = Rect2(xf.origin, cr.size * xf.get_scale())
	elif n is Sprite2D:
		var sp := n as Sprite2D
		if sp.texture != null:
			var half: Vector2 = sp.texture.get_size() * 0.5 * sp.global_scale
			var c: Vector2 = sp.global_position
			r = Rect2(c - half, half * 2.0)
	for c in n.get_children():
		var cr2 := _visual_rect(c)
		if cr2.size.x > 0.0 and cr2.size.y > 0.0:
			r = r.merge(cr2) if r.size.x > 0.0 and r.size.y > 0.0 else cr2
	return r


## 形状顶点（全局坐标；ColorRect 非 Node2D，参数用 Node 并各自处理变换）
func _shape_points(d: Node) -> PackedVector2Array:
	if d is Polygon2D:
		var pg := d as Polygon2D
		var out := PackedVector2Array()
		out.resize(pg.polygon.size())
		for i in pg.polygon.size():
			out[i] = pg.to_global(pg.polygon[i])
		return out
	if d is ColorRect:
		var cr := d as ColorRect
		var xf := cr.get_global_transform()
		return PackedVector2Array([
			xf * Vector2.ZERO, xf * Vector2(cr.size.x, 0),
			xf * cr.size, xf * Vector2(0, cr.size.y),
		])
	if d is Sprite2D:
		var sp := d as Sprite2D
		if sp.texture == null:
			return PackedVector2Array()
		var half: Vector2 = sp.texture.get_size() * 0.5
		return PackedVector2Array([
			sp.to_global(-half), sp.to_global(Vector2(half.x, -half.y)),
			sp.to_global(half), sp.to_global(Vector2(-half.x, half.y)),
		])
	return PackedVector2Array()


## 收集 Y-sort 叶子排序项：y_sort 容器的直接子级中，非容器者即排序项
## （容器内嵌 y_sort 时其子级上浮参与统一排序，架构 §1.1 渲染层级链）
func _collect_sort_items(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Area2D or c is Camera2D:
			continue
		if c is Node2D:
			if (c as Node2D).y_sort_enabled:
				_collect_sort_items(c, out)
			else:
				out.append(c)
