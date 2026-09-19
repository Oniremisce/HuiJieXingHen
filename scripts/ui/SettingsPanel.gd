## =============================================================
## 《汇界星痕》T2.5 设置面板（架构 §3.1：三页骨架）
## -------------------------------------------------------------
## 音频（BGM/音效/UI 三轨音量条）/ 画面（全屏窗口切换 + 分辨率下拉 +
## 主页背景选择器）/ 操作（键位表只读）。
## 全部设置存独立档 user://settings.json（UISystem 持有，不混进度档）；
## 每次变更立即落盘并应用。背景选择供主页菜单 _build_bg 消费（§3.2）。
## =============================================================
extends UIPanelScript

const UIPanelScript := preload("res://scripts/ui/UIPanel.gd")

const PANEL_RECT := Rect2(336.0, 74.0, 480.0, 500.0)
## 背景选择项：氛围图 + 已获角色立绘占位列表（§3.2）
const BACKGROUND_OPTIONS: Array[String] = ["ambient", "awakened_mech_01", "awakened_arcane_01", "awakened_xian_01"]
const BACKGROUND_LABELS: Array[String] = ["氛围图", "诺菈·星枢", "艾蕾雅", "洛清弦"]
const RESOLUTIONS: Array[String] = ["1152x648", "1280x720", "1600x900", "1920x1080"]
const KEYS_HELP := """W/A/S/D · 方向键    移动
E / 空格            交互
B                   背包
C                   角色列表
G                   唤星
J                   任务
M                   箱庭图 / 世界大地图
Esc                 逐层回退 / 主页菜单"""

var _fullscreen_btn: CheckButton
var _res_option: OptionButton
var _bg_option: OptionButton
var _pages: Array[Control] = []


func _init() -> void:
	panel_name = "settings"
	layer = 92


func _build_ui() -> void:
	var dim := _make_dim()
	var panel := _make_panel(dim, PANEL_RECT)
	_make_title(panel, "设置")
	_make_hint(panel, "Esc 回上一层  |  变更即时保存至 user://settings.json")

	var pages := [
		["音频", _build_audio_page()],
		["画面", _build_display_page()],
		["操作", _build_controls_page()],
	]
	for p: Array in pages:
		var page: Control = p[1]
		panel.add_child(page)
		_pages.append(page)

	var tabs := HBoxContainer.new()
	tabs.position = Vector2(16.0, 40.0)
	tabs.add_theme_constant_override("separation", 8)
	panel.add_child(tabs)
	for i in pages.size():
		var tb := Button.new()
		tb.name = "Tab_%s" % str(pages[i][0])
		tb.text = str(pages[i][0])
		tb.custom_minimum_size = Vector2(90.0, 30.0)
		var idx := i
		tb.pressed.connect(func() -> void: _switch_page(idx))
		tabs.add_child(tb)

	_switch_page(0)


func _build_audio_page() -> Control:
	var page := Control.new()
	page.name = "AudioPage"
	page.position = Vector2(16.0, 84.0)
	page.size = Vector2(PANEL_RECT.size.x - 32.0, PANEL_RECT.size.y - 124.0)
	var us := get_node("/root/UISystem")
	var rows := [["bgm", "BGM"], ["sfx", "音效"], ["ui", "UI"]]
	for i in rows.size():
		var key := str(rows[i][0])
		var lb := Label.new()
		lb.text = str(rows[i][1])
		lb.position = Vector2(0.0, 12.0 + i * 56.0)
		lb.add_theme_font_size_override("font_size", 14)
		page.add_child(lb)
		var slider := HSlider.new()
		slider.name = "Slider_%s" % key
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.position = Vector2(80.0, 12.0 + i * 56.0)
		slider.size = Vector2(280.0, 24.0)
		slider.value = int(us.settings["audio"][key])
		slider.value_changed.connect(func(v: float) -> void: _on_audio_changed(key, v))
		page.add_child(slider)
		var val := Label.new()
		val.name = "Val_%s" % key
		val.text = "%d" % int(slider.value)
		val.position = Vector2(372.0, 12.0 + i * 56.0)
		val.add_theme_font_size_override("font_size", 13)
		page.add_child(val)
	var note := Label.new()
	note.text = "（音频总线接入由音频岗 T6.x 消费，本卡持久化数值）"
	note.position = Vector2(0.0, page.size.y - 30.0)
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	page.add_child(note)
	return page


func _build_display_page() -> Control:
	var page := Control.new()
	page.name = "DisplayPage"
	page.position = Vector2(16.0, 84.0)
	page.size = Vector2(PANEL_RECT.size.x - 32.0, PANEL_RECT.size.y - 124.0)
	var us := get_node("/root/UISystem")

	_fullscreen_btn = CheckButton.new()
	_fullscreen_btn.name = "FullscreenBtn"
	_fullscreen_btn.text = "全屏窗口"
	_fullscreen_btn.position = Vector2(0.0, 8.0)
	_fullscreen_btn.button_pressed = bool(us.settings["display"]["fullscreen"])
	_fullscreen_btn.toggled.connect(func(on: bool) -> void:
		us.update_setting("display", "fullscreen", on))
	page.add_child(_fullscreen_btn)

	var res_lb := Label.new()
	res_lb.text = "分辨率"
	res_lb.position = Vector2(0.0, 56.0)
	res_lb.add_theme_font_size_override("font_size", 14)
	page.add_child(res_lb)
	_res_option = OptionButton.new()
	_res_option.name = "ResolutionOption"
	for r in RESOLUTIONS:
		_res_option.add_item(r)
	_res_option.selected = RESOLUTIONS.find(str(us.settings["display"]["resolution"]))
	_res_option.position = Vector2(80.0, 52.0)
	_res_option.size = Vector2(160.0, 28.0)
	_res_option.item_selected.connect(func(i: int) -> void:
		us.update_setting("display", "resolution", RESOLUTIONS[i]))
	page.add_child(_res_option)

	var bg_lb := Label.new()
	bg_lb.text = "主页背景"
	bg_lb.position = Vector2(0.0, 104.0)
	bg_lb.add_theme_font_size_override("font_size", 14)
	page.add_child(bg_lb)
	_bg_option = OptionButton.new()
	_bg_option.name = "BackgroundOption"
	for i in BACKGROUND_OPTIONS.size():
		_bg_option.add_item(BACKGROUND_LABELS[i])
	_bg_option.selected = BACKGROUND_OPTIONS.find(us.get_main_background())
	_bg_option.position = Vector2(80.0, 100.0)
	_bg_option.size = Vector2(160.0, 28.0)
	_bg_option.item_selected.connect(func(i: int) -> void:
		us.set_background(BACKGROUND_OPTIONS[i]))
	page.add_child(_bg_option)

	var bg_note := Label.new()
	bg_note.text = "主页背景：氛围图 / 已获角色立绘（§3.2 背景选择器）"
	bg_note.position = Vector2(0.0, 140.0)
	bg_note.add_theme_font_size_override("font_size", 11)
	bg_note.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	page.add_child(bg_note)
	return page


func _build_controls_page() -> Control:
	var page := Control.new()
	page.name = "ControlsPage"
	page.position = Vector2(16.0, 84.0)
	page.size = Vector2(PANEL_RECT.size.x - 32.0, PANEL_RECT.size.y - 124.0)
	var lb := Label.new()
	lb.name = "KeysHelp"
	lb.text = "键位表（只读）：\n\n" + KEYS_HELP
	lb.add_theme_font_size_override("font_size", 14)
	page.add_child(lb)
	return page


func _switch_page(idx: int) -> void:
	for i in _pages.size():
		_pages[i].visible = i == idx


func _on_audio_changed(key: String, v: float) -> void:
	get_node("/root/UISystem").update_setting("audio", key, int(v))
	get_node("Dim/Panel/AudioPage/Val_%s" % key).text = "%d" % int(v)
