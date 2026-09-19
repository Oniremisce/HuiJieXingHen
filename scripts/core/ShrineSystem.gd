## =============================================================
## 《汇界星痕》T2.4 ShrineSystem（神像系统，Autoload 单例）
## -------------------------------------------------------------
## 架构 §2.2：神像点亮状态唯一真相（接管 T2.3「lit 暂以区块解锁态代替」
## 的过渡实现，消除双真相；MapSystem.is_shrine_lit 转发至此）。
## 数据表 MVP 硬编码 1 座（id 与 MapSystem.SHRINES 对齐，后续可 CSV 化）；
## lit_shrines 为存档序列化项（SaveManager 读档经 deserialize 回填）。
## 依赖：EventBus。Autoload 顺序：…→MapSystem→ShrineSystem→SaveManager。
## =============================================================
extends Node

## 神像数据表（lit 真值归本单例；位置/箱庭图标点位仍归 MapSystem.SHRINES）
const SHRINES := {
	"camp_shrine_01": {
		"name": "营地星痕神像", "region": "region_camp",
		"scene": "res://scenes/map/CampMap.tscn",
	},
}

## 已点亮神像列表（存档序列化项，本单例唯一真相）
var lit_shrines: Array[String] = []


func is_shrine_lit(shrine_id: String) -> bool:
	return shrine_id in lit_shrines


## 点亮（幂等）：首次点亮返回 true 并广播 EventBus.shrine_lit；
## 已点亮返回 false 不重复广播（首亮奖励/自动存档由 Shrine 交互流处理，
## 不挂此信号，故重复触发不会重复奖励）
func light_shrine(shrine_id: String) -> bool:
	if is_shrine_lit(shrine_id):
		return false
	lit_shrines.append(shrine_id)
	print("[ShrineSystem] shrine_lit -> %s" % shrine_id)
	get_node("/root/EventBus").shrine_lit.emit(shrine_id)
	return true


## 点亮列表副本（SaveManager 序列化用）
func get_lit_shrines() -> Array:
	return lit_shrines.duplicate()


## 读档回填：直接写状态；新增项逐个补发 shrine_lit（场景内 Shrine 实体
## 监听此信号刷新亮态视觉——读档后无需重进场景即可看到点亮态）
func deserialize(arr: Variant) -> void:
	if not (arr is Array):
		push_warning("[ShrineSystem] deserialize 参数非数组，忽略：%s" % str(arr))
		return
	for id: Variant in arr:
		var sid := str(id)
		if not SHRINES.has(sid):
			push_warning("[ShrineSystem] deserialize 未知神像：%s（跳过）" % sid)
			continue
		if sid in lit_shrines:
			continue
		lit_shrines.append(sid)
		print("[ShrineSystem] deserialize 回填点亮：%s" % sid)
		get_node("/root/EventBus").shrine_lit.emit(sid)


## 光环恢复（MVP：HP/星缘满 + 状态重置为占位实现——角色 HP/状态模型由
## T3.x 战斗系统落地后在此扩展；本卡以日志 + 飘字为验收证据）
func restore_all() -> void:
	var party: Array = get_node("/root/Party").get_members()
	if party.is_empty():
		print("[ShrineSystem] restore_all：空编队，无恢复对象")
		return
	for id: String in party:
		print("[ShrineSystem] restore %s -> HP/星缘满、状态重置（MVP 占位，HP 模型 T3.x 接入）" % id)
