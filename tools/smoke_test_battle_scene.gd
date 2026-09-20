extends SceneTree
## =============================================================
## T3.7 战斗场景接入冒烟（headless：先设 GODOT_MCP_RUNTIME_PORT='abc' 再
## godot --headless --path . --script res://tools/smoke_test_battle_scene.gd）
## 最小环境：root 挂 EventBus/Transition/GameState/DataManager/MapSystem{HUD}
## （均 headless --script 真实 autoload）+ 假地图（Ground/Decorations/Player(layer2)/
## BattleController）→ current_scene。
## 场景1 win 全链：battle_started(三觉醒者, [corrosion_beast], {quest_id}) →
##   变身（Controller 藏 Decorations/Player；HUD 由 MapSystem 战斗信号藏，Ground 保留）→ 战斗（假演出）→
##   battle_finished{win, context 透传} → star_sand=30（drop_sand）→ 还原
## 场景2 失败链：3v2 双兽 → 6 轮 timeout → battle_finished(timeout) →
##   空格重试 → 再 timeout → Esc 撤离 → aborted → 还原、star_sand 不变、不卡死
## =============================================================

const CTRL := preload("res://scripts/battle/battle_controller.gd")

var _failed := false
var _n := 0
var _hud_at_finish := false  # T3.9：battle_finished 发出时点的 HUD 可见性快照

class FakeCutscene extends RefCounted:
	var calls: Array = []
	func play_active(id: String) -> void:
		calls.append("active:" + id)
	func play_skill(id: String, skill_id: String) -> void:
		calls.append("skill:" + skill_id)
	func play_ult(id: String, skill_id: String) -> void:
		calls.append("ult:" + skill_id)
	func play_combo(combo_name: String = "三人合击") -> void:
		calls.append("combo:" + combo_name)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	# headless --script 模式 autoload 照常加载（实测）：直接用树内实例，
	# 切勿手动 new 同名节点（会被改名 @X@2，controller connect 到 autoload 而冒烟监听私有副本 → 信号错位）
	var eb = root.get_node("EventBus")
	var tr = root.get_node("Transition")
	var gs = root.get_node("GameState")
	var dm = root.get_node("DataManager")
	var ms = root.get_node("MapSystem")
	var hud = ms.get_node("HUD")
	# 假地图 + BattleController
	var map := Node2D.new()
	map.name = "Map"
	var ground := TileMapLayer.new()
	ground.name = "Ground"
	map.add_child(ground)
	var deco := Node2D.new()
	deco.name = "Decorations"
	map.add_child(deco)
	var player := CharacterBody2D.new()
	player.name = "Player"
	player.collision_layer = 2
	map.add_child(player)
	var ctrl = CTRL.new()
	ctrl.name = "BattleController"
	map.add_child(ctrl)
	ctrl.cutscene_factory = func(): return FakeCutscene.new()
	root.add_child(map)
	current_scene = map
	print("=== T3.7 战斗场景冒烟开始 ===")
	# 场景1：win 全链
	var results: Array = []
	eb.battle_finished.connect(func(r): results.append(r))
	eb.battle_finished.connect(func(_r): _hud_at_finish = hud.visible)  # T3.9：发出时点快照
	eb.battle_started.emit(["awakened_mech_01", "awakened_arcane_01", "awakened_xian_01"], ["corrosion_beast"], {"quest_id": "heartbond_01"})
	_check(not hud.visible)  # T3.9：battle_started 即藏（MapSystem 监听，无条件设值）
	await create_timer(1.0).timeout
	# T3.9：headless 假演出战斗可在 1s 内打完并发出 battle_finished（HUD 即时恢复），
	# 固定时刻断言 HUD 隐藏已成竞态——HUD 契约改由两端覆盖：发出即藏（上断言）+
	# battle_finished 时点已恢复（_hud_at_finish 快照）；此处只断言探索元素隐藏态
	print("[SMOKE] 场景1 发出1s后: hud.visible=%s deco.visible=%s（快战斗可能已收尾）" % [
		str(hud.visible), str(deco.visible)])
	_check(not deco.visible)  # 变身隐藏态：探索元素由 Controller 管，收尾还原前恒藏（§1/裁决④）
	while ctrl._active:
		await process_frame
	print("[SMOKE] 场景1: results=%s star_sand=%d deco=%s hud=%s" % [
		str(results), gs.star_sand, str(deco.visible), str(hud.visible)])
	_check(results.size() == 1 and results[0]["outcome"] == "win")
	_check(results[0]["context"] == {"quest_id": "heartbond_01"})  # context 透传（T5.3 消费）
	_check(gs.star_sand == 30)  # drop_sand=30 入账
	_check(deco.visible and hud.visible and player.visible and ground.visible)  # 战场隐藏已还原
	_check(_hud_at_finish)  # T3.9：battle_finished 发出时点 HUD 已恢复（MapSystem 监听）
	# 场景2：失败链——20 兽（总 hp 3000 / DPS 20）构造我方 30 轮内必败 →
	# battle_finished(lose) → 空格重试 → 再 lose → Esc 撤离 → 不卡死、无星砂
	var results2: Array = []
	eb.battle_finished.connect(func(r): results2.append(r))
	var horde: Array = []
	for i in range(20):
		horde.append("corrosion_beast")
	eb.battle_started.emit(["awakened_mech_01", "awakened_arcane_01", "awakened_xian_01"], horde, {})
	await _wait_flag(ctrl, "_waiting_input")
	_push_key(32)  # 空格：重试
	await _wait_flag_off(ctrl, "_waiting_input")  # 重试被接受（第一次等待退出）
	await _wait_flag(ctrl, "_waiting_input")      # 第二场 lose 后再次进入重试等待
	_push_key(4194305)  # Esc：撤离
	await _wait_flag_off(ctrl, "_waiting_input")  # 撤离被接受
	while ctrl._active:
		await process_frame
	print("[SMOKE] 场景2: results=%s star_sand=%d deco=%s" % [
		str(results2), gs.star_sand, str(deco.visible)])
	_check(results2.size() == 2 and results2[0]["outcome"] == "lose" and results2[1]["outcome"] == "lose")
	_check(gs.star_sand == 30 and deco.visible and hud.visible)  # 撤离无星砂、已还原、不卡死
	if _failed:
		print("=== T3.7 冒烟结束：存在失败项 ===")
		quit(1)
	else:
		print("=== T3.7 冒烟结束：全部通过 ===")
		quit(0)

## 轮询等待 controller 布尔字段变为 true（带超时防死锁）
func _wait_flag(ctrl, flag: String) -> void:
	var waited := 0.0
	while not bool(ctrl.get(flag)) and waited < 60.0:
		await process_frame
		waited += get_root().get_process_delta_time()

## 轮询等待 controller 布尔字段变为 false（输入被接受的确认）
func _wait_flag_off(ctrl, flag: String) -> void:
	var waited := 0.0
	while bool(ctrl.get(flag)) and waited < 60.0:
		await process_frame
		waited += get_root().get_process_delta_time()

func _push_key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code as Key
	ev.pressed = true
	root.push_input(ev)
	var up := InputEventKey.new()
	up.keycode = code as Key
	up.pressed = false
	root.push_input(up)

func _check(cond: bool) -> void:
	_n += 1
	if not cond:
		_failed = true
		print("[SmokeTest] 第 %d 个断言失败" % _n)
		push_error("[SmokeTest] 断言失败")
