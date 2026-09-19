## =============================================================
## 《汇界星痕》T2.5 唤星面板（G 键，架构 §3.1：全屏骨架）
## -------------------------------------------------------------
## 星砂×100 单抽按钮（星砂不足禁用+提示；本卡整体置灰标注
## 「T6.2 开放」，抽取逻辑与演出 T6.2/T6.4 接）+ 保底进度条
## （SaveManager.pity_counter / 60，占位显示）+ 结果展示区占位。
## =============================================================
extends UIPanelScript

const UIPanelScript := preload("res://scripts/ui/UIPanel.gd")

const PANEL_SIZE := Vector2(640.0, 380.0)
const VIEWPORT := Vector2(1152.0, 648.0)
const PITY_MAX := 60
const SUMMON_COST := 100

var _pull_btn: Button
var _tip: Label
var _pity_bar: ProgressBar
var _pity_label: Label
var _result: Label


func _init() -> void:
	panel_name = "summon"
	layer = 92


func _build_ui() -> void:
	var dim := _make_dim()
	var panel := _make_panel(dim, Rect2((VIEWPORT - PANEL_SIZE) * 0.5, PANEL_SIZE))
	_make_title(panel, "唤星")
	_make_hint(panel, "G 关闭  |  Esc 回上一层")

	_pull_btn = Button.new()
	_pull_btn.name = "PullBtn"
	_pull_btn.text = "星砂×100 单抽（T6.2 开放）"
	_pull_btn.disabled = true
	_pull_btn.position = Vector2(32.0, 56.0)
	_pull_btn.size = Vector2(240.0, 44.0)
	_pull_btn.add_theme_font_size_override("font_size", 15)
	panel.add_child(_pull_btn)

	_tip = Label.new()
	_tip.name = "Tip"
	_tip.text = "唤星系统 T6.2 开放，敬请期待。"
	_tip.position = Vector2(292.0, 66.0)
	_tip.add_theme_font_size_override("font_size", 14)
	_tip.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	panel.add_child(_tip)

	var pity_title := Label.new()
	pity_title.text = "保底进度"
	pity_title.position = Vector2(32.0, 128.0)
	pity_title.add_theme_font_size_override("font_size", 15)
	pity_title.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	panel.add_child(pity_title)

	_pity_bar = ProgressBar.new()
	_pity_bar.name = "PityBar"
	_pity_bar.min_value = 0
	_pity_bar.max_value = PITY_MAX
	_pity_bar.position = Vector2(32.0, 156.0)
	_pity_bar.size = Vector2(PANEL_SIZE.x - 64.0, 22.0)
	_pity_bar.show_percentage = false
	panel.add_child(_pity_bar)

	_pity_label = Label.new()
	_pity_label.name = "PityLabel"
	_pity_label.position = Vector2(32.0, 182.0)
	_pity_label.add_theme_font_size_override("font_size", 12)
	_pity_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	panel.add_child(_pity_label)

	var result_title := Label.new()
	result_title.text = "结果展示"
	result_title.position = Vector2(32.0, 224.0)
	result_title.add_theme_font_size_override("font_size", 15)
	result_title.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	panel.add_child(result_title)

	_result = Label.new()
	_result.name = "Result"
	_result.text = "（出卡动画与结果页 T6.4 接演出）"
	_result.position = Vector2(32.0, 252.0)
	_result.size = Vector2(PANEL_SIZE.x - 64.0, 80.0)
	_result.add_theme_font_size_override("font_size", 13)
	_result.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	panel.add_child(_result)


func _on_open() -> void:
	var sand: int = get_node("/root/GameState").star_sand
	var pity: int = get_node("/root/SaveManager").pity_counter
	_pity_bar.value = pity
	_pity_label.text = "保底 %d / %d（T6.3 唤星系统接管计数）" % [pity, PITY_MAX]
	if sand < SUMMON_COST:
		_tip.text = "星砂不足（当前 %d / 需要 %d）。" % [sand, SUMMON_COST]
	else:
		_tip.text = "唤星系统 T6.2 开放，敬请期待。"
