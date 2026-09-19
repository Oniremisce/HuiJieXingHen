## =============================================================
## 《汇界星痕》T2.4 神像菜单（全屏半透明面板，Shrine 运行时构建挂载）
## -------------------------------------------------------------
## 三项：存档（SaveManager.save_game("manual")）/ 恢复状态（ShrineSystem.
## restore_all）/ 查看此区域提示（MapSystem 区域信息占位文案）。
## 打开 → PauseManager.pause_game("shrine_menu") + EventBus.ui_open；
## 关闭反向 + ui_closed。T2.5 起 open/close 由 UISystem 面板栈调度，
## Esc 层级导航统一归 UISystem（本面板不再自行处理）。
## process_mode=ALWAYS：世界暂停时面板自身与子按钮仍可交互。
## =============================================================
extends CanvasLayer

const PANEL_SIZE := Vector2(440.0, 340.0)
const VIEWPORT := Vector2(1152.0, 648.0)

var is_open := false

var _info: Label


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()
	get_node("/root/UISystem").register_panel("shrine_menu", self)


func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	_info.text = ""
	get_node("/root/PauseManager").pause_game("shrine_menu")
	get_node("/root/EventBus").ui_open.emit("shrine_menu")
	print("[ShrineMenu] open")


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	get_node("/root/PauseManager").resume_game("shrine_menu")
	get_node("/root/EventBus").ui_closed.emit("shrine_menu")
	print("[ShrineMenu] close")


# ---------------------------------------------------------------
# UI 构建（代码构建，MapUI 先例）
# ---------------------------------------------------------------

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := ColorRect.new()
	panel.name = "Panel"
	panel.color = Color(0.06, 0.07, 0.10, 0.94)
	panel.size = PANEL_SIZE
	panel.position = (VIEWPORT - PANEL_SIZE) * 0.5
	dim.add_child(panel)

	var title := Label.new()
	title.text = "星痕神像"
	title.position = Vector2(24.0, 14.0)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	panel.add_child(title)

	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "Esc 关闭"
	hint.position = Vector2(24.0, PANEL_SIZE.y - 30.0)
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.55))
	panel.add_child(hint)

	_add_button(panel, "存档", Vector2(24.0, 64.0), _on_save_pressed)
	_add_button(panel, "恢复状态", Vector2(24.0, 118.0), _on_restore_pressed)
	_add_button(panel, "查看此区域提示", Vector2(24.0, 172.0), _on_region_info_pressed)
	_add_button(panel, "关闭", Vector2(24.0, 240.0), close)

	_info = Label.new()
	_info.name = "Info"
	_info.position = Vector2(224.0, 70.0)
	_info.size = Vector2(PANEL_SIZE.x - 248.0, PANEL_SIZE.y - 100.0)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_font_size_override("font_size", 14)
	_info.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0))
	panel.add_child(_info)


func _add_button(panel: Control, text: String, pos: Vector2, handler: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(184.0, 42.0)
	b.pressed.connect(handler)
	panel.add_child(b)


# ---------------------------------------------------------------
# 三项行为
# ---------------------------------------------------------------

func _on_save_pressed() -> void:
	var ok: bool = get_node("/root/SaveManager").save_game("manual")
	_info.text = "已保存至手动档（user://save_manual.json）。" if ok else "存档失败，详见日志。"
	print("[ShrineMenu] 存档 -> manual：%s" % str(ok))


func _on_restore_pressed() -> void:
	get_node("/root/ShrineSystem").restore_all()
	_info.text = "全队状态已恢复（HP/星缘满、状态重置）。"


func _on_region_info_pressed() -> void:
	var ms := get_node("/root/MapSystem")
	var rid: String = ms.get_current_region_id()
	var info: Dictionary = ms.get_region_info(rid)
	_info.text = "当前区域：【%s】\n提示占位：此处区域文案由剧情文案补充（T4.x 接入）。" % str(info.get("name", rid))
