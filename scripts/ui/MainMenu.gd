## =============================================================
## 《汇界星痕》T2.5 主页菜单（架构 §3.1：全屏，打开即暂停世界）
## -------------------------------------------------------------
## 快捷入口网格：出发（世界大地图）/编队（角色列表）/唤星/背包/任务/设置；
## 顶部常显星砂数值（打开时刷新）；背景=设置档 background
## （ambient → 纯色渐变占位；角色 id → ArtProvider 立绘占位拉伸）。
## Esc 关闭（栈空再按 Esc 重开，UISystem 统一调度）。
## =============================================================
extends UIPanelScript  # scripts/ui/UIPanel.gd

const UIPanelScript := preload("res://scripts/ui/UIPanel.gd")

const VIEWPORT := Vector2(1152.0, 648.0)

var _sand_label: Label
var _bg_holder: Control


func _init() -> void:
	panel_name = "main_menu"
	layer = 90


func _build_ui() -> void:
	_bg_holder = Control.new()
	_bg_holder.name = "Background"
	_bg_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg_holder)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.25)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_build_bg()

	# 标题
	var title := Label.new()
	title.text = "汇 界 星 痕"
	title.position = Vector2(0.0, 92.0)
	title.size = Vector2(VIEWPORT.x, 48.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.12, 0.2))
	title.add_theme_constant_override("outline_size", 8)
	add_child(title)

	# 顶部常显星砂
	_sand_label = Label.new()
	_sand_label.name = "StarSand"
	_sand_label.position = Vector2(0.0, 152.0)
	_sand_label.size = Vector2(VIEWPORT.x, 26.0)
	_sand_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sand_label.add_theme_font_size_override("font_size", 18)
	_sand_label.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	add_child(_sand_label)

	# 快捷入口网格（2 列 × 3 行）
	var grid := GridContainer.new()
	grid.name = "Entries"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 18)
	grid.position = Vector2(VIEWPORT.x * 0.5 - 200.0, 224.0)
	add_child(grid)

	var entries := [
		["出发", func() -> void: get_node("/root/UISystem").open_world_map()],
		["编队", func() -> void: get_node("/root/UISystem").open_panel("char_list")],
		["唤星", func() -> void: get_node("/root/UISystem").open_panel("summon")],
		["背包", func() -> void: get_node("/root/UISystem").open_panel("bag")],
		["任务", func() -> void: get_node("/root/UISystem").open_panel("quest")],
		["设置", func() -> void: get_node("/root/UISystem").open_panel("settings")],
	]
	for e: Array in entries:
		var b := Button.new()
		b.name = "Entry_%s" % str(e[0])
		b.text = str(e[0])
		b.custom_minimum_size = Vector2(180.0, 52.0)
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(e[1])
		grid.add_child(b)

	var hint := Label.new()
	hint.text = "Esc 关闭菜单  |  B 背包  C 角色  G 唤星  J 任务  M 地图"
	hint.position = Vector2(0.0, VIEWPORT.y - 40.0)
	hint.size = Vector2(VIEWPORT.x, 24.0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.55))
	add_child(hint)


## 背景渲染（打开期与设置变更后均重建）
func _build_bg() -> void:
	for c in _bg_holder.get_children():
		_bg_holder.remove_child(c)
		c.queue_free()
	var bg_key := str(get_node("/root/UISystem").get_main_background())
	if bg_key != "ambient":
		var tex: Texture2D = get_node("/root/ArtProvider").get_portrait(bg_key, "normal")
		var tr := TextureRect.new()
		tr.texture = tex
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.modulate = Color(1.0, 1.0, 1.0, 0.9)
		_bg_holder.add_child(tr)
		return
	# 氛围图占位：竖向双色渐变（深蓝夜空 → 暗紫星尘）
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0.05, 0.07, 0.14), Color(0.16, 0.10, 0.22)])
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0.0, 0.0)
	gtex.fill_to = Vector2(0.0, 1.0)
	var tr2 := TextureRect.new()
	tr2.texture = gtex
	tr2.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_holder.add_child(tr2)


func _on_open() -> void:
	_sand_label.text = "星砂  %d" % get_node("/root/GameState").star_sand
	_build_bg()
