## =============================================================
## 《汇界星痕》T2.2 队伍系统（Autoload 单例）
## -------------------------------------------------------------
## 规则唯一依据：docs/系统规则/队伍系统.md（系统策划01 v1 定稿）。
## 数据不变量（规则 §1）：
##   - members 上限 3，有序（插入序即编队序）；
##   - companion_id 空串 = 无同行，且必须 ∈ members（同行不占第 4 席）；
##   - 同行只占编队数据，不生成任何地图实体/跟随者（架构 §1.3）。
## 信号契约（规则 §3）：仅变更 API 返回 true（确有变更）时发一次
##   EventBus.party_changed(party_list)；失败/幂等（false）不发。
## API 返回 bool 语义 =「本次调用是否成功产生了数据变更」。
## 依赖：DataManager（查 characters.csv system 列）、EventBus（发信号），
##   Autoload 注册位置必须在其后（本工程：…→GameState→Party）。
## 下游消费：T3.5 战斗三态判定（team_systems）、T5.2 CompanionManager、队伍 UI。
## =============================================================
extends Node

const DM := preload("res://scripts/core/data_models.gd")

## 编队上限（规则 §1）
const MAX_MEMBERS := 3
## 体系全集 = characters.csv system 列合法值；三系各 ≥1 人即 has_all_three
const ALL_SYSTEMS: Array[String] = ["机律", "秘法", "玄门"]

## 编队角色 id 数组（有序，上限 3；存档序列化项之一，规则 §6 #7）
var members: Array[String] = []
## 同行角色 id（空串 = 无同行；必须 ∈ members；只占编队数据，无地图实体）
var companion_id: String = ""

## 依赖单例用 get_node 引用（不依赖全局 autoload 名，规避 script_check 离线校验误报；
## 本 Autoload 位于 DataManager/EventBus 之后，_ready 时二者已就绪）
@onready var _data_manager: Node = get_node("/root/DataManager")
@onready var _event_bus: Node = get_node("/root/EventBus")

# ---------------------------------------------------------------
# 变更 API（返回 true = 产生变更并发一次 party_changed；false = 拒绝/幂等）
# ---------------------------------------------------------------

## 编入角色：id 合法且不在队、未满员 → 追加至 members 末尾。
## 满员拒绝不替换（规则 §2.1：替换权在 UI 层先 remove 后 add）。
func add_member(id: String) -> bool:
	if _data_manager.get_character(id) == null:
		push_warning("[Party] add_member 拒绝：角色 id 在 characters.csv 不存在（%s）" % id)
		return false
	if id in members:
		push_warning("[Party] add_member 幂等：已在编队（%s）" % id)
		return false
	if members.size() >= MAX_MEMBERS:
		push_warning("[Party] add_member 拒绝：编队已满（%d/%d），不自动替换，请 UI 层先移除再添加" % [members.size(), MAX_MEMBERS])
		return false
	members.append(id)
	_notify_changed()
	return true

## 移出角色；若移除的恰是同行者 → 同步清空 companion_id，仍只发一次信号（规则 §2 / §6 #3）。
func remove_member(id: String) -> bool:
	if not id in members:
		push_warning("[Party] remove_member 幂等：不在编队（%s）" % id)
		return false
	members.erase(id)
	if companion_id == id:
		companion_id = ""
	_notify_changed()
	return true

## 设定同行者：必须 ∈ members（拒绝不隐式入队，规则 §2 / §6 #2）。
func set_companion(id: String) -> bool:
	if not id in members:
		push_warning("[Party] set_companion 拒绝：角色不在编队（%s），不隐式入队" % id)
		return false
	if companion_id == id:
		push_warning("[Party] set_companion 幂等：已是同行者（%s）" % id)
		return false
	companion_id = id
	_notify_changed()
	return true

## 清除同行者；无同行时幂等 false。
func clear_companion() -> bool:
	if companion_id == "":
		push_warning("[Party] clear_companion 幂等：当前无同行者")
		return false
	companion_id = ""
	_notify_changed()
	return true

# ---------------------------------------------------------------
# 查询 API（恒不发信号）
# ---------------------------------------------------------------

func is_full() -> bool:
	return members.size() >= MAX_MEMBERS

func has_member(id: String) -> bool:
	return id in members

## 返回 members 副本，调用方改副本不影响内部数据（规则 §2）。
func get_members() -> Array[String]:
	return members.duplicate()

# ---------------------------------------------------------------
# 体系组合查询（供 T3.5 战斗共振/汇流/混元判定）
# ---------------------------------------------------------------

## team_systems() -> {systems: Array, all_same: bool, has_all_three: bool}
## - systems：members 各角色 system 值（按编队序，可含重复），实时查
##   characters.csv（不缓存副本，CSV 是唯一真相）；
## - all_same：非空且全员同体系（单人队 true，纯数据事实）；
## - has_all_three：机律/秘法/玄门三系各 ≥1 人；
## - 空编队 → {[], false, false}；member 查不到 → 跳过统计并告警（规则 §4）。
func team_systems() -> Dictionary:
	var systems: Array = []
	for id in members:
		var data: DM.CharacterData = _data_manager.get_character(id)
		if data == null:
			push_warning("[Party] team_systems 跳过未知角色（%s）" % id)
			continue
		systems.append(data.system)
	var all_same := systems.size() > 0
	if all_same:
		var first: String = systems[0]
		for s in systems:
			if s != first:
				all_same = false
				break
	var has_all_three := systems.size() >= ALL_SYSTEMS.size()
	if has_all_three:
		for s in ALL_SYSTEMS:
			if not s in systems:
				has_all_three = false
				break
	return {"systems": systems, "all_same": all_same, "has_all_three": has_all_three}

# ---------------------------------------------------------------
# 内部
# ---------------------------------------------------------------

## 变更转发：party_list = members 快照。同行者本就 ∈ members，
## party_list 即 members 原样，不重复计入、不追加第 4 项（规则 §3）。
## 占位 print 为验收证据（任务卡：EventBus 侧验证，占位日志即可），
## 队伍 UI（T2.5）/CompanionManager（T5.2）消费后可移除。
func _notify_changed() -> void:
	var snapshot := get_members()
	print("[Party] party_changed -> %s (companion=%s)" % [str(snapshot), companion_id])
	_event_bus.party_changed.emit(snapshot)
