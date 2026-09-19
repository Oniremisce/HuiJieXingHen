## =============================================================
## 《汇界星痕》T2.5 主角命名面板（首次进入营地触发）
## -------------------------------------------------------------
## 单行输入 + 确认：确认 → GameState.set_hero_name + flag "hero_named"；
## HUD 左上经 hero_name_changed 同步。Esc 不关闭（必须确认，防漏命名）；
## 读档已有 flag / 重开新档（flags 空）→ CampMap._ready 检查触发。
## layer=95 强制置顶（覆盖其他面板）。
## =============================================================
extends UIPanelScript

const UIPanelScript := preload("res://scripts/ui/UIPanel.gd")

const PANEL_SIZE := Vector2(460.0, 220.0)
const VIEWPORT := Vector2(1152.0, 648.0)

var _input: LineEdit


func _init() -> void:
	panel_name = "rename"
	layer = 95


func _build_ui() -> void:
	var dim := _make_dim()
	var panel := _make_panel(dim, Rect2((VIEWPORT - PANEL_SIZE) * 0.5, PANEL_SIZE))

	var title := _make_title(panel, "为主角命名")
	title.position = Vector2(20.0, 16.0)

	var tip := Label.new()
	tip.text = "这段名字将伴随你的旅程（留空则使用默认名）。"
	tip.position = Vector2(20.0, 52.0)
	tip.add_theme_font_size_override("font_size", 13)
	tip.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	panel.add_child(tip)

	_input = LineEdit.new()
	_input.name = "NameInput"
	_input.placeholder_text = "异乡人"
	_input.max_length = 12
	_input.position = Vector2(20.0, 88.0)
	_input.size = Vector2(PANEL_SIZE.x - 40.0, 36.0)
	_input.add_theme_font_size_override("font_size", 16)
	panel.add_child(_input)

	var ok := Button.new()
	ok.name = "ConfirmBtn"
	ok.text = "确认"
	ok.position = Vector2(PANEL_SIZE.x * 0.5 - 60.0, 148.0)
	ok.size = Vector2(120.0, 40.0)
	ok.pressed.connect(_on_confirm)
	panel.add_child(ok)


## Esc 不关闭：命名是必须步骤，确认前不给跳过（事件在此消费，不上传 UISystem）
func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()


func _on_open() -> void:
	_input.text = ""
	_input.grab_focus()


func _on_confirm() -> void:
	var name_text := _input.text.strip_edges()
	if name_text.is_empty():
		name_text = "异乡人"
	var gs := get_node("/root/GameState")
	gs.set_hero_name(name_text)
	gs.set_flag("hero_named", true)
	print("[RenamePanel] 主角命名 -> %s（flag hero_named=1）" % name_text)
	get_node("/root/UISystem").close_panel("rename")
