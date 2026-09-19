extends Node2D
## T4.1 Dialogic 2 冒烟验证场景脚本（scenes/Main.tscn）
## 按 1 键播放 dialogues/timelines/smoke_test.dtl，结束打印 [DIALOGIC] ended。
## 注意：只做播放验证，不改 main_scene（T7.1 前保持 CampMap）。

const TIMELINE_PATH := "res://dialogues/timelines/smoke_test.dtl"
const CHARACTER_PATH := "res://dialogues/characters/test_npc.dch"
const CHARACTER_ID := "test_npc"
## 静态工具类按项目约定 preload 引用（规避 script_check 离线校验对全局 class_name 的误报）
const DRU := preload("res://addons/dialogic/Core/DialogicResourceUtil.gd")

var dialogic: Variant
var playing := false


func _ready() -> void:
	dialogic = get_node("/root/Dialogic")
	# character identifier 运行时兜底：按编辑器同款形态把 identifier -> 路径串写入 dch 目录
	# （TextEvent 的 identifier 反查走 resource_path -> 目录值匹配，必须存路径串而非 Resource）
	var dch_dir: Dictionary = DRU.get_directory("dch")
	dch_dir[CHARACTER_ID] = CHARACTER_PATH
	DRU.set_directory("dch", dch_dir)
	dialogic.timeline_started.connect(_on_timeline_started)
	dialogic.timeline_ended.connect(_on_timeline_ended)
	print("[SMOKE] 就绪，按 1 播放 ", TIMELINE_PATH)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1 or event.physical_keycode == KEY_1:
			_start_smoke()


func _start_smoke() -> void:
	if playing:
		return
	playing = true
	print("[SMOKE] 开始播放")
	dialogic.start(TIMELINE_PATH)


func _on_timeline_started() -> void:
	print("[DIALOGIC] started")


func _on_timeline_ended() -> void:
	playing = false
	print("[DIALOGIC] ended ", TIMELINE_PATH)
