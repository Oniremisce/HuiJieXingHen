## =============================================================
## 《汇界星痕》T2.3 遮挡描边（架构 §1.2）
## -------------------------------------------------------------
## 原理：作为宿主实体（玩家/NPC 实体根）的子节点，收集宿主的可见形状
## （Polygon2D/ColorRect/Sprite2D，跳过阴影/调试件），以 8 向 2px 偏移
## 在自身（z_index=20，压过前景遮挡物）上用 outline.gdshader 重绘白色轮廓；
## 强度 = 前景遮挡面积占宿主视觉面积的比例（复用 Y-sort 排序数据：
## 仅当「遮挡项排序 y > 宿主脚部 y」且投影 AABB 重叠才计入，无射线检测），
## 指数平滑淡入淡出。玩家与 NPC 均适用。
## 挂载：PlayerController / Interactable 运行时自动安装（无需改 .tscn）。
## =============================================================
extends Node2D

const OUTLINE_PX := 2.0
const STRENGTH_GAIN := 1.6  # 遮挡比例 → 强度增益（约 62% 覆盖即全强度）
const FADE_SPEED := 10.0    # 指数平滑速度

## 8 向描边偏移（纯白外描边宽度 ≈ OUTLINE_PX）
const _OFFSETS: Array[Vector2] = [
	Vector2(OUTLINE_PX, 0), Vector2(-OUTLINE_PX, 0),
	Vector2(0, OUTLINE_PX), Vector2(0, -OUTLINE_PX),
	Vector2(OUTLINE_PX * 0.71, OUTLINE_PX * 0.71), Vector2(-OUTLINE_PX * 0.71, OUTLINE_PX * 0.71),
	Vector2(OUTLINE_PX * 0.71, -OUTLINE_PX * 0.71), Vector2(-OUTLINE_PX * 0.71, -OUTLINE_PX * 0.71),
]

## 不参与描边/遮挡判定的视觉件（阴影、调试可视化、头顶 UI）
const _SKIP_NAMES := ["Shade", "DebugVisual", "HintRoot", "NameTag", "AnimSprite"]

## 当前描边强度（0=无遮挡，1=完全遮挡；MCP 验证可读）
var strength := 0.0

var _material: ShaderMaterial
var _drawables: Array = []  # Polygon2D / ColorRect / Sprite2D 列表


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
	var target := clampf(cover / my_rect.get_area() * STRENGTH_GAIN, 0.0, 1.0)
	strength = lerpf(strength, target, 1.0 - exp(-FADE_SPEED * delta))
	_material.set_shader_parameter("strength", strength)
	visible = strength > 0.01
	if visible:
		queue_redraw()


func _draw() -> void:
	for d in _drawables:
		var pts := _shape_points(d)
		if pts.is_empty():
			continue
		var base := PackedVector2Array()
		for p: Vector2 in pts:
			base.append(to_local(p))
		for off: Vector2 in _OFFSETS:
			var shifted := PackedVector2Array()
			shifted.resize(base.size())
			for i in base.size():
				shifted[i] = base[i] + off
			draw_colored_polygon(shifted, Color.WHITE)


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
