extends RefCounted
## =============================================================
## T3.2b 战斗状态机（口径：docs/系统规则/战斗系统.md §2/§3/§8 + 推进表 T3.2 卡）
## 消费 T3.2a SpeedBarSimulator（接口冻结勿动）。
## 回合循环：回合开始 → SIM.simulate_round 取出手序列 → 依次分发出手
## → 全员出手或胜负分出 → 下一轮（模拟器再次调用即全员条位置归 0）。
## 决策 ai_pattern=simple（§8）：充能满用大招后归零，否则小技能；
## MVP 1v1 占位我方同用此自动决策，T3.3 指令系统接入后改人工指令。
## 充能（§3）：自身回合激活开始+10 / 小技能命中+20 / 受到伤害+15，
## 上限 charge_max=100；大招释放后充能归零。
## 伤害占位公式 max(1, atk*power-def)（int 截断）——T3.4 替换正式 DamageCalc；
## SkillData.power 为 float 倍率制；SkillData 无 energy_cost 字段（T2.8 已删，勿读）。
##
## 对外接口（T3.3/T3.4/T3.6 消费，勿改名）：
##   const BM := preload("res://scripts/battle/battle_manager.gd")
##   var bm = BM.new(dm, ["awakened_mech_01"], ["corrosion_beast"])
##     dm=DataManager 实例（依赖注入：运行时传 get_node("/root/DataManager")，
##     headless 冒烟用 DMS.new() 后手动 _load_all()）
##   bm.run_to_end(max_rounds := 6) -> String  # "win" / "lose" / "timeout"
##   bm.state（INTRO/RUNNING/ACTION/WIN/LOSE）/ bm.round_num /
##   bm.units（编队序：我方在前；冒烟可在 run 前直接覆盖 hp 等占位数值）/
##   bm.round_orders（每回合出手序快照，冒烟断言用）
##   演出暂停钩子 _on_action_start/_on_action_end（§2.2）：空实现占位，T3.6 消费。
## 内部 class BattleUnit 为占位结构，T3.3 抽出为正式 BattleUnit.gd。
## =============================================================

const DM := preload("res://scripts/core/data_models.gd")
const SIM := preload("res://scripts/battle/speed_bar_simulator.gd")

enum State { INTRO, RUNNING, ACTION, WIN, LOSE }

const CHARGE_ACTIVE := 10     # 自身回合激活开始（§3）
const CHARGE_SMALL_HIT := 20  # 小技能命中（§3）
const CHARGE_DAMAGED := 15    # 受到伤害（§3）

## 内部占位单位（T3.3 抽出为 BattleUnit.gd：指令/目标选择/charge_free）
class BattleUnit extends RefCounted:
	var id := ""
	var name := ""
	var is_ally := true
	var hp := 0
	var max_hp := 0
	var atk := 0
	var def := 0
	var spd := 0
	var charge := 0
	var charge_max := 100
	var skill_small: Variant = null  # DM.SkillData
	var skill_ult: Variant = null    # DM.SkillData
	var alive := true
	func _to_string() -> String:
		return "%s(hp=%d/%d atk=%d def=%d spd=%d charge=%d/%d)" % [
			name, hp, max_hp, atk, def, spd, charge, charge_max]

var state := State.INTRO
var round_num := 0
var units: Array = []         # BattleUnit，编队序（我方在前）
var round_orders: Array = []  # 每回合出手序快照 Array[Array[int]]
var _dm: Variant = null

func _init(dm, party_ids: Array, enemy_ids: Array) -> void:
	_dm = dm
	for pid in party_ids:
		units.append(_make_unit(String(pid), true))
	for eid in enemy_ids:
		units.append(_make_unit(String(eid), false))

func _make_unit(uid: String, is_ally: bool) -> BattleUnit:
	var d: Variant = _dm.get_character(uid) if is_ally else _dm.get_enemy(uid)
	var u := BattleUnit.new()
	u.id = uid
	u.name = str(d.name)
	u.is_ally = is_ally
	u.max_hp = int(d.hp)
	u.hp = u.max_hp
	u.atk = int(d.atk)
	u.def = int(d.def)
	u.spd = int(d.spd)
	u.skill_small = _dm.get_skill(str(d.skill_small))
	u.skill_ult = _dm.get_skill(str(d.skill_ult))
	return u

## 跑完整场（headless/冒烟用）；max_rounds 为防死锁安全上限。
## timeout 仅强制终止不判胜负（语义待制作人裁定），win/lose 为正式终态。
func run_to_end(max_rounds := 6) -> String:
	state = State.RUNNING
	while state == State.RUNNING and round_num < max_rounds:
		round_num += 1
		print("[BATTLE] === 回合 %d 开始（全员条位置归 0）===" % round_num)
		var order: Array = SIM.simulate_round(_sim_entries())
		round_orders.append(order.duplicate())
		print("[BATTLE] R%d 行动序=%s" % [round_num, str(order)])
		for idx in order:
			if state == State.WIN or state == State.LOSE:
				break
			var u: BattleUnit = units[idx]
			if not u.alive:
				continue  # 本轮内已被打死（如大招击杀）则跳过其出手
			state = State.ACTION
			_on_action_start(u)  # 演出钩子占位（T3.6）
			_take_turn(u)
			_on_action_end(u)    # 演出钩子占位（T3.6）
			_check_end()
		if state == State.ACTION:
			state = State.RUNNING  # 本轮全员出手完；下轮 SIM 再次调用即全员归 0
	if state == State.WIN:
		print("[BATTLE] 终态=WIN（第 %d 轮）" % round_num)
		return "win"
	if state == State.LOSE:
		print("[BATTLE] 终态=LOSE（第 %d 轮）" % round_num)
		return "lose"
	print("[BATTLE] %d 轮上限强制结束（防死锁安全网，未分胜负）" % max_rounds)
	return "timeout"

## 一次出手：激活充能 → 决策 → 结算伤害与充能 → 结构化日志。
func _take_turn(u: BattleUnit) -> void:
	u.charge = mini(u.charge + CHARGE_ACTIVE, u.charge_max)  # 激活开始 +10
	var target := _first_alive_enemy_of(u)
	if target == null:
		return  # 对方全灭（胜负面数接手）
	var use_ult := u.charge >= u.charge_max  # ai_pattern=simple：满则大招
	var skill: Variant = u.skill_ult if use_ult else u.skill_small
	# 占位伤害公式（T3.4 替换 DamageCalc）
	var dmg := int(max(1.0, float(u.atk) * float(skill.power) - float(target.def)))
	target.hp = maxi(target.hp - dmg, 0)
	target.alive = target.hp > 0
	if use_ult:
		u.charge = 0  # 大招释放后充能归零（§3）
	else:
		u.charge = mini(u.charge + CHARGE_SMALL_HIT, u.charge_max)  # 小技能命中 +20
	target.charge = mini(target.charge + CHARGE_DAMAGED, target.charge_max)  # 受伤 +15
	print("[BATTLE] R%d 行动者=%s bar=100 %s[%s power=%.2f] → 目标=%s 伤害=%d | %s | %s" % [
		round_num, u.name, "大招" if use_ult else "小技能", skill.id,
		float(skill.power), target.name, dmg, u, target])

func _first_alive_enemy_of(u: BattleUnit) -> BattleUnit:
	for t in units:
		var tu: BattleUnit = t
		if tu.alive and tu.is_ally != u.is_ally:
			return tu
	return null

func _check_end() -> void:
	var a_alive := false
	var e_alive := false
	for t in units:
		var tu: BattleUnit = t
		if tu.alive:
			if tu.is_ally:
				a_alive = true
			else:
				e_alive = true
	if not e_alive:
		state = State.WIN
	elif not a_alive:
		state = State.LOSE

func _sim_entries() -> Array:
	var arr: Array = []
	for t in units:
		var tu: BattleUnit = t
		arr.append({"id": tu.id, "spd": tu.spd, "is_ally": tu.is_ally})
	return arr

## 演出暂停钩子（§2.2）：演出期间后台跑条瞬间推进、出手时暂停。
## MVP 空实现占位；T3.6 战斗演出在此插入演出并等待 finished 后继续回合循环。
func _on_action_start(_u: BattleUnit) -> void:
	pass

func _on_action_end(_u: BattleUnit) -> void:
	pass
