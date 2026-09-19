## =============================================================
## 《汇界星痕》T1.5 交互体（A 类按键交互）
## -------------------------------------------------------------
## 规则依据：docs/系统规则/交互系统.md（T1.5 占位版，系统策划01 定稿）
## 职责：玩家进入/离开检测区 → 显隐头顶提示；范围内按 E/空格 →
##       仲裁最近者后 emit EventBus.interact_requested(self)。
## 本体不硬编码任何业务行为：action_type 枚举由业务方注册分发
## （MVP 占位枚举 talk/open；下游：T4.2/T4.4 对话、T1.6 拾取）。
## 约定：节点 origin = 脚底（与 T1.2 实体原点规范一致）。
## =============================================================
extends Area2D

const _CharacterAnimator := preload("res://scripts/map/CharacterAnimator.gd")
const _OcclusionOutline := preload("res://scripts/map/OcclusionOutline.gd")

const ACTION_INTERACT := "interact"
const INTERACTABLE_GROUP := "interactable"
const PLAYER_LAYER_BIT := 2  # T1.3 约定：玩家 collision_layer=2

@export var npc_id: String = ""
@export var display_name: String = "":
	set(value):
		display_name = value
		_refresh_hint_text()
@export var action_type: String = "talk"

var _player: Node2D = null
var _visual_queued := false  # deferred 添加防重复排队

@onready var _hint_root: Node2D = $HintRoot
@onready var _hint_label: Label = $HintRoot/Label
@onready var _event_bus: Node = get_node("/root/EventBus")

func _ready() -> void:
	add_to_group(INTERACTABLE_GROUP)
	_ensure_input_action()
	_ensure_visual_helpers()
	_refresh_hint_text()
	_hint_root.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## T2.3：向宿主实体根（本节点所属 NPC 的 Node2D 根）自动安装遮挡描边
## 与八向动画占位组件（无需改 .tscn）。宿主不是 Node2D 或就是当前场景根
## （即 Interactable 直接挂在场景下、无实体根，如纯触发点）时跳过。
## 注意：场景实例化期间父节点尚在构建子级，直接 add_child 会被拒
## （Parent node is busy setting up children）→ 必须 call_deferred。
func _ensure_visual_helpers() -> void:
	var host := get_parent()
	if host == null or not (host is Node2D):
		return
	if host == get_tree().current_scene:
		return
	if _visual_queued or host.has_node("OcclusionOutline"):
		return
	_visual_queued = true
	var ol := _OcclusionOutline.new()
	ol.name = "OcclusionOutline"
	host.add_child.call_deferred(ol)
	var an := _CharacterAnimator.new()
	an.name = "CharacterAnimator"
	host.add_child.call_deferred(an)

## 兜底注册 interact action（同 PlayerController._ensure_input_actions 模式）：
## project.godot 已绑定 E/空格 physical_keycode，但编辑器覆写磁盘配置时
## 游戏进程可能读到缺 action 的设置，运行时补注册保证按键可用。
func _ensure_input_action() -> void:
	if InputMap.has_action(ACTION_INTERACT):
		return
	InputMap.add_action(ACTION_INTERACT)
	for keycode: Key in [KEY_E, KEY_SPACE]:
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode
		InputMap.action_add_event(ACTION_INTERACT, ev)

func _refresh_hint_text() -> void:
	if _hint_label:
		_hint_label.text = "%s [E]" % display_name

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and (body.collision_layer & PLAYER_LAYER_BIT):
		_player = body
		_hint_root.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null
		_hint_root.visible = false

func _process(_delta: float) -> void:
	if _player and Input.is_action_just_pressed(ACTION_INTERACT):
		_try_trigger()

## R2/R3：同帧多个交互体命中时只触发距玩家脚底最近的一个；
## 距离相同按场景树顺序取先者（get_nodes_in_group 返回树序，
## 严格更近才替换 → 相同距离保留树序先者）。
func _try_trigger() -> void:
	var best: Area2D = null
	var best_d := INF
	for it in get_tree().get_nodes_in_group(INTERACTABLE_GROUP):
		if it._player == null:
			continue
		var d: float = it.global_position.distance_squared_to(it._player.global_position)
		if d < best_d:
			best_d = d
			best = it
	if best == self:
		# 占位日志（规则 §6 边界 4：信号无业务消费时打印即可，业务接入后由业务反馈）
		print("[Interactable] interact_requested -> npc_id=%s display=%s action=%s" % [npc_id, display_name, action_type])
		_event_bus.interact_requested.emit(self)
