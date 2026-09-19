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
	_fill_npc_names()
	_load_player_frames()
	print("[CampMap] ready: npcs=3 trigger=1 pickup=1 shrine=1")
	# T2.5 主角命名：首次进入营地弹命名面板（新档 flags 空 → 触发；
	# 读档已有 hero_named flag / 已命名则不弹；deferred 避开场景切换帧）
	_maybe_prompt_rename.call_deferred()


## T2.7 A1：觉醒者名牌正式名——npc_id 为唯一真相，运行时读 characters.csv
## 填充（display_name 不再硬编码在场景里；查不到保持空+告警不崩溃）
func _fill_npc_names() -> void:
	var dm := get_node("/root/DataManager")
	for npc in get_tree().get_nodes_in_group("quest_npc"):
		var npc_id := str(npc.get_meta("npc_id"))
		var cd: Variant = dm.get_character(npc_id)
		if cd == null:
			push_warning("[CampMap] NPC %s 在 characters.csv 查不到，名牌未填充" % npc_id)
			continue
		var inter := npc.get_node_or_null("Interactable")
		if inter != null:
			inter.set("display_name", cd.name)
		var tag := npc.get_node_or_null("NameTag/Label")
		if tag != null:
			tag.set("text", cd.name)


## T2.6 帧条接入：Player 角色自动挂 CharacterAnimator.load_frames
## 主角目前固定机律觉醒者（awakened_mech_01）；帧规格 idle 192×48=4 帧 / walk 384×48=8 帧
func _load_player_frames() -> void:
	var player := get_node_or_null("Player")
	if player == null:
		return
	var anim := player.get_node_or_null("CharacterAnimator")
	if anim == null:
		return
	var frames: SpriteFrames = ArtProvider.build_sprite_frames_for("awakened_mech_01")
	if frames == null:
		push_warning("[CampMap] 角色帧条构建失败")
		return
	anim.load_frames(frames)
	anim.set_dir(2)  # 默认朝南 s=2 作为 idle 立绘首帧
	print("[CampMap] Player 帧条已挂载（idle_<dir>/walk_<dir> 共 %d 动画）" % frames.get_animation_names().size())


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
