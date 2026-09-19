## =============================================================
## 《汇界星痕》T4.2 DialogicBridge（Dialogic ↔ EventBus/GameState 桥接，Autoload 单例）
## -------------------------------------------------------------
## 职责：
##   1. 台词表登记：扫描 dialogues/timelines/*.dtl 与 dialogues/characters/*.dch
##      写入 Dialogic 资源目录（identifier→路径串），使 Dialogic.start("<timeline_id>")
##      短 id 可用（project.godot 目录仅作持久化缓存，运行时以扫描结果兜底自愈）。
##   2. 播放接口：start_timeline(timeline_id) —— 地图触发区/任务系统统一入口。
##   3. 信号桥接：Dialogic.signal_event → 解析协议 → GameState.dialogue_signal_bridge
##      （由 GameState 写 flag / 广播 EventBus.quest_updated 等）。
##   4. 生命周期转发：timeline_started/ended → EventBus.dialogue_started/dialogue_finished
##      （timeline_id 与对话 CSV 的 timeline_id 一致，供 T4.3 暂停世界、T5.3/T5.4 任务关闭消费）。
## 信号协议（signal 事件 arg 字符串）："事件名[:k=v[;k=v...]]"
##   - set_flag:<flag>            → data={"flag": <flag>, "value": true}
##   - set_flag:<flag>=<值>       → data={"flag": <flag>, "value": <值>}（数字自动转 int）
##   - 其他事件 → 按 k=v; k=v 平铺为 data 字典（如 quest_advance:quest_id=main_01;step=2）
## 依赖：EventBus、GameState（本 autoload 注册于尾部，晚于二者初始化）。
## =============================================================
extends Node

const _DRU := preload("res://addons/dialogic/Core/DialogicResourceUtil.gd")

const TIMELINE_DIR := "res://dialogues/timelines"
const CHARACTER_DIR := "res://dialogues/characters"

## 当前播放的 timeline_id（start_timeline 时登记，供信号转发携带）
var _current_timeline_id := ""


func _ready() -> void:
	_fill_directories()
	var dialogic := get_node("/root/Dialogic")
	dialogic.signal_event.connect(_on_dialogic_signal)
	dialogic.timeline_started.connect(_on_timeline_started)
	dialogic.timeline_ended.connect(_on_timeline_ended)
	# T4.3：世界暂停（PauseManager）期间对话照常播放——Dialogic 根设 ALWAYS
	# （layout 节点在 start_timeline 中单独设置；子节点 INHERIT 随根生效）
	dialogic.process_mode = Node.PROCESS_MODE_ALWAYS
	var dtl_dir: Dictionary = _DRU.get_directory("dtl")
	print("[DialogicBridge] ready: timelines=%s" % [str(dtl_dir.keys())])


## 播放指定 timeline（对外统一入口）。传 CSV 的 timeline_id（= .dtl 文件名）。
func start_timeline(timeline_id: String) -> Variant:
	_current_timeline_id = timeline_id
	_fill_directories()  # 新转换的 .dtl 无需重启即可播放
	var dialogic := get_node("/root/Dialogic")
	dialogic.process_mode = Node.PROCESS_MODE_ALWAYS  # 每次播放前兜底
	var layout: Variant = null
	if _DRU.get_directory("dtl").has(timeline_id):
		layout = dialogic.start(timeline_id)
	elif FileAccess.file_exists(TIMELINE_DIR + "/" + timeline_id + ".dtl"):
		layout = dialogic.start(TIMELINE_DIR + "/" + timeline_id + ".dtl")
	else:
		push_error("[DialogicBridge] 未知 timeline_id：%s（无对应 .dtl）" % timeline_id)
		return null
	# start() 返回 layout 节点（挂 /root 下，不随 Dialogic 根继承）→ 单独设 ALWAYS
	if layout is Node:
		(layout as Node).process_mode = Node.PROCESS_MODE_ALWAYS
	return layout


## ------------------------------------------------------------
## Dialogic 信号处理
## ------------------------------------------------------------
func _on_dialogic_signal(argument: Variant) -> void:
	if argument is Dictionary:
		# Dictionary 型 arg 预留：{"event": 事件名, ...键值平铺}
		var d: Dictionary = argument
		_dispatch(str(d.get("event", "")), d.duplicate())
		return
	var text := str(argument).strip_edges()
	if text.is_empty():
		return
	var colon := text.find(":")
	var event_name := text if colon < 0 else text.substr(0, colon).strip_edges()
	var spec := "" if colon < 0 else text.substr(colon + 1).strip_edges()
	match event_name:
		"set_flag":
			_dispatch("set_flag", _parse_set_flag(spec))
		_:
			_dispatch(event_name, _parse_spec(spec))


## set_flag 规格：<flag> 或 <flag>=<值>
func _parse_set_flag(spec: String) -> Dictionary:
	var eq := spec.find("=")
	if eq < 0:
		return {"flag": spec.strip_edges(), "value": true}
	var flag_name := spec.substr(0, eq).strip_edges()
	var value_text := spec.substr(eq + 1).strip_edges()
	var value: Variant = int(value_text) if value_text.is_valid_int() else value_text
	return {"flag": flag_name, "value": value}


## 通用规格：k=v; k=v（数字转 int/float，其余保持字符串）
func _parse_spec(spec: String) -> Dictionary:
	var data := {}
	for pair in spec.split(";", false):
		var eq := pair.find("=")
		if eq < 0:
			data[pair.strip_edges()] = true
			continue
		var k := pair.substr(0, eq).strip_edges()
		var v := pair.substr(eq + 1).strip_edges()
		data[k] = int(v) if v.is_valid_int() else (float(v) if v.is_valid_float() else v)
	return data


## 统一转发 GameState（flag 写入与 EventBus 广播的分发真相在 GameState）
func _dispatch(event_name: String, data: Dictionary) -> void:
	print("[DialogicBridge] signal: event=%s data=%s" % [event_name, str(data)])
	get_node("/root/GameState").dialogue_signal_bridge(event_name, data)


## ------------------------------------------------------------
## 生命周期转发（供任务关闭等消费）
## ------------------------------------------------------------
func _on_timeline_started() -> void:
	get_node("/root/EventBus").dialogue_started.emit(_current_timeline_id)


func _on_timeline_ended() -> void:
	print("[DialogicBridge] timeline_ended: %s" % _current_timeline_id)
	get_node("/root/EventBus").dialogue_finished.emit(_current_timeline_id)
	_current_timeline_id = ""


## ------------------------------------------------------------
## 资源目录登记（identifier→路径串；TextEvent speaker 反查与短 id 播放依赖此表）
## ------------------------------------------------------------
func _fill_directories() -> void:
	var dtl_dir: Dictionary = _DRU.get_directory("dtl")
	for fname in _list_dir(TIMELINE_DIR, "dtl"):
		dtl_dir[fname.get_basename()] = TIMELINE_DIR + "/" + fname
	_DRU.set_directory("dtl", dtl_dir)
	var dch_dir: Dictionary = _DRU.get_directory("dch")
	for fname in _list_dir(CHARACTER_DIR, "dch"):
		dch_dir[fname.get_basename()] = CHARACTER_DIR + "/" + fname
	_DRU.set_directory("dch", dch_dir)


func _list_dir(path: String, ext: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var dir := DirAccess.open(path)
	if dir == null:
		return out
	for fname in dir.get_files():
		if fname.ends_with("." + ext):
			out.append(fname)
	return out
