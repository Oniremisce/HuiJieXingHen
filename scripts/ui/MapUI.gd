## =============================================================
## 《汇界星痕》T2.3 地图面板（箱庭图 ⇄ 世界大地图）
## -------------------------------------------------------------
## 架构 §2.3：M 键开箱庭图；滚轮双向切换世界大地图；ESC 关闭。
## 打开 → PauseManager 暂停（reason="map_ui"）+ EventBus.ui_open；
## 关闭恢复 + ui_closed。点击世界大地图已点亮神像 → 确认框 →
## Transition.transition_portal。
## 挂载：MapSystem._ensure_ui 守卫加载（本面板为其常驻子节点，跨场景）。
## 输入兜底：ui_map 物理键 M（编辑器覆写 project.godot 时保底）。
## =============================================================
extends CanvasLayer

const _SandboxView := preload("res://scripts/ui/SandboxView.gd")
const _WorldMapView := preload("res://scripts/ui/WorldMapView.gd")

const ACTION_TOGGLE := "ui_map"
const ACTION_CANCEL := "ui_cancel"
const VIEW_NAMES: Array[String] = ["箱庭图", "世界大地图"]
const PANEL_RECT := Rect2(196.0, 64.0, 760.0, 520.0)

## 是否打开（MCP 验证可读）
var is_open := false
## 当前视图：0=箱庭图 1=世界大地图
var view_index := 0

var _dim: ColorRect
var _panel: ColorRect
var _sandbox: Node2D = null
var _world: Node2D = null
var _title: Label
var _hint: Label
var _confirm: Control
var _confirm_label: Label
var _pending_shrine := ""


func _ready() -> void:
	visible = false
	_ensure_input_action()
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION_TOGGLE):
		if is_open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed(ACTION_CANCEL):
		if _confirm.visible:
			_close_confirm()
		else:
			close()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------
# 开关与暂停
# ---------------------------------------------------------------

func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	_close_confirm()
	get_node("/root/PauseManager").pause_game("map_ui")
	get_node("/root/EventBus").ui_open.emit("map_ui")
	_refresh_view()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	_close_confirm()
	get_node("/root/PauseManager").resume_game("map_ui")
	get_node("/root/EventBus").ui_closed.emit("map_ui")


func _switch_view(dir: int) -> void:
	view_index = wrapi(view_index + dir, 0, 2)
	_close_confirm()
	_refresh_view()


func _refresh_view() -> void:
	if _sandbox == null or _world == null:
		return
	_sandbox.visible = view_index == 0
	_world.visible = view_index == 1
	_title.text = VIEW_NAMES[view_index]
	_hint.text = "滚轮 切换视图  |  左键点击已点亮神像传送  |  M/Esc 关闭"
	if view_index == 0:
		_sandbox.queue_redraw()
	else:
		_world.queue_redraw()


# ---------------------------------------------------------------
# UI 构建（代码构建，场景仅根 CanvasLayer）
# ---------------------------------------------------------------

func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = Color(0.0, 0.0, 0.0, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)

	_panel = ColorRect.new()
	_panel.name = "Panel"
	_panel.color = Color(0.06, 0.07, 0.10, 0.94)
	_panel.position = PANEL_RECT.position
	_panel.size = PANEL_RECT.size
	_dim.add_child(_panel)

	var border := ColorRect.new()
	border.name = "Border"
	border.color = Color(0.85, 0.9, 1.0, 0.35)
	border.position = Vector2.ZERO
	border.size = Vector2(PANEL_RECT.size.x, 2.0)
	_panel.add_child(border)

	_title = Label.new()
	_title.position = Vector2(16.0, 10.0)
	_title.add_theme_font_size_override("font_size", 18)
	_title.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	_panel.add_child(_title)

	_hint = Label.new()
	_hint.position = Vector2(16.0, PANEL_RECT.size.y - 30.0)
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.55))
	_panel.add_child(_hint)

	var inner := Rect2(Vector2(16.0, 44.0), Vector2(PANEL_RECT.size.x - 32.0, PANEL_RECT.size.y - 88.0))

	_sandbox = _SandboxView.new()
	_sandbox.name = "SandboxView"
	_sandbox.view_rect = inner
	_sandbox.position = inner.position
	_sandbox.visible = true
	_panel.add_child(_sandbox)

	_world = _WorldMapView.new()
	_world.name = "WorldMapView"
	_world.view_rect = inner
	_world.position = inner.position
	_world.visible = false
	_panel.add_child(_world)

	_build_confirm()


func _build_confirm() -> void:
	_confirm = ColorRect.new()
	_confirm.name = "ConfirmBar"
	_confirm.color = Color(0.10, 0.11, 0.16, 0.98)
	var w := 380.0
	_confirm.size = Vector2(w, 76.0)
	_confirm.position = Vector2((PANEL_RECT.size.x - w) * 0.5, PANEL_RECT.size.y - 108.0)
	_confirm.visible = false
	_panel.add_child(_confirm)

	_confirm_label = Label.new()
	_confirm_label.position = Vector2(16.0, 8.0)
	_confirm_label.add_theme_font_size_override("font_size", 14)
	_confirm.add_child(_confirm_label)

	var ok := Button.new()
	ok.text = "传送"
	ok.position = Vector2(w * 0.5 - 90.0, 38.0)
	ok.size = Vector2(80.0, 28.0)
	ok.pressed.connect(_on_confirm_ok)
	_confirm.add_child(ok)

	var no := Button.new()
	no.text = "取消"
	no.position = Vector2(w * 0.5 + 10.0, 38.0)
	no.size = Vector2(80.0, 28.0)
	no.pressed.connect(_close_confirm)
	_confirm.add_child(no)


func _on_dim_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_switch_view(-1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_switch_view(1)
			MOUSE_BUTTON_LEFT:
				_close_confirm()
				if view_index == 1 and _world != null:
					var id: String = _world.call("hit_test", _world.call("get_local_mouse_position"))
					if id != "":
						_show_confirm(id)


# ---------------------------------------------------------------
# 传送确认（点击已点亮神像）
# ---------------------------------------------------------------

func _show_confirm(shrine_id: String) -> void:
	_pending_shrine = shrine_id
	var info: Dictionary = get_node("/root/MapSystem").get_shrine_info(shrine_id)
	_confirm_label.text = "传送至【%s】？" % str(info.get("name", shrine_id))
	_confirm.visible = true


func _close_confirm() -> void:
	_pending_shrine = ""
	if _confirm != null:
		_confirm.visible = false


func _on_confirm_ok() -> void:
	if _pending_shrine == "":
		return
	var id := _pending_shrine
	_pending_shrine = ""
	close()
	# 关面板恢复游戏后再启动传送（Transition 自管场景切换与落点）
	get_node("/root/Transition").transition_portal(id)


# ---------------------------------------------------------------
# 兜底
# ---------------------------------------------------------------

func _ensure_input_action() -> void:
	if InputMap.has_action(ACTION_TOGGLE):
		return
	InputMap.add_action(ACTION_TOGGLE)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_M
	InputMap.action_add_event(ACTION_TOGGLE, ev)
