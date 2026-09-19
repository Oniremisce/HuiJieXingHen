## =============================================================
## 《汇界星痕》T2.4 神像（四行为：恢复/点亮/传送/存档）
## -------------------------------------------------------------
## 架构 §2.2 + 推进表 T2.4：
##   恢复：光环 Area2D r=96，玩家进入 → ShrineSystem.restore_all +
##         飘字反馈 + EventBus.shrine_entered_radius（自动触发不弹 UI）
##   点亮：未点亮按 E → 1s 光柱+粒子演出 → 区块 unlock_region +
##         首亮奖励星砂×100 + 自动档 + ShrineSystem.light_shrine 广播
##         shrine_lit（重复按 E 不重复奖励：lit 后走菜单分支）
##   传送：由世界大地图点击经 Transition.transition_portal 触发，
##         落点 = MapSystem.SHRINES[id].spawn（神像旁出生点），本节点不实现
##   存档：已点亮按 E → 打开神像菜单（ShrineMenu，暂停世界）
## 视觉占位：色块神像 + 光柱 + 光环圈（draw_arc）+ CPUParticles2D 粒子。
## origin=脚底，挂地图根下参与 Y-sort。
## 点亮状态唯一真相 = ShrineSystem；本节点监听 shrine_lit 刷视觉（读档
## 回填 deserialize 补发信号 → 无需重进场景即刷新）。
## =============================================================
extends Node2D

const _ShrineMenu := preload("res://scripts/ui/ShrineMenu.gd")

const FIRST_LIGHT_SAND := 100  # 首亮奖励星砂（常量可调）
const LIGHT_DURATION := 1.0    # 点亮演出时长
const HALO_RADIUS := 96.0      # 恢复光环半径（与 HaloArea 碰撞圆一致）

@export var shrine_id: String = "camp_shrine_01"

var _player_in_halo := false
var _lighting := false
var _menu: CanvasLayer = null

@onready var _interact: Area2D = $Interactable
@onready var _hint_root: Node2D = $Interactable/HintRoot
@onready var _gem: Polygon2D = $Gem
@onready var _pillar: Polygon2D = $Pillar
@onready var _particles: CPUParticles2D = $Particles
@onready var _event_bus: Node = get_node("/root/EventBus")
@onready var _shrine_system: Node = get_node("/root/ShrineSystem")
@onready var _game_state: Node = get_node("/root/GameState")
@onready var _map_system: Node = get_node("/root/MapSystem")
@onready var _save_manager: Node = get_node("/root/SaveManager")


func _ready() -> void:
	if not _shrine_system.SHRINES.has(shrine_id):
		push_warning("[Shrine] 未知 shrine_id：%s（检查 ShrineSystem.SHRINES）" % shrine_id)
	_apply_lit_visuals(_shrine_system.is_shrine_lit(shrine_id))
	_set_hint_by_state()
	_event_bus.interact_requested.connect(_on_interact_requested)
	_event_bus.shrine_lit.connect(_on_shrine_lit)
	$HaloArea.body_entered.connect(_on_halo_body_entered)
	$HaloArea.body_exited.connect(_on_halo_body_exited)
	_menu = _ShrineMenu.new()
	_menu.name = "ShrineMenu"
	add_child(_menu)


func _draw() -> void:
	# 恢复光环圈：点亮金色 / 未点亮灰蓝；玩家在环内加亮
	var lit: bool = _shrine_system.is_shrine_lit(shrine_id)
	var col := Color(1.0, 0.84, 0.3, 0.45) if lit else Color(0.6, 0.68, 0.8, 0.28)
	if _player_in_halo:
		col.a = 0.85
	draw_arc(Vector2.ZERO, HALO_RADIUS, 0.0, TAU, 48, col, 1.5)


# ---------------------------------------------------------------
# 行为 1：恢复光环（自动，不弹 UI）
# ---------------------------------------------------------------

func _on_halo_body_entered(body: Node2D) -> void:
	if not (body is CharacterBody2D) or not (body.collision_layer & 2):
		return
	_player_in_halo = true
	queue_redraw()
	_shrine_system.restore_all()
	_event_bus.shrine_entered_radius.emit(shrine_id)
	_spawn_float_text("状态已恢复")
	print("[Shrine] 光环进入 -> shrine_entered_radius(%s)" % shrine_id)


func _on_halo_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and (body.collision_layer & 2):
		_player_in_halo = false
		queue_redraw()


# ---------------------------------------------------------------
# 行为 2/4：点亮 / 打开神像菜单（E 键交互，经 Interactable 仲裁）
# ---------------------------------------------------------------

func _on_interact_requested(node: Node) -> void:
	if node != _interact or _lighting:
		return
	if not _shrine_system.is_shrine_lit(shrine_id):
		_start_light_flow()
	else:
		# T2.5：面板开关统一走 UISystem 面板栈（Esc 逐层回退由其调度）
		get_node("/root/UISystem").open_panel("shrine_menu")


## 点亮流程：演出 1s → 区块解锁 → 首亮星砂 +100 → 自动档 → shrine_lit
func _start_light_flow() -> void:
	_lighting = true
	print("[Shrine] 点亮演出开始：%s（%.1fs）" % [shrine_id, LIGHT_DURATION])
	_hint_root.visible = false
	_pillar.visible = true
	_pillar.modulate.a = 0.0
	_particles.emitting = true
	var tw := create_tween()
	tw.tween_property(_pillar, "modulate:a", 0.85, LIGHT_DURATION * 0.5)
	await get_tree().create_timer(LIGHT_DURATION).timeout
	# 解锁所属区块（内含传送点语义：SHRINES 注册表即传送点）
	var region: String = _shrine_system.SHRINES.get(shrine_id, {}).get("region", "")
	if region != "":
		_map_system.unlock_region(region)
	# 首亮奖励（本流程仅未点亮态可进入，天然不重复）
	_game_state.add_sand(FIRST_LIGHT_SAND)
	print("[Shrine] 首亮奖励：星砂+%d（当前 %d）" % [FIRST_LIGHT_SAND, _game_state.star_sand])
	# lit 真值落 ShrineSystem（广播 shrine_lit → _on_shrine_lit 刷视觉/提示）
	_shrine_system.light_shrine(shrine_id)
	# 自动档触发点：点亮神像
	_save_manager.save_game("auto", true)
	_set_hint_by_state()
	_lighting = false


func _on_shrine_lit(id: String) -> void:
	if id != shrine_id:
		return
	_apply_lit_visuals(true)
	_set_hint_by_state()
	queue_redraw()


func _apply_lit_visuals(lit: bool) -> void:
	if lit:
		_gem.color = Color(0.55, 0.9, 1.0)
		_pillar.visible = true
		if _pillar.modulate.a < 0.3:
			_pillar.modulate.a = 0.30
	else:
		_gem.color = Color(0.42, 0.47, 0.55)
		_pillar.visible = false


func _set_hint_by_state() -> void:
	if _shrine_system.is_shrine_lit(shrine_id):
		_interact.set("hint_text", "按 E 打开神像菜单")
	else:
		_interact.set("hint_text", "按 E 点亮")


## 飘字反馈（占位）：上飘 + 淡出后自毁
func _spawn_float_text(text: String) -> void:
	var lb := Label.new()
	lb.text = text
	lb.position = Vector2(-44, -140)
	lb.z_index = 120
	lb.add_theme_font_size_override("font_size", 16)
	lb.add_theme_color_override("font_color", Color(0.7, 1.0, 0.95))
	add_child(lb)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lb, "position:y", -180.0, 1.2)
	tw.tween_property(lb, "modulate:a", 0.0, 1.2).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(lb.queue_free)
