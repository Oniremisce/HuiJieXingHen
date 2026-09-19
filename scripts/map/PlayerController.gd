extends CharacterBody2D
## T1.3 占位玩家控制器：八方向移动 + 障碍碰撞
## T2.3：走停/朝向的视觉表现改走 CharacterAnimator 八向动画接口；
##       运行时自动安装 CharacterAnimator + OcclusionOutline（视觉挂点，.tscn 零改动）。
## 接口预留：VisualRoot/Sprite 后期替换为 Q 版精灵，本脚本无需改动

const SPEED := 200.0

## 运行时兜底注册输入映射（project.godot 已正式声明，此处理防编辑器未重载设置）
const _KEY_BINDINGS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
}

const _CharacterAnimator := preload("res://scripts/map/CharacterAnimator.gd")
const _OcclusionOutline := preload("res://scripts/map/OcclusionOutline.gd")

## 八向动画接口（占位阶段驱动色块；T2.6 接帧条后零改动）
var animator: Node = null

@onready var _marker: Polygon2D = $VisualRoot/DirMarker

func _ready() -> void:
	_ensure_input_actions()
	_ensure_visual_helpers()

func _physics_process(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * SPEED
	move_and_slide()
	_update_facing(dir)
	_update_move_state(dir)

## 朝向：DirMarker 默认朝上（-Y），随最后移动方向旋转
func _update_facing(dir: Vector2) -> void:
	if dir != Vector2.ZERO:
		_marker.rotation = dir.angle() + PI / 2.0

## 走停切换统一走八向动画接口（T2.3；占位表现由 CharacterAnimator 驱动）
func _update_move_state(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		animator.play("idle")
	else:
		animator.set_dir_from_angle(dir.angle())
		animator.play("walk")

func _ensure_input_actions() -> void:
	for action: String in _KEY_BINDINGS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: Key in _KEY_BINDINGS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)

## T2.3 视觉挂点：八向动画接口 + 遮挡描边（幂等，运行时安装）
func _ensure_visual_helpers() -> void:
	if not has_node("CharacterAnimator"):
		animator = _CharacterAnimator.new()
		animator.name = "CharacterAnimator"
		add_child(animator)
	else:
		animator = get_node("CharacterAnimator")
	if not has_node("OcclusionOutline"):
		var ol := _OcclusionOutline.new()
		ol.name = "OcclusionOutline"
		add_child(ol)
