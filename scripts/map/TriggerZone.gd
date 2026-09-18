## =============================================================
## 《汇界星痕》T1.6 B 类触发区（进入触发）
## -------------------------------------------------------------
## 规则依据：docs/系统规则/交互系统.md §5.3（T1.5 占位版）
## 职责：玩家 body_entered → emit EventBus.interact_requested(self)，
##       node 上以 meta "main_trigger" 标记（场景内设置，T4.3 接 Dialogic）。
## 单次触发：发过一次后永久失效（避免反复进出刷信号）。
## 约定：collision_mask=2 只检测玩家（T1.3 玩家 layer=2）。
## =============================================================
extends Area2D

const PLAYER_LAYER_BIT := 2  # T1.3 约定：玩家 collision_layer=2

var _fired := false

@onready var _event_bus: Node = get_node("/root/EventBus")

func _ready() -> void:
	# 调试视觉仅 debug 构建可见（美术建议：产品态不可见）
	$DebugVisual.visible = OS.is_debug_build()
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if _fired:
		return
	if body is CharacterBody2D and (body.collision_layer & PLAYER_LAYER_BIT):
		_fired = true
		print("[TriggerZone] main_trigger fired -> interact_requested")
		_event_bus.interact_requested.emit(self)
