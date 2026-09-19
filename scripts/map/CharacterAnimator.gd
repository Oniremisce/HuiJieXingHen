## =============================================================
## 《汇界星痕》T2.3 八向帧动画接口（视觉挂点，占位阶段）
## -------------------------------------------------------------
## 架构 §1.2：屏幕空间 8 方向独立姿势组（斜向独立资源非翻转），
## idle 4 帧 ~3s / walk 6~8 帧 ~0.6s。
## 占位阶段：色块视觉继续由本节点驱动（行走挤压拉伸，逻辑自
## PlayerController 迁入）；美术帧条接入后调 load_frames(SpriteFrames)
## 切换到 AnimatedSprite2D 路径（动画名 idle_<dir> / walk_<dir>），
## PlayerController 走停切换已统一改走 play()/set_dir_from_angle() 接口。
## 方向编码：dir_index = round(屏幕角度 / 45°) wrap 到 0..7，
## DIR_NAMES = [e, se, s, sw, w, nw, n, ne]（0=东，顺时针）。
## 挂载：Player 根 / NPC 实体根（Interactable 自动安装）。
## =============================================================
extends Node2D

signal anim_state_changed(state: String, dir_index: int)

const DIR_NAMES: Array[String] = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
const WALK_FREQ := 10.0    # 行走挤压频率（占位）
const BOB_AMOUNT := 0.08   # 挤压拉伸幅度
const SHADE_AMOUNT := 0.15 # 明暗呼吸幅度

## 美术帧条（T2.6 接入：8 向 idle/walk 动画名 "<state>_<dir>"）；null = 占位模式
var frames: SpriteFrames = null
## 当前状态（"idle" / "walk"）
var state: String = "idle"
## 当前朝向索引（0..7，见 DIR_NAMES；默认朝南 s=2）
var dir_index: int = 2

var _t := 0.0
var _anim_sprite: AnimatedSprite2D = null
var _placeholder: Control = null  # 色块占位（Player 的 VisualRoot/Sprite）
var _placeholder_dirty := true


func _ready() -> void:
	_find_placeholder()


## 接入真实帧条（T2.6）：传入含 idle_<dir>/walk_<dir> 动画的 SpriteFrames
func load_frames(f: SpriteFrames) -> void:
	frames = f
	if f == null:
		return
	if _anim_sprite == null:
		_anim_sprite = AnimatedSprite2D.new()
		_anim_sprite.name = "AnimSprite"
		# T2.6：帧 48×48，足底对齐节点原点 → offset=(0,-24) 中心向上
		_anim_sprite.offset = Vector2(0.0, -24.0)
		add_child(_anim_sprite)
	_anim_sprite.sprite_frames = f
	# 隐藏占位色块（Player 的 VisualRoot/Sprite），让 AnimatedSprite2D 独占显示
	if _placeholder != null:
		_placeholder.visible = false
	_apply_frames()


## 走停切换入口（PlayerController 调用）：state ∈ {"idle", "walk"}
func play(new_state: String) -> void:
	if new_state == state:
		return
	state = new_state
	_placeholder_dirty = true
	_apply_frames()
	anim_state_changed.emit(state, dir_index)


## 朝向切换（弧度：屏幕空间角度，0=东）
func set_dir_from_angle(screen_angle: float) -> void:
	set_dir(roundi(screen_angle / (PI / 4.0)))


func set_dir(i: int) -> void:
	var idx := wrapi(i, 0, 8)
	if idx == dir_index:
		return
	dir_index = idx
	_apply_frames()
	anim_state_changed.emit(state, dir_index)


# ---------------------------------------------------------------
# 内部
# ---------------------------------------------------------------

func _apply_frames() -> void:
	if frames == null or _anim_sprite == null:
		return
	var anim := "%s_%s" % [state, DIR_NAMES[dir_index]]
	if _anim_sprite.sprite_frames.has_animation(anim):
		_anim_sprite.play(anim)


## 占位色块查找（Player 结构 VisualRoot/Sprite；NPC 无则静默跳过）
func _find_placeholder() -> void:
	var p := get_parent()
	if p == null:
		return
	var vr := p.get_node_or_null("VisualRoot")
	if vr != null:
		_placeholder = vr.get_node_or_null("Sprite")


func _process(delta: float) -> void:
	if frames != null and _anim_sprite != null:
		return  # 真实帧动画由 AnimatedSprite2D 自驱
	if _placeholder == null:
		return
	if state == "walk":
		_t += delta * WALK_FREQ
		var squash := 1.0 + BOB_AMOUNT * sin(_t * TAU)
		_placeholder.scale = Vector2(squash, 2.0 - squash)
		var shade := 1.0 - SHADE_AMOUNT * (0.5 + 0.5 * sin(_t * TAU))
		_placeholder.self_modulate = Color(shade, shade, shade, 1.0)
	elif _placeholder_dirty:
		_placeholder.scale = Vector2.ONE
		_placeholder.self_modulate = Color.WHITE
		_t = 0.0
		_placeholder_dirty = false
