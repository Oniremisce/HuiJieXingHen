extends Area2D
## =============================================================
## T3.7 战斗触发点（复用 T1.6 TriggerZone 模式：进入单次触发）
## 玩家进入 → EventBus.battle_started(party_ids, enemy_ids, context)。
## enemy_ids/context 以节点 metadata 配置（场景内可调，缺省 corrosion_beast）；
## party_ids 取 Party.get_members()，编队为空时兜底三觉醒者（T2.2 编队 UI 前）。
## =============================================================

const PLAYER_LAYER_BIT := 2  # T1.3 约定：玩家 collision_layer=2

var _fired := false

func _ready() -> void:
	$DebugVisual.visible = OS.is_debug_build()
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if _fired:
		return
	if body is CharacterBody2D and (body.collision_layer & PLAYER_LAYER_BIT):
		_fired = true
		var party: Array = []
		var p := get_node_or_null("/root/Party")
		if p != null:
			party = p.get_members()
		if party.is_empty():
			party = ["awakened_mech_01", "awakened_arcane_01", "awakened_xian_01"]
		var enemies: Array = get_meta("enemy_ids", ["corrosion_beast"])
		var context: Dictionary = get_meta("context", {})
		print("[BattleTrigger] fired -> battle_started party=%s enemies=%s context=%s" % [
			str(party), str(enemies), str(context)])
		get_node("/root/EventBus").battle_started.emit(party, enemies, context)
