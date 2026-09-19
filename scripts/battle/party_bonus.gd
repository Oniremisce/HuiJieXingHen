extends RefCounted
## =============================================================
## T3.5 PartyBonus 队伍机制（口径：docs/系统规则/战斗系统.md §4 + 推进表 T3.5 卡）
## 判定沿用 Party.team_systems()（T2.2，接口勿改名）；互斥顺序固定：混元→共振→汇流。
## 共振 §4.1：我方各 ≥1 次大招 → 插合击（全体敌人逐个走 T3.4 combo_calc 管线，
##   每敌独立条件增伤 §4.4.3）；计数触发后重置可循环，死亡保留不计 atk 求和；
##   合击不改跑条/充能。汇流 §4.2：大招后 charge=上限×30%（BU.retain 分支）；
##   全队各 ≥1 次后全体拉条 +30：≥100 立即出手（tie-break 序）、已出手无效；
##   拉条出手不连锁新拉条（占位⑤）。混元 §4.3：我方四维 ×1.3（不含暴击/爆伤/充能）。
## 三人小队前提：我方编组 <3 不触发（占位⑦）；待制作人04：⑤连锁 ⑥取整（int 截断）。
## 对外接口（T3.6/T7.1 消费，勿改名，详见交接班表 T3.5 行）：
##   PB.judge(ts) / pb.setup_from_party(party) / pb.setup_systems(arr) / pb.mode
##   pb.apply_battle_start(units) / pb.ult_charge_retain() / pb.on_ult_cast(...)
##   pb.combo_strike(units, force_crit) / pb.run_pull(bm, actor, acted)
##   pb.pull_targets(units, acted, t_now) / PB.arrival_tick(spd)
## =============================================================

const DC := preload("res://scripts/battle/damage_calc.gd")

const HUNYUAN_MULT := 1.3  # 混元四维增幅（§4.3）
const FLOW_RETAIN := 0.3   # 汇流大招后 charge 保留比例（§4.2）
const PULL_AMOUNT := 30    # 汇流拉条量（§4.2）
const BAR_CAP := 100       # 与 SpeedBarSimulator.BAR_CAP 同口径

var mode := ""                  # ""/"混元"/"共振"/"汇流"
var systems: Array = []         # 判定输入快照（编队序）
var ult_count: Dictionary = {}  # 我方 unit_id → 本窗口大招次数（死亡保留；触发后重置）

## 互斥判定（顺序固定：混元→共振→汇流；空编队=无体系）
static func judge(ts: Dictionary) -> String:
	if bool(ts.get("has_all_three", false)):
		return "混元"
	if bool(ts.get("all_same", false)):
		return "共振"
	if (ts.get("systems", []) as Array).size() > 0:
		return "汇流"
	return ""

## 生产入口：消费 Party.team_systems()（接口勿改名）
func setup_from_party(party) -> void:
	setup_ts(party.team_systems())

## 体系输入：按 party_ids 从 dm 读 system（同构 team_systems().systems）
static func systems_from_dm(dm, party_ids: Array) -> Array:
	var arr: Array = []
	for pid in party_ids:
		var d: Variant = dm.get_character(String(pid))
		if d != null:
			arr.append(str(d.system))
	return arr

## 测试注入入口：team_systems() 同构 Dictionary
func setup_ts(ts: Dictionary) -> void:
	systems = (ts.get("systems", []) as Array).duplicate()
	mode = judge(ts)
	print("[BONUS] 体系判定=%s systems=%s（互斥顺序：混元→共振→汇流）" % [
		mode if mode != "" else "无", str(systems)])

## 测试注入入口：systems 数组（内部同构 team_systems 三元组）
func setup_systems(systems_arr: Array) -> void:
	var all_same := systems_arr.size() > 0
	var has_three := systems_arr.size() >= 3
	if all_same:
		for s in systems_arr:
			if s != systems_arr[0]:
				all_same = false
	if has_three:
		for s in ["机律", "秘法", "玄门"]:
			if not s in systems_arr:
				has_three = false
	setup_ts({"systems": systems_arr, "all_same": all_same, "has_all_three": has_three})

## 混元：进战斗我方四维 ×1.3（一次整场；不含暴击/爆伤/充能 §4.3）
func apply_battle_start(units: Array) -> void:
	if mode != "混元":
		return
	for u in units:
		if u.is_ally:
			u.max_hp = int(u.max_hp * HUNYUAN_MULT)
			u.hp = int(u.hp * HUNYUAN_MULT)
			u.atk = int(u.atk * HUNYUAN_MULT)
			u.def = int(u.def * HUNYUAN_MULT)
			u.spd = int(u.spd * HUNYUAN_MULT)
	print("[BONUS] 混元：全队四维 ×%.1f（不含暴击/爆伤/充能）" % HUNYUAN_MULT)

## 大招后 charge 保留比例（BU.consume_ult 消费）：汇流 0.3，其余 0（归零 §3）
func ult_charge_retain() -> float:
	return FLOW_RETAIN if mode == "汇流" else 0.0

## 大招释放登记：返回 "combo"（共振合击）/"pull"（汇流拉条）/""；
## 计数窗口=我方各 ≥1 次（死亡角色计数保留计入满足），触发后重置可循环；
## 三人小队前提：我方编组 <3 不触发（占位⑦，见交接班表——MVP 简化编组冒烟不受体系影响）
func on_ult_cast(units: Array, actor, is_ult: bool) -> String:
	if (mode != "共振" and mode != "汇流") or not is_ult or not actor.is_ally:
		return ""
	var ally_count := 0
	for u in units:
		if u.is_ally:
			ally_count += 1
	if ally_count < 3:
		return ""
	ult_count[actor.id] = int(ult_count.get(actor.id, 0)) + 1
	var all_cast := true
	for u in units:
		if u.is_ally and int(ult_count.get(u.id, 0)) < 1:
			all_cast = false
	if not all_cast:
		return ""
	for u in units:
		if u.is_ally:
			ult_count[u.id] = 0  # 触发后重置，可循环再触发（§4.1/§4.2）
	return "combo" if mode == "共振" else "pull"

## 到达 tick=ceil(100/spd)（轮始置 0 逐 tick 前推，SIM 同口径）
static func arrival_tick(spd: int) -> int:
	return int(ceil(float(BAR_CAP) / maxf(float(spd), 1.0)))

## 汇流拉条达标名单：我方+存活+本轮未出手（已出手无效 §4.2），位置（=spd×当前
## tick，未出手者必 <100）+30 ≥100 达标；排序=spd 降序→我方→编队序（tie-break 口径）
func pull_targets(units: Array, acted: Array, t_now: int) -> Array:
	var hits: Array = []
	for i in units.size():
		var u = units[i]
		if u.is_ally and u.is_alive() and not acted[i]:
			if int(u.spd) * t_now + PULL_AMOUNT >= BAR_CAP:
				hits.append(i)
	hits.sort_custom(func(a, b):
		var ua = units[a]
		var ub = units[b]
		if int(ua.spd) != int(ub.spd):
			return int(ua.spd) > int(ub.spd)
		if bool(ua.is_ally) != bool(ub.is_ally):
			return bool(ua.is_ally)
		return a < b)
	return hits

## 共振合击：全体存活敌人逐个走 T3.4 combo_calc（每敌独立条件增伤 §4.4.3）；
## 不改任何单位跑条位置与充能（§4.1）
func combo_strike(units: Array, force_crit: int) -> void:
	for t in units:
		if t.is_alive() and not t.is_ally:
			var dc: Dictionary = DC.combo_calc(units, 1.0, t, force_crit)
			var dmg := int(dc["damage"])
			t.take_damage(dmg)
			print("[COMBO] 共振合击 → %s 伤害=%d%s | %s" % [
				str(t.name), dmg, "（暴击！）" if bool(dc["crit"]) else "", str(t)])

## 汇流拉条执行：达标者立即出手；调用时点=触发者演出结束后（§4.2）；
## 拉条出手不连锁新拉条（占位⑤）；终态由 BM 调用方收尾检查
func run_pull(bm, actor, acted: Array) -> void:
	var targets := pull_targets(bm.units, acted, arrival_tick(int(actor.spd)))
	if targets.is_empty():
		print("[BONUS] 汇流拉条：无达标单位（+30 后未满 100）")
		return
	var names := PackedStringArray()
	for i in targets:
		names.append(str(bm.units[i].name))
	print("[BONUS] 汇流拉条：达标立即出手=%s" % str(names))
	for i in targets:
		acted[i] = true
		var u = bm.units[i]
		bm.state = bm.State.ACTION
		await bm._on_action_start(u)
		await bm._take_turn(u)
		bm._on_action_end(u)
		bm._check_end()
