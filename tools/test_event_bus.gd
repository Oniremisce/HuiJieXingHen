## =============================================================
## 《汇界星痕》T0.4 冒烟测试：跨场景信号收发 + GameState 读写 + Autoload 顺序
## -------------------------------------------------------------
## 模拟：场景 A（发送方）emit 全部总线信号；场景 B（接收方，另一脚本路径
## 模拟的独立节点逻辑）connect 后打印，控制台互证收发一致。
## 运行：game_start(scene_path="res://tools/TestEventBus.tscn")，跑完自动退出。
## =============================================================
extends Node2D

var _failed := false

func _ready() -> void:
	print("=== T0.4 事件总线与全局状态测试开始 ===")
	var bus := get_node("/root/EventBus")
	var state := get_node("/root/GameState")

	_check_autoload_order()

	# ---- 场景 B（接收方）：连接全部信号，收到即打印 ----
	bus.interact_requested.connect(_on_interact_requested)
	bus.dialogue_started.connect(_on_dialogue_started)
	bus.dialogue_finished.connect(_on_dialogue_finished)
	bus.battle_started.connect(_on_battle_started)
	bus.battle_finished.connect(_on_battle_finished)
	bus.quest_updated.connect(_on_quest_updated)
	bus.summon_completed.connect(_on_summon_completed)
	bus.character_recruited.connect(_on_character_recruited)

	# ---- 场景 A（发送方）：逐个发射 ----
	var fake_npc := Node2D.new()
	fake_npc.name = "Npc_Mech_01"
	add_child(fake_npc)
	bus.interact_requested.emit(fake_npc)
	bus.dialogue_started.emit("main_01")
	bus.quest_updated.emit("heartbond_01", 1)
	bus.battle_started.emit(["corrosion_beast"])
	bus.battle_finished.emit({"outcome": "win", "rounds": 3})
	bus.summon_completed.emit({"entry_id": "entry_starlink_01", "name": "星缘令", "kind": "starlink_token", "gold": true})
	bus.character_recruited.emit("awakened_mech_01")
	bus.dialogue_finished.emit("main_01")

	# ---- GameState 读写 ----
	_check(state.star_sand == 0 and state.starlink_tokens == 0 and state.flags.is_empty(),
		"初始值应为 0/空")
	state.star_sand += 150
	state.starlink_tokens += 1
	state.set_flag("met_mech_01")
	state.set_flag("affection_mech_01", 30)
	_check(state.star_sand == 150, "star_sand 应为 150")
	_check(state.starlink_tokens == 1, "starlink_tokens 应为 1")
	_check(state.has_flag("met_mech_01") and state.get_flag("met_mech_01") == true,
		"布尔 flag 读写")
	_check(state.get_flag("affection_mech_01") == 30, "数值 flag 读写")
	_check(not state.has_flag("nonexistent") and state.get_flag("nonexistent") == null,
		"不存在的 flag 返回默认")

	# ---- 桥接骨架调用（T4.2 前仅回显） ----
	state.dialogue_signal_bridge("quest_advance", {"quest_id": "heartbond_01", "step": 1})

	if _failed:
		push_error("[T0.4 测试] 存在失败断言！")
		print("=== T0.4 测试结束：存在失败项 ===")
		get_tree().quit(1)
	else:
		print("=== T0.4 测试结束：全部通过 ===")
		get_tree().quit(0)


## Autoload 顺序：EventBus 必须先于 GameState（依赖方）
func _check_autoload_order() -> void:
	var names := PackedStringArray()
	for child in get_tree().root.get_children():
		names.append(String(child.name))
	var bus_idx := names.find("EventBus")
	var state_idx := names.find("GameState")
	print("[T0.4] Autoload 顺序：", " -> ".join(names))
	_check(bus_idx != -1 and state_idx != -1 and bus_idx < state_idx,
		"EventBus 应先于 GameState 加载")


func _check(cond: bool, label: String) -> void:
	if cond:
		print("[T0.4] 通过：%s" % label)
	else:
		_failed = true
		push_error("[T0.4] 断言失败：%s" % label)


# ---- 场景 B 接收回调 ----
func _on_interact_requested(node: Node) -> void:
	print("[场景B] 收到 interact_requested：node=%s" % node.name)

func _on_dialogue_started(timeline_id: String) -> void:
	print("[场景B] 收到 dialogue_started：timeline=%s" % timeline_id)

func _on_dialogue_finished(timeline_id: String) -> void:
	print("[场景B] 收到 dialogue_finished：timeline=%s" % timeline_id)

func _on_battle_started(enemy_ids: Array) -> void:
	print("[场景B] 收到 battle_started：enemies=%s" % str(enemy_ids))

func _on_battle_finished(result: Dictionary) -> void:
	print("[场景B] 收到 battle_finished：%s" % str(result))

func _on_quest_updated(quest_id: String, step: int) -> void:
	print("[场景B] 收到 quest_updated：quest=%s, step=%d" % [quest_id, step])

func _on_summon_completed(result: Dictionary) -> void:
	print("[场景B] 收到 summon_completed：%s" % str(result))

func _on_character_recruited(character_id: String) -> void:
	print("[场景B] 收到 character_recruited：id=%s" % character_id)
