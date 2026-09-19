extends Node2D
## =============================================================
## 《汇界星痕》T4.1/T4.2 Dialogic 冒烟验证场景（scenes/Main.tscn）
## -------------------------------------------------------------
## 按 1 播放 smoke_test（T4.2 起由 data/csv/dialogues_smoke.csv 转换生成）
## 按 2 播放 smoke_bridge（set_flag 写入 + flag_condition 条件行验证）
## 播放统一走 DialogicBridge.start_timeline（验证桥接接口自身）；
## 目录登记/信号桥接均由 DialogicBridge（Autoload）承担。
## =============================================================
const TIMELINES := {
	KEY_1: "smoke_test",
	KEY_2: "smoke_bridge",
}

var dialogic: Variant
var bridge: Variant
var playing := false
var _current_id := ""


func _ready() -> void:
	dialogic = get_node("/root/Dialogic")
	bridge = get_node("/root/DialogicBridge")
	dialogic.timeline_started.connect(_on_timeline_started)
	dialogic.timeline_ended.connect(_on_timeline_ended)
	print("[SMOKE] 就绪，按 1 播放 smoke_test，按 2 播放 smoke_bridge")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		for key in TIMELINES:
			if event.keycode == key or event.physical_keycode == key:
				_start_smoke(TIMELINES[key])
				return


func _start_smoke(timeline_id: String) -> void:
	if playing:
		return
	playing = true
	_current_id = timeline_id
	print("[SMOKE] 开始播放 " + timeline_id)
	bridge.start_timeline(timeline_id)


func _on_timeline_started() -> void:
	print("[DIALOGIC] started")


func _on_timeline_ended() -> void:
	playing = false
	print("[DIALOGIC] ended " + _current_id)
