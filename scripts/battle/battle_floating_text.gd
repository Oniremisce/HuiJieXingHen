extends Node2D
## =============================================================
## T3.10 飘字组件（§8.3）：技能生效时受影响单位头顶向上飘动渐隐 0.8s。
## 占位=色块字 Label（正式样式归美术 T7.3，可换 BitmapFont）。
## 语义色：伤害=白（暴击金）/ 治疗=绿 / 护盾=蓝 / 增伤 amp=黄 "+N%"
## ——本卡只交付组件+damage 触发（battle_arena 连接 BM.damage_dealt）；
## heal/shield/amp 实际触发归 T3.11（TODO 在 battle_command.execute 效果分支）。
## 挂载：battle_arena 根下（世界坐标=单位头顶位置，单位不动不跟随）。
## 回收：FLOAT_TIME 秒后自 queue_free（_process 驱动，headless 冒烟可步进验证）。
## 纯组件：无 class_name（headless --script 无缓存可跑，惯例），BM/arena 经
## preload+new+setup 使用。
## =============================================================

const FLOAT_TIME := 0.8   # 飘字生命周期秒（§8.3 向上飘动渐隐）
const RISE := 36.0        # 上飘距离 px
const FONT_SIZE := 14

var _t := 0.0
var _label: Label = null

## 两步构造：FT.new() → setup(text, color) → add_child（位置由挂载方设定）
func setup(text: String, color: Color) -> void:
	_label = Label.new()
	_label.text = text
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", color)
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_label.position = Vector2(-60, -12)
	_label.size = Vector2(120, 20)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	z_index = 20

## 冒烟/调试入口：当前进度 0~1
func progress() -> float:
	return clampf(_t / FLOAT_TIME, 0.0, 1.0)

func _process(delta: float) -> void:
	if _label == null:
		return
	_t += delta
	var p := clampf(_t / FLOAT_TIME, 0.0, 1.0)
	position.y -= RISE * delta / FLOAT_TIME  # 向上飘动
	modulate.a = 1.0 - p                      # 渐隐
	if _t >= FLOAT_TIME:
		queue_free()  # 回收（生成/回收冒烟断言点）
