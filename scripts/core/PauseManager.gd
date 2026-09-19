## =============================================================
## 《汇界星痕》T2.3 PauseManager（暂停管理器，Autoload 单例）
## -------------------------------------------------------------
## 架构 §2.7：主页菜单、对话、UI 面板打开时 get_tree().paused = true。
## reason 计数式管理：同 reason 多次 open/close 必须平衡；
## 任一 reason 在计数 → 全局暂停；全部归零 → 恢复运行。
## 消费方：MapUI（T2.3）、T2.5 各面板、T4.x 对话、T3.6 演出。
## =============================================================
extends Node

## reason -> 计数（调试可见：get_active_reasons()）
var _reasons: Dictionary = {}


## 打开 UI/对话时暂停（reason 用于调试配对，如 "map_ui" / "dialogue" / "panel_bag"）
func pause_game(reason: String) -> void:
	_reasons[reason] = int(_reasons.get(reason, 0)) + 1
	get_tree().paused = true
	print("[PauseManager] pause(%s) -> %s" % [reason, str(_reasons.keys())])


## 关闭 UI/对话时恢复；计数归零才真正解除全局暂停
func resume_game(reason: String) -> void:
	if not _reasons.has(reason):
		push_warning("[PauseManager] resume(%s) 无对应暂停原因，忽略（当前：%s）" % [reason, str(_reasons.keys())])
		return
	var n := int(_reasons[reason]) - 1
	if n <= 0:
		_reasons.erase(reason)
	else:
		_reasons[reason] = n
	if _reasons.is_empty():
		get_tree().paused = false
	print("[PauseManager] resume(%s) -> %s" % [reason, str(_reasons.keys())])


func is_paused() -> bool:
	return get_tree().paused


## 调试用：当前未平衡的暂停原因列表
func get_active_reasons() -> Array:
	return _reasons.keys()
