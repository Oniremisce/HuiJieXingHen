extends CharacterBody2D
## T1.3 占位玩家控制器：八方向移动 + 障碍碰撞 + 行走呼吸占位动画
## 接口预留：VisualRoot/Sprite 后期替换为 Q 版精灵，本脚本无需改动

const SPEED := 200.0
const WALK_FREQ := 10.0 # 行走呼吸频率
const BOB_AMOUNT := 0.08 # 挤压拉伸幅度
const SHADE_AMOUNT := 0.15 # 明暗呼吸幅度

## 运行时兜底注册输入映射（project.godot 已正式声明，此处理防编辑器未重载设置）
const _KEY_BINDINGS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
}

var _walk_t := 0.0

@onready var _sprite: ColorRect = $VisualRoot/Sprite
@onready var _marker: Polygon2D = $VisualRoot/DirMarker

func _ready() -> void:
	_ensure_input_actions()

func _physics_process(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * SPEED
	move_and_slide()
	_update_facing(dir)
	_update_walk_fx(dir, delta)

## 朝向：DirMarker 默认朝上（-Y），随最后移动方向旋转
func _update_facing(dir: Vector2) -> void:
	if dir != Vector2.ZERO:
		_marker.rotation = dir.angle() + PI / 2.0

## 行走表现占位：Sprite 围绕脚底（pivot）轻微挤压拉伸 + 明暗呼吸，模拟走路
func _update_walk_fx(dir: Vector2, delta: float) -> void:
	if dir == Vector2.ZERO:
		_sprite.scale = Vector2.ONE
		_sprite.self_modulate = Color.WHITE
		_walk_t = 0.0
		return
	_walk_t += delta * WALK_FREQ
	var squash := 1.0 + BOB_AMOUNT * sin(_walk_t * TAU)
	_sprite.scale = Vector2(squash, 2.0 - squash)
	var shade := 1.0 - SHADE_AMOUNT * (0.5 + 0.5 * sin(_walk_t * TAU))
	_sprite.self_modulate = Color(shade, shade, shade, 1.0)

func _ensure_input_actions() -> void:
	for action: String in _KEY_BINDINGS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: Key in _KEY_BINDINGS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
