extends Node
## =============================================================
## T3.7 BattleController（挂地图场景；battle_started 消费链全程驱动）
## 流程：battle_started → Transition 淡出 → 原地图变身（隐藏非地板探索元素，
## §1/制作人04 裁决④；跑图 HUD 显隐自 T3.9 起归 MapSystem 战斗信号监听）→
## 叠 Battle 表现层 + BattleCutscene →
## BM 驱动（失败重试循环：空格重试/Esc 撤离，不卡死）→ 结算星砂（GameState
## 暂记，T6.1 迁移 Inventory）+ battle_finished → Transition 淡出还原 → 淡入。
## Transition 用 fade_out/in 成对（§1 地板真复用=原地变身，不 change_scene；
## 卡面 transition_scene 措辞以规则文档优先，登记交接班表）。
## =============================================================

const BM := preload("res://scripts/battle/battle_manager.gd")
const BATTLE_SCENE := preload("res://scenes/Battle.tscn")
const CUTSCENE_SCENE := preload("res://scenes/BattleCutscene.tscn")
const MANUAL := preload("res://scripts/battle/battle_manual_input.gd")  # T3.10 手动模式

var _active := false
var _layer: Node2D = null
var _hidden: Array = []
var _context := {}
var _waiting_input := false
var _retry := false
var _abort := false
var _manual = null               # T3.10 手动模式组件（BattleUI 下，首场创建复用）
var cutscene_factory := Callable()  # 测试注入 func() -> Node（同签名演出对象）；空=真演出场景

func _ready() -> void:
	get_node("/root/EventBus").battle_started.connect(_on_battle_started)

## battle_started 消费链（T5.2/T5.3 心契触发同信号复用；忙时忽略并告警）
func _on_battle_started(party_ids: Array, enemy_ids: Array, context: Dictionary) -> void:
	if _active:
		push_warning("[BattleController] 战斗进行中，忽略重复 battle_started")
		return
	_active = true
	_context = context
	print("[BattleController] battle_started party=%s enemies=%s context=%s" % [
		str(party_ids), str(enemy_ids), str(context)])
	var tr := get_node("/root/Transition")
	await tr.transition_fade_out()
	_layer = BATTLE_SCENE.instantiate()
	get_tree().current_scene.add_child(_layer)
	_layer.setup_stances(party_ids, enemy_ids)
	_hide_exploration()
	await tr.transition_fade_in()
	var dm := get_node("/root/DataManager")
	var outcome := "lose"
	var sand := 0
	var rounds := 0
	while true:  # 失败重试循环：每场独立 BM/演出层，battle_finished 每场各发一次
		var bm = BM.new(dm, party_ids, enemy_ids)
		# 演出对象：真演出层（Node，挂树接收跳过输入/显示）或鸭子对象（RefCounted 假演出，不挂树）
		var cs: Variant = cutscene_factory.call() if cutscene_factory.is_valid() else CUTSCENE_SCENE.instantiate()
		bm.cutscene = _layer.make_cutscene_proxy(cs)  # T3.8：转发代理（四方法契约不变，播毕通知跑条放行）
		if cs is Node:
			_layer.add_child(cs)
		_layer.attach_battle(bm)  # T3.8：速度条/参战行绑定（只读表现，每场重绑）
		if _manual == null:  # T3.10：手动模式组件（开关+状态机+箭头调度），首场创建复用
			_manual = MANUAL.new()
			_manual.name = "ManualInput"
			_layer.get_node("BattleUI").add_child(_manual)
		_manual.setup(bm, _layer)  # 每场重绑（command_provider 指向新 bm）
		outcome = await bm.run_to_end(30)
		rounds = bm.round_num
		if cs is Node:
			cs.queue_free()
		if outcome == "win":
			for eid in enemy_ids:
				var e: Variant = dm.get_enemy(String(eid))
				sand += int(e.drop_sand) if e != null else 0
		# T3.7 协作修正（系统程序05）：契约定稿四字段——补 star_sand_gained
		# （lose/timeout/aborted 场 sand 恒 0：仅 win 分支累加且即 break）
		get_node("/root/EventBus").battle_finished.emit({
			"outcome": outcome, "rounds": rounds, "context": _context,
			"star_sand_gained": sand})
		if outcome == "win":
			break
		_layer.show_retry()
		await _wait_retry_input()
		_layer.show_battle()
		if _abort:
			outcome = "aborted"  # 撤离：不再重试（无星砂；battle_finished 已发 timeout/lose）
			break
	if outcome == "win":
		get_node("/root/GameState").add_sand(sand)  # TODO T6.1：迁移 Inventory.add_sand
		print("[BattleController] 胜利结算：星砂 +%d（GameState.star_sand=%d）" % [
			sand, get_node("/root/GameState").star_sand])
	_layer.show_result(outcome == "win", sand)
	await get_tree().create_timer(2.2).timeout
	await tr.transition_fade_out()
	_layer.queue_free()
	_restore()
	await tr.transition_fade_in()
	_active = false
	print("[BattleController] 战斗收尾完成，已还原地图（outcome=%s）" % outcome)

## 原地变身：隐藏当前场景非地板探索元素（Ground 保留；跑图 HUD 显隐自 T3.9 起
## 归 MapSystem 战斗信号监听）
func _hide_exploration() -> void:
	_hidden.clear()
	var scene := get_tree().current_scene
	for c in scene.get_children():
		if c == _layer or c.name == "Ground":
			continue
		if c is Node2D and c.visible:
			_hidden.append(c)
			c.visible = false
	# T3.9：跑图 HUD 显隐归 MapSystem 战斗信号监听（battle_started/battle_finished），
	# 本层只藏场景内 Node2D，不再跨岗操作 MapSystem 常驻子节点

## 还原探索元素与跑图 HUD
func _restore() -> void:
	for n in _hidden:
		if is_instance_valid(n):
			n.visible = true
	_hidden.clear()

## 失败后等待玩家选择：空格=重试 / Esc=撤离
func _wait_retry_input() -> void:
	_retry = false
	_abort = false
	_waiting_input = true
	while not _retry and not _abort:
		await get_tree().process_frame
	_waiting_input = false

func _unhandled_input(e: InputEvent) -> void:
	if not _waiting_input:
		return
	if e.is_action_pressed("ui_accept"):
		_retry = true
	elif e.is_action_pressed("ui_cancel"):
		_abort = true
