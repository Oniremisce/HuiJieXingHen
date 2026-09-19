## =============================================================
## 《汇界星痕》T2.3 Transition（场景流转层，Autoload · CanvasLayer）
## -------------------------------------------------------------
## 架构 §1.4 / §4.4：全部场景切换统一走本层，黑场淡入淡出 0.4s；
## 传送（神像/任务跳转）同层复用；加载画面 MVP 秒切仅预留。
## 签名（架构 §4.4）：
##   transition_scene(from_path, to_path, duration=0.4)
##   transition_portal(target_id, duration=0.4)
##   transition_fade_out / transition_fade_in（无参，duration 默认 0.4）
## target_id 注册表在 MapSystem（地图数据唯一归属），本层运行时反查。
## 忙标志防并发：进行中的流转忽略新请求并告警。
## =============================================================
extends CanvasLayer

var _busy := false
var _rect: ColorRect


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS  # 暂停中的世界仍可流转（传送前先关面板恢复）
	_rect = ColorRect.new()
	_rect.name = "FadeRect"
	_rect.color = Color.BLACK
	_rect.modulate.a = 0.0
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)
	print("[Transition] ready")


## 同层场景切换：黑场淡出 → change_scene → 淡入
func transition_scene(from_path: String, to_path: String, duration: float = 0.4) -> void:
	if _busy:
		push_warning("[Transition] 忙碌中，忽略 transition_scene(%s)" % to_path)
		return
	var cur := get_tree().current_scene
	if from_path != "" and cur != null and cur.scene_file_path != from_path:
		push_warning("[Transition] from_path 与当前场景不一致（%s != %s），继续执行" % [cur.scene_file_path, from_path])
	_busy = true
	print("[Transition] scene %s -> %s" % [from_path, to_path])
	await _fade_to(1.0, duration)
	get_tree().change_scene_to_file(to_path)
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_to(0.0, duration)
	_busy = false


## 传送：target_id（神像/任务跳转点）→ MapSystem 注册表解析目标场景与落点
func transition_portal(target_id: String, duration: float = 0.4) -> void:
	if _busy:
		push_warning("[Transition] 忙碌中，忽略 transition_portal(%s)" % target_id)
		return
	var ms := get_node_or_null("/root/MapSystem")
	var target: Dictionary = ms.get_portal_target(target_id) if ms != null else {}
	if target.is_empty():
		push_warning("[Transition] transition_portal 未知 target_id：%s（注册表见 MapSystem.PORTALS/SHRINES）" % target_id)
		return
	_busy = true
	print("[Transition] portal %s -> %s" % [target_id, str(target)])
	await _fade_to(1.0, duration)
	get_tree().change_scene_to_file(target.scene)
	await get_tree().process_frame
	await get_tree().process_frame
	# 落点：MVP 用场景默认玩家位；注册表给了 spawn 则覆盖（T2.4 神像旁出生点）
	if target.has("spawn") and target.spawn != null:
		var ps := get_tree().current_scene.find_child("Player", true, false) as Node2D
		if ps != null:
			ps.global_position = target.spawn
	await _fade_to(0.0, duration)
	_busy = false


## 独立淡出/淡入（UI 面板开关效果辅助）；成对调用，期间忙标志阻止并发流转
func transition_fade_out(duration: float = 0.4) -> void:
	if _busy:
		push_warning("[Transition] 忙碌中，忽略 transition_fade_out")
		return
	_busy = true
	await _fade_to(1.0, duration)


func transition_fade_in(duration: float = 0.4) -> void:
	if not _busy:
		push_warning("[Transition] 未处于淡出态，忽略 transition_fade_in")
		return
	await _fade_to(0.0, duration)
	_busy = false


func _fade_to(alpha: float, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(_rect, "modulate:a", alpha, duration)
	await tw.finished
