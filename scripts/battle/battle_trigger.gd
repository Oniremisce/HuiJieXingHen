extends Area2D
## =============================================================
## T3.7 战斗触发区（部署者手动测试调整版，制作人04 执行）
## 玩家进入触发区 → 显示「按 E：开战」提示 → 按 E 手动触发
## battle_started(party_ids, enemy_ids, context)；不自动触发。
## 每次重新进入触发区重置 _fired（可反复测试）；触发区内战后不重复触发，
## 需走出再进入。enemy_ids/context 以节点 meta 配置（缺省 corrosion_beast）；
## party_ids 取 Party.get_members()，编队为空时兜底三觉醒者。
## =============================================================

const PLAYER_LAYER_BIT := 2  # T1.3 约定：玩家 collision_layer=2

var _fired := false
var _in_range := false
var _hint: Label

func _ready() -> void:
	$DebugVisual.visible = OS.is_debug_build()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_hint = Label.new()
	_hint.text = "按 E：开战"
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color(1, 1, 0.6, 1))
	_hint.position = Vector2(-44, -56)
	_hint.z_index = 100
	_hint.visible = false
	add_child(_hint)
	_ensure_input_action()

func _ensure_input_action() -> void:
	# 代码兜底注册（T1.5 Interactable 先例：防编辑器覆写回滚）
	if InputMap.has_action("interact"):
		return
	InputMap.add_action("interact")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	InputMap.action_add_event("interact", ev)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and (body.collision_layer & PLAYER_LAYER_BIT):
		_in_range = true
		_fired = false  # 每次进入重置，支持反复测试
		_hint.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and (body.collision_layer & PLAYER_LAYER_BIT):
		_in_range = false
		_hint.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if _fired or not _in_range:
		return
	if event.is_action_pressed("interact"):
		_fired = true
		_hint.visible = false
		var party: Array = []
		var p := get_node_or_null("/root/Party")
		if p != null:
			party = p.get_members()
		if party.is_empty():
			party = ["awakened_mech_01", "awakened_arcane_01", "awakened_xian_01"]
		var enemies: Array = get_meta("enemy_ids", ["corrosion_beast"])
		var context: Dictionary = get_meta("context", {})
		print("[BattleTrigger] manual fire (E) -> battle_started party=%s enemies=%s context=%s" % [
			str(party), str(enemies), str(context)])
		get_node("/root/EventBus").battle_started.emit(party, enemies, context)
