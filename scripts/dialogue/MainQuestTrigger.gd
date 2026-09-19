## =============================================================
## 《汇界星痕》T4.3 主线剧情触发器（CampMap/MainQuestTrigger 独立节点）
## -------------------------------------------------------------
## 链路：TriggerZone（B 类进入触发，T1.6 先例）→ EventBus.interact_requested
##       → 本节点过滤 meta "main_trigger" → 暂停世界 → DialogicBridge 播放 main_01
##       → EventBus.dialogue_finished → 恢复世界 → main_01_done 后自动存档。
## 设计约束（跨岗最小侵入）：不改 CampMap.gd 现有逻辑（其 main_trigger 分支
##   仅占位日志，与本节点并存无冲突）；场景接入只需在 CampMap.tscn 挂本节点。
## 暂停约定：reason="dialogue"（PauseManager 计数配对）；播放期间 Dialogic
##   与 layout 由 DialogicBridge 设 PROCESS_MODE_ALWAYS，世界（地图/玩家）停摆。
## 防重播：GameState.has_flag("main_01_done") → 已完触发区只出提示文字不重播
##   （TriggerZone 的 _fired 仅会话内单次，读档后由本 flag 兜底）。
## 自动存档：main_01_done 落库后 save_game("auto", true)（自动档触发点=主线段落关闭；
##   会话内 _auto_saved 防重，读档后 flag 已在档内不再触发）。
## 依赖：EventBus、PauseManager、GameState、SaveManager、DialogicBridge（均为 Autoload）。
## 下游：T4.4 NPC 闲聊、T5.3 任务系统（quest_advance 事件）、T4.4+ 更多主线段落
##   复用本触发器模式（TIMELINE_ID/FLAG_DONE 常量参数化）。
## =============================================================
extends Node

const TIMELINE_ID := "main_01"
const FLAG_DONE := "main_01_done"
const PAUSE_REASON := "dialogue"
const HINT_DONE := "主线剧情已完成"

var _playing := false
var _auto_saved := false
var _hint_shown := false

@onready var _event_bus: Node = get_node("/root/EventBus")
@onready var _pause: Node = get_node("/root/PauseManager")
@onready var _state: Node = get_node("/root/GameState")
@onready var _saver: Node = get_node("/root/SaveManager")


func _ready() -> void:
	_event_bus.interact_requested.connect(_on_interact_requested)
	_event_bus.dialogue_finished.connect(_on_dialogue_finished)
	# 读档/重启后主线已完成 → 直接出提示（等 TriggerZone fire 后再出，避免场景加载期闪现）
	print("[MainQuestTrigger] ready: timeline=%s done=%s" % [TIMELINE_ID, str(_state.has_flag(FLAG_DONE))])


## 触发区分发：只消费 meta main_trigger 的节点（B 类进入触发）
func _on_interact_requested(node: Node) -> void:
	if _playing or not node.has_meta("main_trigger"):
		return
	if _state.has_flag(FLAG_DONE):
		_show_done_hint()
		return
	_playing = true
	_pause.pause_game(PAUSE_REASON)
	print("[MainQuestTrigger] 触发主线 %s（世界已暂停）" % TIMELINE_ID)
	get_node("/root/DialogicBridge").start_timeline(TIMELINE_ID)


## 播放结束：恢复世界；主线完成 flag 已写入 → 自动存档（一次）
func _on_dialogue_finished(timeline_id: String) -> void:
	if not _playing or timeline_id != TIMELINE_ID:
		return
	_playing = false
	_pause.resume_game(PAUSE_REASON)
	print("[MainQuestTrigger] 主线 %s 播放结束（世界已恢复）" % TIMELINE_ID)
	if _state.has_flag(FLAG_DONE) and not _auto_saved:
		_auto_saved = true
		var ok: bool = _saver.save_game("auto", true)
		print("[MainQuestTrigger] 自动存档触发 -> save_game(auto)=%s" % str(ok))


## 已完成提示：触发区上方常驻文字（世界坐标，Node2D+Label，T1.6 NameTag 先例）
func _show_done_hint() -> void:
	if _hint_shown:
		return
	_hint_shown = true
	var trigger := get_node_or_null("../MainTrigger")
	var pos: Vector2 = trigger.position if trigger != null else Vector2.ZERO
	var root := Node2D.new()
	root.name = "DoneHint"
	root.position = pos + Vector2(0, -96)
	root.z_index = 100
	var label := Label.new()
	label.name = "HintLabel"
	label.text = HINT_DONE
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	label.position = Vector2(-48, 0)
	root.add_child(label)
	add_child(root)
	print("[MainQuestTrigger] 主线已完成 -> 触发区只出提示不重播")
