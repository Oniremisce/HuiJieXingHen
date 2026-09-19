## =============================================================
## 《汇界星痕》T1.6 营地地图（业务分发层）
## -------------------------------------------------------------
## 场景：scenes/map/CampMap.tscn（汇界营地：广场 + 3 觉醒者 NPC +
##       主线触发区 + 星砂结晶拾取点）。
## 职责：监听 EventBus.interact_requested，按交互系统规则分发：
##   - meta "main_trigger"（B 类触发区）→ 占位日志，T4.3 接 Dialogic；
##   - action_type "open" + npc_id "star_sand_crystal" → 拾取：
##     写入 GameState flag（骨架；Inventory 由 T6.1 完善后迁移
##     Inventory.add_item）并移除拾取点；
##   - action_type "talk"（3 NPC）→ 本卡不处理，Interactable 已有
##     占位日志，T4.2/T4.4 接 Dialogic。
## =============================================================
extends Node2D

const PICKUP_CRYSTAL_ID := "star_sand_crystal"
const FLAG_ITEM_CRYSTAL := "inv_star_sand_crystal"  # 骨架 flag，T6.1 迁移 Inventory

@onready var _event_bus: Node = get_node("/root/EventBus")
@onready var _game_state: Node = get_node("/root/GameState")
@onready var _crystal: Node2D = $StarSandCrystal

func _ready() -> void:
	_event_bus.interact_requested.connect(_on_interact_requested)
	print("[CampMap] ready: npcs=3 trigger=1 pickup=1 shrine=1")
	# T2.5 主角命名：首次进入营地弹命名面板（新档 flags 空 → 触发；
	# 读档已有 hero_named flag / 已命名则不弹；deferred 避开场景切换帧）
	_maybe_prompt_rename.call_deferred()


## 命名触发（MVP 简化：CampMap 首次进入判定一次）
func _maybe_prompt_rename() -> void:
	var gs := get_node("/root/GameState")
	if gs.has_flag("hero_named"):
		return
	get_node("/root/UISystem").open_panel("rename")
	print("[CampMap] 首次进入营地 -> 弹出主角命名面板")

func _on_interact_requested(node: Node) -> void:
	if node.has_meta("main_trigger"):
		print("[CampMap] main_trigger received（T4.3 接 Dialogic 主线）")
		return
	if node.get("action_type") == "open" and node.get("npc_id") == PICKUP_CRYSTAL_ID:
		_game_state.set_flag(FLAG_ITEM_CRYSTAL, 1)
		print("[CampMap] pickup %s -> GameState.%s=1（Inventory 由 T6.1 迁移）" % [PICKUP_CRYSTAL_ID, FLAG_ITEM_CRYSTAL])
		if is_instance_valid(_crystal):
			_crystal.queue_free()
