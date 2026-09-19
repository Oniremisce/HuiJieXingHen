extends RefCounted
## =============================================================
## T3.2b~T3.5 战斗状态机（口径：战斗系统.md §2/§3/§4/§8 + 推进表 T3.2~T3.5 卡）
## 消费 SIM/BU/BC/DC/PB（均 preload，接口冻结勿动）。
## 回合循环：SIM.simulate_round 取出手序列 → 依次出手 → 大招计数（共振合击插入/
## 汇流拉条立即出手，PartyBonus 驱动）→ 全员出手或胜负分出 → 下一轮（再调用即归 0）。
## 决策：未设 command_provider 时 ai_pattern=simple（§8）；伤害=DC.calc；充能三途径在 BU。
## 演出钩子 _on_action_start/_end + _on_combo_start/_end（§2.2/§4.1 空占位，T3.6 消费）。
## 对外接口（T3.6/T3.7/T7.1 消费，勿改名，详见交接班表 T3.5 行）：
##   const BM := preload("res://scripts/battle/battle_manager.gd")
##   BM.new(dm, party_ids, enemy_ids, bonus_systems := null)  # dm=DataManager 依赖注入；
##     bonus_systems：体系输入 Array（null=按 party_ids 从 dm 读 system，与
##     Party.team_systems().systems 同构；生产 T3.7 亦可 pb.setup_from_party 替换）
##   bm.run_to_end(max_rounds := 6) -> "win"/"lose"/"timeout"（0=无上限）
##   bm.state/round_num/units/round_orders/command_provider/force_crit/bonus
## =============================================================

const SIM := preload("res://scripts/battle/speed_bar_simulator.gd")
const BU := preload("res://scripts/battle/battle_unit.gd")
const BC := preload("res://scripts/battle/battle_command.gd")
const PB := preload("res://scripts/battle/party_bonus.gd")

enum State { INTRO, RUNNING, ACTION, WIN, LOSE }

var state := State.INTRO
var round_num := 0
var units: Array = []         # BU 实例，编队序（我方在前）
var round_orders: Array = []  # 每回合出手序快照 Array[Array[int]]
var command_provider: Callable = Callable()
var force_crit := -1
var bonus = PB.new()          # PartyBonus 实例（T3.5 体系驱动）
var _dm: Variant = null

func _init(dm, party_ids: Array, enemy_ids: Array, bonus_systems = null) -> void:
	_dm = dm
	for pid in party_ids:
		units.append(_make_unit(String(pid), true))
	for eid in enemy_ids:
		units.append(_make_unit(String(eid), false))
	var systems: Array = bonus_systems if bonus_systems != null else _systems_from_dm(party_ids)
	bonus.setup_systems(systems)
	bonus.apply_battle_start(units)  # 混元 ×1.3（进战斗一次 §4.3）
	for u in units:
		if u.is_ally:
			u.ult_charge_retain = bonus.ult_charge_retain()  # 汇流 0.3 / 其余 0

func _make_unit(uid: String, is_ally: bool):
	var u = BU.new()
	u.setup(_dm, uid, is_ally)
	return u

## 体系输入：按 party_ids 从 dm 读 system（与 Party.team_systems().systems 同构；
## Party 实例可用时生产方亦可 pb.setup_from_party(party) 替换，判定同一 judge）
func _systems_from_dm(party_ids: Array) -> Array:
	var arr: Array = []
	for pid in party_ids:
		var d: Variant = _dm.get_character(String(pid))
		if d != null:
			arr.append(str(d.system))
	return arr

## 跑完整场（headless/冒烟用）；max_rounds>0 防死锁上限，=0 无上限（制作人02 裁定③）
func run_to_end(max_rounds := 6) -> String:
	state = State.RUNNING
	while state == State.RUNNING and (max_rounds <= 0 or round_num < max_rounds):
		round_num += 1
		print("[BATTLE] === 回合 %d 开始（全员条位置归 0）===" % round_num)
		var order: Array = SIM.simulate_round(_sim_entries())
		round_orders.append(order.duplicate())
		print("[BATTLE] R%d 行动序=%s" % [round_num, str(order)])
		var acted: Array = []
		for i in units.size():
			acted.append(false)
		for idx in order:
			if state == State.WIN or state == State.LOSE:
				break
			if acted[idx] or not units[idx].is_alive():
				continue  # 本轮已出手（含汇流拉条提前出手）/已死亡 → 跳过
			var u = units[idx]
			state = State.ACTION
			_on_action_start(u)
			var res: Dictionary = _take_turn(u)
			_on_action_end(u)
			acted[idx] = true
			_check_end()
			_after_action(u, res, acted)
		if state == State.ACTION:
			state = State.RUNNING
	if state == State.WIN:
		print("[BATTLE] 终态=WIN（第 %d 轮）" % round_num)
		return "win"
	if state == State.LOSE:
		print("[BATTLE] 终态=LOSE（第 %d 轮）" % round_num)
		return "lose"
	print("[BATTLE] %d 轮上限强制结束（防死锁安全网，未分胜负）" % max_rounds)
	return "timeout"

## 一次出手：激活充能 → 取指令（人工或 simple 自动）→ 执行 → 结构化日志；返回执行结果
func _take_turn(u) -> Dictionary:
	u.charge_on_turn_start()  # 自身回合激活开始 +10（§3）
	var cmd: Array = _resolve_command(u)
	var res: Dictionary = BC.execute(units, u, int(cmd[0]), cmd[1], force_crit)
	if not bool(res["ok"]):
		print("[BATTLE] R%d %s 指令被拒（%s），降级小技能" % [round_num, u.name, str(res["reason"])])
		res = BC.execute(units, u, BC.Kind.SKILL, null, force_crit)
	_check_end()
	if not bool(res["ok"]):
		print("[BATTLE] R%d %s 出手失败（%s）" % [round_num, u.name, str(res["reason"])])
		return res
	print("[BATTLE] R%d 行动者=%s bar=100 %s[%s power=%.2f] → 目标=%s 伤害=%d%s | %s | %s" % [
		round_num, u.name, str(res["kind"]), str(res["skill"].id),
		float(res["skill"].power), str(res["target"].name), int(res["damage"]),
		"（暴击！）" if bool(res.get("crit", false)) else "", str(u), str(res["target"])])
	return res

## 出手后体系触发检查：共振合击插入（不占轮次不改跑条/充能 §4.1）/汇流拉条（§4.2）
func _after_action(u, res: Dictionary, acted: Array) -> void:
	var is_ult := bool(res.get("ok", false)) and str(res.get("kind", "")) == "大招"
	var ev: String = bonus.on_ult_cast(units, u, is_ult)
	if ev == "combo":
		_on_combo_start(u)  # T3.6 合击 CG 钩子占位（演出期间跑条/充能冻结）
		bonus.combo_strike(units, force_crit)
		_on_combo_end(u)
	elif ev == "pull":
		bonus.run_pull(self, u, acted)  # 达标者立即出手（tie-break 序 §4.2）
	_check_end()

func _resolve_command(u) -> Array:
	if command_provider.is_valid():
		var c: Variant = command_provider.call(u)
		return [int(c[0]), c[1]]
	return [BC.Kind.ULT if u.can_use_ult() else BC.Kind.SKILL, null]

func _check_end() -> void:
	var a_alive := false
	var e_alive := false
	for t in units:
		if t.is_alive():
			if t.is_ally:
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
		arr.append({"id": t.id, "spd": t.spd, "is_ally": t.is_ally})
	return arr

## 演出暂停钩子（§2.2/§4.1）：空占位，T3.6 消费——激活/小技能/大招挂 action 钩子，
## 合击 CG 挂 combo 钩子；演出期间跑条暂停、结束后结算拉条等延迟效果
func _on_action_start(_u) -> void:
	pass

func _on_action_end(_u) -> void:
	pass

func _on_combo_start(_u) -> void:
	pass

func _on_combo_end(_u) -> void:
	pass
