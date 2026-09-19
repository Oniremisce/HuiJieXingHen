## =============================================================
## 《汇界星痕》T2.5 UISystem（UI 总管，Autoload 单例）
## -------------------------------------------------------------
## 架构 §3.1 面板总览 / §2.7 手感细则：
##   1) 面板栈：open_panel push / close_panel 任意层关闭 / close_top 弹顶；
##      Esc 层级导航 = 栈非空逐层回退，栈空打开主页菜单。
##   2) 快捷键：B 背包 / C 角色列表 / G 唤星 / J 任务（toggle：已在栈则关，
##      不在栈则叠加打开）；M 箱庭图仍由 MapUI 自行处理（T2.3 先例）；
##      Esc 在此统一消费（各面板不再自行处理）。
##   3) 设置独立档 user://settings.json（不混进度档，结构见 SETTINGS_DEFAULT）。
## 面板注册：各面板 _ready 调 register_panel；MVP 面板全部代码构建，
##   由本单例 _ready 统一实例化挂载（常驻跨场景，ShrineMenu 例外——
##   仍由 Shrine 实体构建并注册）。
## 叠层规则（layer）：main_menu=90 与 map_ui 同层互斥（出发先关主页）、
##   功能面板=92、rename=95 强制置顶。栈内面板保持 open（暂停计数叠加），
##   视觉上层盖下层，Esc 弹顶露下层。
## 依赖顺序：EventBus/PauseManager 之前就绪即可；Autoload 追加 SaveManager 之后。
## 下游消费：T5.4 任务面板数据接入、T6.1 背包、T6.2/T6.4 唤星、T6.5 星髓。
## =============================================================
extends Node

const UIPanelScript := preload("res://scripts/ui/UIPanel.gd")
const MainMenuScript := preload("res://scripts/ui/MainMenu.gd")
const RenamePanelScript := preload("res://scripts/ui/RenamePanel.gd")
const CharListScript := preload("res://scripts/ui/CharListPanel.gd")
const QuestScript := preload("res://scripts/ui/QuestPanel.gd")
const SummonScript := preload("res://scripts/ui/SummonPanel.gd")
const BagScript := preload("res://scripts/ui/BagPanel.gd")
const SettingsScript := preload("res://scripts/ui/SettingsPanel.gd")

## 快捷键 action -> 面板名（M 键不在此列，MapUI 自理；Esc 单独处理）
const HOTKEY_PANELS := {
	"ui_bag": "bag",
	"ui_char": "char_list",
	"ui_summon": "summon",
	"ui_quest": "quest",
}

## 设置档默认值（user://settings.json；version 变更时迁移重置）
const SETTINGS_PATH := "user://settings.json"
const SETTINGS_DEFAULT := {
	"version": 1,
	"audio": {"bgm": 80, "sfx": 80, "ui": 80},
	"display": {"fullscreen": false, "resolution": "1152x648"},
	"background": "ambient",
}

## 已注册面板（panel_name -> CanvasLayer）
var _panels: Dictionary = {}
## 面板栈（后进先出，存 panel_name；Esc 逐层回退）
var _stack: Array[String] = []
## 设置缓存（load_settings 填充；save_settings 落盘）
var settings: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_input_actions()
	_load_settings()
	# MVP 面板统一构建挂载（常驻子节点；ShrineMenu 由 Shrine 自建自注册）
	var built: Dictionary = {
		"main_menu": MainMenuScript.new(),
		"rename": RenamePanelScript.new(),
		"char_list": CharListScript.new(),
		"quest": QuestScript.new(),
		"summon": SummonScript.new(),
		"bag": BagScript.new(),
		"settings": SettingsScript.new(),
	}
	for panel_name: String in built:
		var panel: CanvasLayer = built[panel_name]
		panel.name = panel_name.capitalize().replace(" ", "")
		add_child(panel)
		_panels[panel_name] = panel
	# 外部挂载面板（MapUI 挂 MapSystem 下，T2.3 先例）由其 _ready 自注册
	print("[UISystem] ready: panels=%s" % str(built.keys()))


# ---------------------------------------------------------------
# 面板注册（面板 _ready 自注册，ShrineMenu/MapUI 等外部挂载面板走此入口）
# ---------------------------------------------------------------

func register_panel(name_key: String, panel: CanvasLayer) -> void:
	_panels[name_key] = panel


# ---------------------------------------------------------------
# 栈管理（对外主入口）
# ---------------------------------------------------------------

## 打开面板：open + 入栈（已在栈则忽略，幂等）
func open_panel(name_key: String) -> void:
	var panel: CanvasLayer = _panels.get(name_key)
	if panel == null:
		push_warning("[UISystem] open_panel 未知面板：%s" % name_key)
		return
	if name_key in _stack:
		return
	_stack.append(name_key)
	panel.open()
	print("[UISystem] push %s -> stack=%s" % [name_key, str(_stack)])


## 关闭面板：任意深度移出栈 + close（栈中不存在则忽略）
func close_panel(name_key: String) -> void:
	var panel: CanvasLayer = _panels.get(name_key)
	if panel == null or not (name_key in _stack):
		return
	_stack.erase(name_key)
	panel.close()
	print("[UISystem] close %s -> stack=%s" % [name_key, str(_stack)])


## 弹出栈顶并关闭（Esc 逐层回退的核心）
func close_top() -> void:
	if _stack.is_empty():
		return
	close_panel(_stack[_stack.size() - 1])


## toggle：已在栈 → 关；不在栈 → 开（B/C/G/J 快捷键与 M 键共用语义）
func toggle_panel(name_key: String) -> void:
	if name_key in _stack:
		close_panel(name_key)
	else:
		open_panel(name_key)


## Esc 层级导航：栈顶面板可消费 Esc（子浮层）则不动栈；
## 否则弹顶；栈空 → 打开主页菜单
func handle_esc() -> void:
	if not _stack.is_empty():
		var panel: CanvasLayer = _panels.get(_stack[_stack.size() - 1])
		if panel != null and panel.has_method("_consume_esc") and panel.call("_consume_esc"):
			return
		close_top()
	else:
		open_panel("main_menu")


## 主页菜单「出发」：关主页 → 世界大地图视图打开箱庭图面板（M 面板）
func open_world_map() -> void:
	close_panel("main_menu")
	var map_ui: CanvasLayer = _panels.get("map_ui")
	if map_ui != null:
		map_ui.set("view_index", 1)
		open_panel("map_ui")


func is_panel_open(name_key: String) -> bool:
	return name_key in _stack


## 当前栈快照（MCP 验证可读）
func get_stack() -> Array[String]:
	return _stack.duplicate()


# ---------------------------------------------------------------
# 输入（Esc + B/C/G/J；process_mode=ALWAYS 暂停中仍生效）
# ---------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		handle_esc()
		get_viewport().set_input_as_handled()
		return
	for action: String in HOTKEY_PANELS:
		if event.is_action_pressed(action):
			toggle_panel(HOTKEY_PANELS[action])
			get_viewport().set_input_as_handled()
			return


## 快捷键兜底注册（编辑器覆写 project.godot 时保底，T1.5 先例；
## 物理键码与布局无关：B=66 C=67 G=71 J=74）
func _ensure_input_actions() -> void:
	var keys := {"ui_bag": KEY_B, "ui_char": KEY_C, "ui_summon": KEY_G, "ui_quest": KEY_J}
	for action: String in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = keys[action]
		InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------
# 设置独立档（user://settings.json，不混进度档）
# ---------------------------------------------------------------

func _load_settings() -> void:
	settings = SETTINGS_DEFAULT.duplicate(true)
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		push_warning("[UISystem] 设置档打开失败 err=%d，用默认值" % FileAccess.get_open_error())
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		push_warning("[UISystem] 设置档损坏（非 JSON），用默认值")
		return
	var data: Dictionary = parsed
	var audio: Variant = data.get("audio", {})
	if audio is Dictionary:
		for k: String in ["bgm", "sfx", "ui"]:
			settings["audio"][k] = clampi(int(audio.get(k, SETTINGS_DEFAULT["audio"][k])), 0, 100)
	var disp: Variant = data.get("display", {})
	if disp is Dictionary:
		settings["display"]["fullscreen"] = bool(disp.get("fullscreen", false))
		var res := str(disp.get("resolution", "1152x648"))
		if res in ["1152x648", "1280x720", "1600x900", "1920x1080"]:
			settings["display"]["resolution"] = res
	var bg := str(data.get("background", "ambient"))
	if bg in ["ambient", "awakened_mech_01", "awakened_arcane_01", "awakened_xian_01"]:
		settings["background"] = bg
	_apply_settings()
	print("[UISystem] 设置档已读取：%s" % SETTINGS_PATH)


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("[UISystem] 设置档写入失败 err=%d" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(settings, "  "))
	f.close()
	print("[UISystem] 设置档已保存：%s" % SETTINGS_PATH)


## 单项写入并立即落盘 + 应用（设置面板音量条/全屏/分辨率共用）
func update_setting(section: String, key: String, value: Variant) -> void:
	if not settings.has(section):
		return
	settings[section][key] = value
	save_settings()
	_apply_settings()


## 背景选择（顶层标量键，不走 section.key 嵌套）
func set_background(value: String) -> void:
	if not value in ["ambient", "awakened_mech_01", "awakened_arcane_01", "awakened_xian_01"]:
		push_warning("[UISystem] 未知背景：%s" % value)
		return
	settings["background"] = value
	save_settings()


## 应用到引擎（画面项即时生效；音频三轨总线由音频岗 T6.x 接 AudioServer）
func _apply_settings() -> void:
	var fullscreen: bool = settings["display"]["fullscreen"]
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	var parts: PackedStringArray = str(settings["display"]["resolution"]).split("x")
	if parts.size() == 2 and not fullscreen:
		var sz := Vector2i(int(parts[0]), int(parts[1]))
		if DisplayServer.window_get_size() != sz:
			DisplayServer.window_set_size(sz)


## 主页背景取值（MainMenu._build_bg 消费；"ambient"=渐变占位，其余=角色立绘）
func get_main_background() -> String:
	return str(settings.get("background", "ambient"))
