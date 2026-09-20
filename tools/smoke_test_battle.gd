extends SceneTree
## =============================================================
## T3.2/T3.3 战斗常驻冒烟回归（headless：先设 GODOT_MCP_RUNTIME_PORT='abc'
## 防注册表污染，再 godot --headless --path . --script res://tools/smoke_test_battle.gd）
## 出手序复算：mech spd10 / 兽 spd8 → tick=ceil(100/spd)=10/13 → 每轮 [0,1]。
## 伤害=int(max(1,atk*power-def))：mech 小8.4→8/大24；兽小1/大8。
## 充能（§3）激活+10/小命中+20/受击+15 clamp100，满放大招归零。
## 用例一（占位覆盖兽 max_hp=40）：R1/2 互小技能 → R3 mech c100 大招24 → WIN
##   （终值 mech hp98 charge0、兽 hp0、orders=[[0,1]]×3）
## 用例二（反转占位血量 mech max_hp=12）：R3 双大招（mech c100 大24 / 兽受击
##   充能加速 c100 大8）→ R5 兽小1 → LOSE（终值 兽 hp94、orders×5）
## 用例三（兽 max_hp=999）：受击充能加速 6 轮总伤 mech80/兽20 → timeout
##   无死锁（终值 mech hp80/兽 hp919、orders×6、双方 alive）
## 用例四：validate 未满禁用返回原因/满可用/charge_free 豁免；execute 大招
##   归零 dmg24；三途径 10+20+15→charge45 hp95、clamp100
## 用例五（1v2 兽A hp8）：execute 缺省自动选兽A 打死；指定已死兽A → 自动
##   改选兽B（hp142）+ 小命中+20×2 → charge40
## 用例六（1v2 双兽 hp8 + command_provider 注入 SKILL）：R1 mech 杀兽A/兽B
##   反1 → R2 杀兽B → WIN R2（死亡目标跳过+敌方全灭进 win 实证）
## 暴击确定性（T3.4）：DamageCalc 引入随机暴击后，回归用例一律 bm.force_crit=0
## （恒不暴，数值与 T3.3 无暴击占位公式完全一致）；手算验算见 smoke_test_damage_calc.gd
## =============================================================

const DMS := preload("res://scripts/core/DataManager.gd")
const BM := preload("res://scripts/battle/battle_manager.gd")
const BC := preload("res://scripts/battle/battle_command.gd")

var _failed := false

func _init() -> void:
	_run.call_deferred()  # T3.6 起 run_to_end 为 coroutine：call_deferred 绕过静态检查，主循环帧驱动

func _run() -> void:
	var dm = DMS.new()
	dm._load_all()  # headless --script 不触发 autoload _ready，需手动同步加载
	print("=== T3.2/T3.3 战斗冒烟开始 ===")
	await _case_win(dm)
	await _case_lose(dm)
	await _case_timeout(dm)
	await _case_command_charge(dm)
	await _case_dead_target(dm)
	await _case_wipeout_win(dm)
	if _failed:
		print("=== 战斗冒烟结束：存在失败项 ===")
		quit(1)
	else:
		print("=== 战斗冒烟结束：全部通过 ===")
		quit(0)

func _case_win(dm) -> void:
	var bm = BM.new(dm, ["awakened_mech_01"], ["corrosion_beast"])
	bm.force_crit = 0  # T3.4 暴击确定性：回归恒不暴（数值=T3.3 无暴击轨迹）
	bm.units[1].max_hp = 40  # 占位削弱兽血量：保证占位伤害 6 轮内分胜负（不改 CSV）
	bm.units[1].hp = 40
	var result: String = await bm.run_to_end(6)
	print("[SMOKE] 用例一: result=%s rounds=%d orders=%s | %s | %s" % [
		result, bm.round_num, str(bm.round_orders), str(bm.units[0]), str(bm.units[1])])
	_check(result == "win" and bm.round_num == 3)
	_check(str(bm.round_orders) == "[[0, 1], [0, 1], [0, 1]]")
	_check(bm.units[0].hp == 98 and bm.units[0].charge == 0)  # R3 大招后归零
	_check(bm.units[1].hp == 0 and bm.units[1].is_alive() == false)

func _case_lose(dm) -> void:
	var bm = BM.new(dm, ["awakened_mech_01"], ["corrosion_beast"])
	bm.force_crit = 0
	bm.units[0].max_hp = 12  # 反转占位血量：我方 6 轮内被打空 → lose
	bm.units[0].hp = 12
	var result: String = await bm.run_to_end(6)
	print("[SMOKE] 用例二: result=%s rounds=%d orders=%s | %s | %s" % [
		result, bm.round_num, str(bm.round_orders), str(bm.units[0]), str(bm.units[1])])
	_check(result == "lose" and bm.round_num == 5)
	_check(str(bm.round_orders) == "[[0, 1], [0, 1], [0, 1], [0, 1], [0, 1]]")
	_check(bm.units[0].hp == 0 and bm.units[0].is_alive() == false)
	_check(bm.units[1].hp == 48)  # T2.9 新数值：mech s1=18/ult=30，兽 s1=1/ult=8

func _case_timeout(dm) -> void:
	var bm = BM.new(dm, ["awakened_mech_01"], ["corrosion_beast"])
	bm.force_crit = 0
	bm.units[1].max_hp = 999  # 占位高血量：6 轮内双方均无法击破 → 触发轮数上限
	bm.units[1].hp = 999
	var result: String = await bm.run_to_end(6)
	print("[SMOKE] 用例三: result=%s rounds=%d orders=%s | %s | %s" % [
		result, bm.round_num, str(bm.round_orders), str(bm.units[0]), str(bm.units[1])])
	_check(result == "timeout")  # 6 轮上限强制结束，无死锁（胜负语义待制作人裁定）
	_check(bm.round_num == 6 and bm.units[0].is_alive() and bm.units[1].is_alive())
	var bm0 = BM.new(dm, ["awakened_mech_01"], ["corrosion_beast"])  # 用例三b：max_rounds=0=无上限
	bm0.force_crit = 0  # T3.10 补：此前未设随机暴击通道（flaky，10% 暴击会提前 R2 win）
	bm0.units[1].max_hp = 40
	bm0.units[1].hp = 40
	var r0: String = await bm0.run_to_end(0)
	_check(r0 == "win" and bm0.round_num == 3)  # 0 若被误当 0 轮上限会 timeout

func _case_command_charge(dm) -> void:  # 用例四：指令校验+大招归零+充能三途径
	var bm = BM.new(dm, ["awakened_mech_01"], ["corrosion_beast"])
	var u = bm.units[0]
	print("[SMOKE] 用例四: 未满校验=\"%s\"" % str(BC.validate(u, BC.Kind.ULT)))
	_check(BC.validate(u, BC.Kind.ULT) != "" and BC.validate(u, BC.Kind.SKILL) == "")
	u.charge = 100
	_check(BC.validate(u, BC.Kind.ULT) == "")  # 充满可释放
	var res: Dictionary = BC.execute(bm.units, u, BC.Kind.ULT, null, 0)
	print("[SMOKE] 用例四: 大招 dmg=%d charge_after=%d" % [int(res["damage"]), int(u.charge)])
	_check(bool(res["ok"]) and int(u.charge) == 0 and int(res["damage"]) == 30)  # T2.9 新 power=3.0
	u.charge_free = true  # 机制预留（§3）：charge_free 豁免充能校验
	_check(BC.validate(u, BC.Kind.ULT) == "" and bool(BC.execute(bm.units, u, BC.Kind.ULT, null, 0)["ok"]))
	u.charge_free = false
	u.charge = 0
	u.charge_on_turn_start()
	u.charge_on_small_hit()
	u.take_damage(5)
	print("[SMOKE] 用例四: 三途径 激活+10/小命中+20/受击+15 → charge=%d hp=%d" % [int(u.charge), int(u.hp)])
	_check(int(u.charge) == 45 and int(u.hp) == 95)
	u.charge = 100
	u.charge_on_turn_start()
	_check(int(u.charge) == 100)  # clamp 到 charge_max

func _case_dead_target(dm) -> void:  # 用例五：死亡目标跳过 → 自动改选存活者
	var bm = BM.new(dm, ["awakened_mech_01"], ["corrosion_beast", "corrosion_beast"])
	bm.units[1].max_hp = 8  # 兽A 占位秒杀血量
	bm.units[1].hp = 8
	var r1: Dictionary = BC.execute(bm.units, bm.units[0], BC.Kind.SKILL, null, 0)  # 缺省自动选首个存活=兽A
	var r2: Dictionary = BC.execute(bm.units, bm.units[0], BC.Kind.SKILL, bm.units[1], 0)  # 指定已死兽A
	print("[SMOKE] 用例五: r1.target_hp=%d r2.target_hp=%d charge=%d" % [
		int(r1["target_hp"]), int(r2["target_hp"]), int(bm.units[0].charge)])
	_check(bool(r1["ok"]) and bm.units[1].is_alive() == false)
	_check(bool(r2["ok"]) and r2["target"] == bm.units[2] and int(bm.units[2].hp) == 132)  # T2.9 新 power=2.0 伤害=18
	_check(int(bm.units[0].charge) == 40)  # 小命中 +20 ×2

func _case_wipeout_win(dm) -> void:  # 用例六：人工指令路径 + 敌方全灭进 win
	var bm = BM.new(dm, ["awakened_mech_01"], ["corrosion_beast", "corrosion_beast"])
	for i in [1, 2]:
		bm.units[i].max_hp = 8
		bm.units[i].hp = 8
	bm.command_provider = func(unit): return [BC.Kind.SKILL, null]  # 人工指令注入（T3.7 UI 接入点）
	bm.force_crit = 0
	var result: String = await bm.run_to_end(6)
	print("[SMOKE] 用例六: result=%s rounds=%d orders=%s" % [result, bm.round_num, str(bm.round_orders)])
	_check(result == "win" and bm.round_num == 2)
	_check(str(bm.round_orders) == "[[0, 1, 2], [0, 1, 2]]")
	_check(bm.units[1].is_alive() == false and bm.units[2].is_alive() == false)

func _check(cond: bool) -> void:
	if not cond:
		_failed = true
		push_error("[SmokeTest] 断言失败")
