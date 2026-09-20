extends SceneTree
## =============================================================
## T3.5 PartyBonus 三编组冒烟（headless：先设 GODOT_MCP_RUNTIME_PORT='abc'
## 再 godot --headless --path . --script res://tools/smoke_test_party_bonus.gd）
## 手算预计算（force_crit=0 确定性；数值全部 CSV；混元 ×1.3 取 int 截断=占位⑥）：
## 用例A 混元（真实 Party.team_systems 消费 + 注入开战）：mech 100/12/10/10
##   → ×1.3 → hp130/atk15(15.6 截断)/def13/spd13；小技能 max(1,15×1.2-6)=12
## 用例B 共振（注入全科技；CSV 三角色三系各一无同系编组，见交接班表）：
##   3v1 兽 hp=1000（T2.9 新数值需要更高 hp 才能扛住三 ULT+合击）、三人 charge 覆写 100 → R1 order=[1,0,2,3]（spd12/10/9/8
##   → tick9/10/12/13）：arcane ULT444→556、mech ULT30→526、xian ULT26→500、
##   计数满合击 500-34=(12+15+13)×100%-6 → 兽 466 → timeout（合击不占轮次/不改充能）；
##   计数重置可循环直测：3 次 ULT→combo→重置→再 3 次→再 combo
## 用例C 汇流：C1 真实两系（bonus_systems=null → dm 读 system）2v1 兽 hp999、
##   双 ULT（31/24）→ charge=上限×30%=30（retain 分支）→ 全队齐触发拉条但
##   无未出手我方 → 无达标；C2 直调 run_pull：acted=[F,T,T]、t_now=arrival(12)=9、
##   mech pos=10×9=90+30=120 达标 → 立即出手 ULT24→charge=30；已出手不重复出手；
##   C3 pull_targets 排序：spd 11/10/9 → [1,0,2]（tie-break 口径 §4.2）
## =============================================================

const DMS := preload("res://scripts/core/DataManager.gd")
const PRTY := preload("res://scripts/core/Party.gd")
const BM := preload("res://scripts/battle/battle_manager.gd")
const BC := preload("res://scripts/battle/battle_command.gd")
const BU := preload("res://scripts/battle/battle_unit.gd")
const PB := preload("res://scripts/battle/party_bonus.gd")

var _failed := false
var _n := 0

func _init() -> void:
	_run.call_deferred()  # T3.6 起 run_to_end/run_pull 为 coroutine：主循环帧驱动

func _run() -> void:
	var dm = DMS.new()
	dm._load_all()  # headless --script 手动同步加载
	print("=== T3.5 队伍机制冒烟开始 ===")
	await _case_hunyuan(dm)
	await _case_resonance(dm)
	await _case_confluence(dm)
	if _failed:
		print("=== T3.5 冒烟结束：存在失败项 ===")
		quit(1)
	else:
		print("=== T3.5 冒烟结束：全部通过 ===")
		quit(0)

func _case_hunyuan(dm) -> void:
	var party = PRTY.new()
	party._data_manager = dm  # headless 无 autoload 树，手动注入（@onready 不跑）
	for id in ["awakened_mech_01", "awakened_arcane_01", "awakened_xian_01"]:
		party.members.append(id)
	var pb = PB.new()
	pb.setup_from_party(party)  # 生产入口：消费 Party.team_systems()（接口勿改名）
	_check(pb.mode == "混元")
	var bm = BM.new(dm, ["awakened_mech_01"], ["corrosion_beast"], ["科技", "魔法", "仙道"])
	bm.force_crit = 0
	print("[SMOKE] 用例A: mode=%s mech=%s" % [str(bm.bonus.mode), str(bm.units[0])])
	_check(bm.bonus.mode == "混元")
	_check(bm.units[0].hp == 130 and bm.units[0].atk == 15 and bm.units[0].def == 13 and bm.units[0].spd == 13)
	var r1: Dictionary = BC.execute(bm.units, bm.units[0], BC.Kind.SKILL, null, 0)
	_check(int(r1["damage"]) == 24)  # T2.9 新 mech_s1 power=2.0 → 混元 atk15×2.0-def6=24

func _case_resonance(dm) -> void:
	var bm = BM.new(dm, ["awakened_mech_01", "awakened_arcane_01", "awakened_xian_01"], ["corrosion_beast"], ["科技", "科技", "科技"])
	bm.force_crit = 0
	bm.units[3].max_hp = 1000  # T2.9 新 power 整体上调，增 hp 保持 timeout 测试意图
	bm.units[3].hp = 1000
	for i in [0, 1, 2]:
		bm.units[i].charge = 100
	var result: String = await bm.run_to_end(1)  # 1 轮窗口：锁合击数值
	print("[SMOKE] 用例B: result=%s rounds=%d orders=%s | 兽=%s" % [
		result, bm.round_num, str(bm.round_orders), str(bm.units[3])])
	_check(result == "timeout" and bm.round_num == 1)  # T2.9：增 hp 后回到 timeout
	_check(str(bm.round_orders) == "[[1, 0, 2, 3]]")
	_check(bm.units[3].hp == 466)  # T2.9 新数值：1000-444-30-26-34=466
	_check(bm.units[2].charge == 0)  # 共振 retain=0：ULT 后归零，合击不改充能
	var pb = PB.new()
	pb.setup_systems(["科技", "科技", "科技"])
	var us: Array = []
	for pid in ["awakened_mech_01", "awakened_arcane_01", "awakened_xian_01"]:
		var u = BU.new()
		u.setup(dm, pid, true)
		us.append(u)
	var e1: String = pb.on_ult_cast(us, us[0], true)
	var e2: String = pb.on_ult_cast(us, us[1], true)
	var e3: String = pb.on_ult_cast(us, us[2], true)
	var e4: String = pb.on_ult_cast(us, us[0], true)
	var e5: String = pb.on_ult_cast(us, us[1], true)
	var e6: String = pb.on_ult_cast(us, us[2], true)
	print("[SMOKE] 用例B 计数循环: %s/%s/%s → 重置 → %s/%s/%s" % [e1, e2, e3, e4, e5, e6])
	_check(e1 == "" and e2 == "" and e3 == "combo" and e4 == "" and e5 == "" and e6 == "combo")

func _case_confluence(dm) -> void:
	# C1 真实两系混编（3v1 注入 ["科技","魔法","科技"]）：三人 charge=100 →
	# R1 三 ULT（arcane9/mech10/xian12 tick 先于兽13）→ 81 伤 → 计数满自动拉条
	# （无未出手我方 → 无达标）→ charge=上限×30%=30×3
	var bm = BM.new(dm, ["awakened_mech_01", "awakened_arcane_01", "awakened_xian_01"], ["corrosion_beast"], ["科技", "魔法", "科技"])
	bm.force_crit = 0
	print("[SMOKE] 用例C1: mode=%s systems=%s" % [str(bm.bonus.mode), str(bm.bonus.systems)])
	_check(bm.bonus.mode == "汇流" and bm.bonus.systems == ["科技", "魔法", "科技"])
	bm.units[3].max_hp = 999
	bm.units[3].hp = 999
	for i in [0, 1, 2]:
		bm.units[i].charge = 100
	var result: String = await bm.run_to_end(1)
	print("[SMOKE] 用例C1: result=%s rounds=%d orders=%s | 兽=%s" % [
		result, bm.round_num, str(bm.round_orders), str(bm.units[3])])
	_check(result == "timeout" and str(bm.round_orders) == "[[1, 0, 2, 3]]")
	_check(bm.units[0].charge == 45 and bm.units[1].charge == 30 and bm.units[2].charge == 30)  # retain=30%；mech 被兽小技能命中受击+15→45
	_check(bm.units[3].hp == 499)  # T2.9 新数值：999-(444+30+26)
	# C2 run_pull 直调：达标者立即出手（ULT→retain30）、已出手单位无效（§4.2）
	var bm2 = BM.new(dm, ["awakened_mech_01", "awakened_arcane_01", "awakened_xian_01"], ["corrosion_beast"], ["科技", "魔法", "科技"])
	bm2.force_crit = 0
	bm2.units[3].max_hp = 999
	bm2.units[3].hp = 999
	bm2.units[0].charge = 100
	var acted: Array = [false, true, true, false]  # arcane/xian 本轮已出手
	await bm2.bonus.run_pull(bm2, bm2.units[1], acted)  # arcane 触发（t_now=arrival(12)=9）
	print("[SMOKE] 用例C2: acted=%s mech=%s 兽=%s" % [str(acted), str(bm2.units[0]), str(bm2.units[3])])
	_check(bool(acted[0]) and bm2.units[0].charge == 30)  # 拉条出手 ULT→retain30
	_check(bm2.units[3].hp == 969)  # T2.9 新：999-30（仅 mech ULT=30；arcane/xian 已出手不重复出手）
	# C3 pull_targets 排序（tie-break：spd 降序→我方→编队序）
	bm2.units[1].spd = 11
	var hits: Array = bm2.bonus.pull_targets(bm2.units, [false, false, false], 9)
	print("[SMOKE] 用例C3: hits=%s（spd 11/10/9 降序，pos 99/90/81 全达标）" % str(hits))
	_check(str(hits) == "[1, 0, 2]")

func _check(cond: bool) -> void:
	_n += 1
	if not cond:
		_failed = true
		print("[SmokeTest] 第 %d 个断言失败" % _n)
		push_error("[SmokeTest] 断言失败")
