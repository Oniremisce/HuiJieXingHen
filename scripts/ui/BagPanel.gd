## =============================================================
## 《汇界星痕》T2.5 背包（B 键，架构 §3.1：全屏半透明占位）
## -------------------------------------------------------------
## 分类 Tab：道具/材料/任务品（无星髓 Tab——星髓不入背包，
## 查看/装备在角色列表 → 星髓面板）；网格 + 数量徽标 + 详情浮层占位。
## Inventory 未就绪（T6.1 接）→ 各 Tab 空态。
## =============================================================
extends UIPanelScript

const UIPanelScript := preload("res://scripts/ui/UIPanel.gd")

const PANEL_RECT := Rect2(276.0, 64.0, 600.0, 520.0)
const TAB_NAMES: Array[String] = ["道具", "材料", "任务品"]

var _grid_box: VBoxContainer
var _detail: Label
var _tab_index := 0


func _init() -> void:
	panel_name = "bag"
	layer = 92


func _build_ui() -> void:
	var dim := _make_dim()
	var panel := _make_panel(dim, PANEL_RECT)
	_make_title(panel, "背包")
	_make_hint(panel, "B 关闭  |  Esc 回上一层  |  星髓不入背包（角色列表 → 星髓面板查看/装备）")

	var tabs := HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.position = Vector2(16.0, 40.0)
	tabs.add_theme_constant_override("separation", 8)
	panel.add_child(tabs)
	for i in TAB_NAMES.size():
		var tb := Button.new()
		tb.name = "Tab_%s" % TAB_NAMES[i]
		tb.text = TAB_NAMES[i]
		tb.custom_minimum_size = Vector2(96.0, 32.0)
		var idx := i
		tb.pressed.connect(func() -> void: _switch_tab(idx))
		tabs.add_child(tb)

	_grid_box = VBoxContainer.new()
	_grid_box.name = "GridBox"
	_grid_box.position = Vector2(16.0, 88.0)
	_grid_box.size = Vector2(PANEL_RECT.size.x - 32.0, PANEL_RECT.size.y - 160.0)
	panel.add_child(_grid_box)

	_detail = Label.new()
	_detail.name = "Detail"
	_detail.text = "详情浮层占位（点击物品后显示名称/描述/数量，T6.1 接 Inventory）"
	_detail.position = Vector2(16.0, PANEL_RECT.size.y - 64.0)
	_detail.size = Vector2(PANEL_RECT.size.x - 32.0, 28.0)
	_detail.add_theme_font_size_override("font_size", 12)
	_detail.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	panel.add_child(_detail)


func _switch_tab(idx: int) -> void:
	_tab_index = idx
	_refresh_grid()


func _refresh_grid() -> void:
	for c in _grid_box.get_children():
		_grid_box.remove_child(c)
		c.queue_free()
	# Inventory 未就绪（T6.1 接入后按 Tab 分类填充网格 + 数量徽标）
	var empty := Label.new()
	empty.name = "EmptyState"
	empty.text = "（%s · 空空如也）\n\n物品系统 T6.1 接入 Inventory 后在此展示\n网格物品 + 数量徽标，点击查看详情。" % TAB_NAMES[_tab_index]
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.add_theme_font_size_override("font_size", 14)
	empty.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	_grid_box.add_child(empty)


func _on_open() -> void:
	_refresh_grid()
