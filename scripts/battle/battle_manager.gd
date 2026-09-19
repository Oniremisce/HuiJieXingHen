extends RefCounted
## =============================================================
## T3.2b/T3.3 战斗状态机（口径：docs/系统规则/战斗系统.md §2/§3/§8 + 推进表 T3.2/T3.3 卡）
## 消费 T3.2a SpeedBarSimulator + T3.3 BattleUnit/BattleCommand（接口冻结勿动）。
## 回合循环：回合开始 → SIM.simulate_round 取出手序列 → 依次分发出手
## → 全员出手或胜负分出 → 下一轮（模拟器再次调用即全员条位置归 0）。
## 决策：未设 command_provider 时按 ai_pattern=simple（§8）充能满放大招，
## 否则小技能（我方占位与敌人同用）；T3.3 起支持人工指令路径——
## command_provider: Callable，签名 func(unit) -> [BattleCommand.Kind, target 或 null]，
## 指令被拒（校验失败）时降级小技能并日志原因，保证不空过不死锁。
## 充能三途径（§3）在 BattleUnit：激活+10 / 小命中+20 / 受击+15，clamp 100。
## 伤害占位公式 max(1, atk*power-def) 在 BattleCommand.execute——T3.4 替换。
## 演出暂停钩子 _on_action_start/_on_action_end（§2.2）——T3.6 接入。
##
## 对外接口（T3.7 UI / T3.4 / T3.6 消费，勿改名）：
##   const BM := preload("res://scripts/battle/battle_manager.gd")
##   var bm = BM.new(dm, ["awakened_mech_01"], ["corrosion_beast"])
##     dm=DataManager 实例（依赖注入：运行时传 get_node("/root/DataManager")，
##     headless 冒烟用 DMS.new() 后手动 _load_all()）
##   bm.run_to_end(max_rounds := 6) -> String  # "win"/"lose"/"timeout"
##     max_rounds=0 即无轮次上限（制作人02 裁定；"timeout" 仅冒烟安全网用）
##   bm.command_provider = Callable   # 人工指令入口（T3.7 UI 接入点）
##   bm.state（INTRO/RUNNING/ACTION/WIN/LOSE）/ bm.round_num /
##   bm.units（编队序：我方在前；冒烟可在 run 前覆盖 hp 等占位数值）/
##   bm.round_orders（每回合出手序快照，冒烟断言用）
## =============================================================

const SIM := preload("res://scripts/battle/speed_bar_simulator.gd")
const BU := preload("res://scripts/battle/battle_unit.gd")
const BC := preload("res://scripts/battle/battle_command.gd")

enum State { INTRO, RUNNING, ACTION, WIN, LOSE }

var state := State.INTRO
var round_num := 0
var units: Array = []         # BU.BattleUnit，编队序（我方在前）
var round_orders: Array = []  # 每回合出手序快照 Array[Array[int]]
var command_provider: Callable = Callable()  # 人工指令 func(unit) -> [kind, target]
var force_crit := -1  # 暴击强制：-1 随机 / 0 恒不暴 / 1 恒暴（冒烟确定性通道，生产不设）
var _dm: Variant = null

func _init(dm, party_ids: Array, enemy_ids: Array) -> void:
	_dm = dm
	for pid in party_ids:
		units.append(_make_unit(String(pid), true))
	for eid in enemy_ids:
		units.append(_make_unit(String(eid), false))

## BU.new() + setup 两步构造（不用全局 class_name，headless 无缓存可跑）
func _make_unit(uid: String, is_ally: bool):
	var u = BU.new()
	u.setup(_dm, uid, is_ally)
	return u

## 跑完整场（headless/冒烟用）；max_rounds>0 为防死锁安全上限，=0 无上限。
## timeout 仅强制终止不判胜负（语义待制作人裁定），win/lose 为正式终态。
func run_to_end(max_rounds := 6) -> String:
	state = State.RUNNING
	while state == State.RUNNING and (max_rounds <= 0 or round_num < max_rounds):
		round_num += 1
		print("[BATTLE] === 回合 %d 开始（全员条位置归 0）===" % round_num)
		var order: Array = SIM.simulate_round(_sim_entries())
		round_orders.append(order.duplicate())
		print("[BATTLE] R%d 行动序=%s" % [round_num, str(order)])
		for idx in order:
			if state == State.WIN or state == State.LOSE:
				break
			var u = units[idx]
			if not u.is_alive():
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

## 一次出手：激活充能 → 取指令（人工或 simple 自动）→ 执行 → 结构化日志。
func _take_turn(u) -> void:
	u.charge_on_turn_start()  # 自身回合激活开始 +10（§3）
	var cmd: Array = _resolve_command(u)
	var res: Dictionary = BC.execute(units, u, int(cmd[0]), cmd[1], force_crit)
	if not bool(res["ok"]):
		print("[BATTLE] R%d %s 指令被拒（%s），降级小技能" % [round_num, u.name, str(res["reason"])])
		res = BC.execute(units, u, BC.Kind.SKILL, null, force_crit)
	_check_end()
	if not bool(res["ok"]):
		print("[BATTLE] R%d %s 出手失败（%s）" % [round_num, u.name, str(res["reason"])])
		return  # 敌方全灭等无目标场景；胜负面数已结算
	print("[BATTLE] R%d 行动者=%s bar=100 %s[%s power=%.2f] → 目标=%s 伤害=%d%s | %s | %s" % [
		round_num, u.name, str(res["kind"]), str(res["skill"].id),
		float(res["skill"].power), str(res["target"].name), int(res["damage"]),
		"（暴击！）" if bool(res.get("crit", false)) else "",
		str(u), str(res["target"])])

## 指令来源：command_provider 优先（人工路径），否则 ai_pattern=simple 自动。
func _resolve_command(u) -> Array:
	if command_provider.is_valid():
		var c: Variant = command_provider.call(u)
		return [int(c[0]), c[1]]
	var kind: int = BC.Kind.ULT if u.can_use_ult() else BC.Kind.SKILL
	return [kind, null]

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

## 演出暂停钩子（§2.2）：演出期间后台跑条瞬间推进、出手时暂停。
## MVP 空实现占位；T3.6 战斗演出在此插入演出并等待 finished 后继续回合循环。
func _on_action_start(_u) -> void:
	pass

func _on_action_end(_u) -> void:
	pass
