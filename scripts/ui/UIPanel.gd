## =============================================================
## 《汇界星痕》T2.5 UI 面板基类（架构 §3.1 面板总览 / §2.7 手感细则）
## -------------------------------------------------------------
## 全部 UI 面板统一继承本类（CanvasLayer 浮层，不参与 Y-sort）：
##   - panel_name：ui_open/ui_closed 信号与 PauseManager reason 统一标识；
##   - open()/close()：开 = PauseManager.pause_game(panel_name) +
##     EventBus.ui_open.emit(panel_name)，关反向（MapUI 先例收敛于此）；
##   - 栈管理与 Esc 层级导航归 UISystem（面板不自行处理 Esc）。
## 子类约定：
##   - _init 里设 panel_name 与 layer（main_menu=90、功能面板=92、rename=95）；
##   - _ready 里调 super._ready() 后（若需注册/连信号），UI 构建走 _build_ui()；
##   - 刷新打开期数据覆写 _on_open()/_on_close()；
##   - 内部子浮层需先于面板关闭时消费 Esc 的，覆写 _consume_esc() -> bool
##     （返回 true = 本面板已消费本次 Esc，UISystem 不再关面板）。
## process_mode=ALWAYS：世界暂停时面板与子按钮仍可交互。
## =============================================================
extends CanvasLayer

## 面板唯一标识（ui_open/ui_closed 信号、暂停 reason、UISystem 栈键）
var panel_name := ""
## 是否打开（MCP 验证可读）
var is_open := false

@onready var _event_bus: Node = get_node("/root/EventBus")
@onready var _pause_manager: Node = get_node("/root/PauseManager")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


## 子类 UI 构建（代码构建，ShrineMenu/MapUI 先例）
func _build_ui() -> void:
	pass


## 打开面板：暂停世界 + ui_open 广播（由 UISystem.open_panel 统一调度）
func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	_pause_manager.pause_game(panel_name)
	_event_bus.ui_open.emit(panel_name)
	_on_open()


## 关闭面板：恢复世界 + ui_closed 广播（由 UISystem.close_panel 统一调度）
func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	_pause_manager.resume_game(panel_name)
	_event_bus.ui_closed.emit(panel_name)
	_on_close()


## 打开期数据刷新（子类覆写：货币/编队/任务等易变内容）
func _on_open() -> void:
	pass


func _on_close() -> void:
	pass


## Esc 消费钩子：内部子浮层（确认框等）需要先吃掉 Esc 时覆写返回 true
func _consume_esc() -> bool:
	return false


# ---------------------------------------------------------------
# 子类共用小工具
# ---------------------------------------------------------------

## 全屏半透明底（挡点击 + 压暗世界）
func _make_dim() -> ColorRect:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	return dim


## 标准内容面板（居中深色矩形 + 顶部亮边）
func _make_panel(dim: ColorRect, rect: Rect2) -> ColorRect:
	var panel := ColorRect.new()
	panel.name = "Panel"
	panel.color = Color(0.06, 0.07, 0.10, 0.94)
	panel.position = rect.position
	panel.size = rect.size
	dim.add_child(panel)
	var border := ColorRect.new()
	border.color = Color(0.85, 0.9, 1.0, 0.35)
	border.size = Vector2(rect.size.x, 2.0)
	panel.add_child(border)
	return panel


## 标准标题
func _make_title(panel: Control, text: String) -> Label:
	var title := Label.new()
	title.text = text
	title.position = Vector2(16.0, 10.0)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	panel.add_child(title)
	return title


## 底部提示行
func _make_hint(panel: Control, text: String) -> Label:
	var hint := Label.new()
	hint.text = text
	hint.position = Vector2(16.0, panel.size.y - 30.0)
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.55))
	panel.add_child(hint)
	return hint
