extends SceneTree
## =============================================================
## T3.10 手动模式与目标选择冒烟（headless：先设 GODOT_MCP_RUNTIME_PORT='abc'
## 再 godot --headless --path . --script res://tools/smoke_test_t310.gd
## 输出重定向 tools/.smoke_t310.log 与 T2.11 隔离）
## -------------------------------------------------------------
## A. 目标集合五类型断言（BC.get_targets 六技能各一条 + 兽 enemy+single +
##    死亡过滤 + 敌方列归属=编队序下标<3 前列；single=候选池语义）
## B. 多目标 damage 结算（xian_s1 column 前列 3 兽 / arcane_s1 all 6 兽；
##    小技能命中充能只 +20 一次；单体路径回归不变）
## C. 手动状态机（call_deferred 启动 provider 协程：WAITING_INPUT→TARGETING→
##    确认全链 / Esc 回退 / 大招未满按 Q 无效 / column 前后列切换 / all 免选
##    直通 / 大招按钮灰显）
## D. AI 占位指令（自动模式：满则 ult 否则 small；敌方恒 AI）
## E. 飘字组件（生成→上飘渐隐→0.8s 回收）
## F. damage_dealt 信号（结算→飘字触发链）
## G. 异步 provider 全链（手动模式下 BM await command_provider 打完整场；
##    run_to_end 经 call_deferred 启动+轮询 state，4.7 协程不得同步 call）
## =============================================================

const DMS := preload("res://scripts/core/DataManager.gd")
const BM := preload("res://scripts/battle/battle_manager.gd")
const BC := preload("res://scripts/battle/battle_command.gd")
const BATTLE_SCENE := preload("res://scenes/Battle.tscn")
const MANUAL := preload("res://scripts/battle/battle_manual_input.gd")

const PARTY := ["awakened_mech_01", "awakened_arcane_01", "awakened_xian_01"]

var _failed := false
var _n := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var dm = DMS.new()
	dm._load_all()
	print("=== T3.10 手动模式与目标选择冒烟开始 ===")
	var bm = BM.new(dm, PARTY, ["corrosion_beast", "corrosion_beast", "corrosion_beast",
		"corrosion_beast", "corrosion_beast", "corrosion_beast"])
	bm.force_crit = 0
	_test_get_targets(bm)
	_test_multi_target(bm)
	var arena = BATTLE_SCENE.instantiate()
	root.add_child(arena)
	arena.setup_stances(PARTY, ["corrosion_beast", "corrosion_beast", "corrosion_beast",
		"corrosion_beast", "corrosion_beast", "corrosion_beast"])
	var manual = MANUAL.new()
	arena.get_node("BattleUI").add_child(manual)
	manual.setup(bm, arena)
	_test_state_machine(manual)
	_test_ai_command(manual, bm)
	await _test_floating_text(arena)
	await _test_damage_signal(dm)
	await _test_async_provider(dm, manual, arena)
	arena.queue_free()
	if _failed:
		print("=== T3.10 冒烟结束：存在失败项 ===")
		quit(1)
	else:
		print("=== T3.10 冒烟结束：全部通过 ===")
		quit(0)

## A. 目标集合五类型（skills.csv 三字段驱动；single=候选池语义）
func _test_get_targets(bm) -> void:
	var units: Array = bm.units
	var mech = units[0]
	# ① mech_s1（ally+single heal）：候选池=全队 3
	var t1: Array = BC.get_targets(units, mech, mech.skill_small)
	_check(t1.size() == 3 and t1[0].is_ally)
	# ② mech_ult（ally+single shield）：同上
	var t2: Array = BC.get_targets(units, mech, mech.skill_ult)
	_check(t2.size() == 3)
	# ③ arcane_s1（enemy+all）：6 敌
	var t3: Array = BC.get_targets(units, units[1], units[1].skill_small)
	_check(t3.size() == 6 and not t3[0].is_ally)
	# ④ arcane_ult（ally+all）：全队 3
	var t4: Array = BC.get_targets(units, units[1], units[1].skill_ult)
	_check(t4.size() == 3 and t4[0].is_ally)
	# ⑤ xian_s1（enemy+column）：前列=编队序敌下标<3（units[3..5]）、后列=[6..8]
	var t5f: Array = BC.get_targets(units, units[2], units[2].skill_small, "front")
	var t5b: Array = BC.get_targets(units, units[2], units[2].skill_small, "back")
	_check(t5f.size() == 3 and t5f[0] == units[3] and t5f[2] == units[5])
	_check(t5b.size() == 3 and t5b[0] == units[6] and t5b[2] == units[8])
	# ⑥ xian_ult（enemy+all）：6
	var t6: Array = BC.get_targets(units, units[2], units[2].skill_ult)
	_check(t6.size() == 6)
	# ⑦ 典兽 enemy_beast_small（enemy+single）：候选池=我方 3
	var t7: Array = BC.get_targets(units, units[3], units[3].skill_small)
	_check(t7.size() == 3 and t7[0].is_ally)
	# ⑧ 死亡过滤：兽A 死 → all=5、前列=2
	units[3].take_damage(9999)
	var t8a: Array = BC.get_targets(units, units[1], units[1].skill_small)
	var t8f: Array = BC.get_targets(units, units[2], units[2].skill_small, "front")
	_check(t8a.size() == 5 and t8f.size() == 2)
	print("[SMOKE] A 目标集合: mech_s1=%d mech_ult=%d arcane_s1=%d arcane_ult=%d xian_front=%d xian_back=%d xian_ult=%d 兽single=%d 死后all=%d" % [
		t1.size(), t2.size(), t3.size(), t4.size(), t5f.size(), t5b.size(), t6.size(), t7.size(), t8a.size()])

## B. 多目标 damage 结算（T3.10 execute 扩展；先复活兽A）
func _test_multi_target(bm) -> void:
	var units: Array = bm.units
	units[3].hp = units[3].max_hp  # 复活兽A（A 段杀死，恢复 6 敌满编）
	units[3].alive = true
	var xian = units[2]
	var hp0: Array = []
	for i in range(3, 9):
		hp0.append(int(units[i].hp))
	var res: Dictionary = BC.execute(units, xian, BC.Kind.SKILL, null, 0, "front")
	_check(bool(res["ok"]) and res.has("targets") and res["targets"].size() == 3)
	var hit := 0
	for i in 3:
		if int(units[3 + i].hp) < hp0[i]:
			hit += 1
	_check(hit == 3)                      # 前列 3 兽全扣血
	_check(int(units[6].hp) == hp0[3])    # 后列不受影响
	_check(int(xian.charge) == 20)        # 小技能命中充能只 +20 一次
	var res2: Dictionary = BC.execute(units, units[1], BC.Kind.SKILL, null, 0)  # arcane_s1 all
	_check(bool(res2["ok"]) and res2["targets"].size() == 6)
	var res3: Dictionary = BC.execute(units, units[3], BC.Kind.SKILL)  # 兽单体路径回归
	_check(bool(res3["ok"]) and not res3.has("targets") and res3["target"].is_ally)
	print("[SMOKE] B 多目标: column前列=3兽扣血 charge=20 all=6兽 单体回归ok")

## C. 手动状态机（call_deferred 启动 provider 协程；command_done 回传结果）
func _test_state_machine(manual) -> void:
	manual.mode = MANUAL.Mode.MANUAL
	var got: Array = []
	manual.command_done.connect(func(cmd: Array) -> void: got.append(cmd))
	var pr: Callable = Callable(manual, "provide_command")
	# ① WAITING_INPUT（deferred 启动 provider，挂起等待指令）
	pr.call_deferred(manual._bm.units[0])
	await process_frame
	await process_frame
	_check(manual.st == MANUAL.St.WAITING_INPUT)
	_check(manual._btn_small.visible and manual._btn_ult.visible)
	# ② 大招未满按 Q 无效（诺菈 charge=0，不进 TARGETING）
	manual._pick_skill(BC.Kind.ULT)
	_check(manual.st == MANUAL.St.WAITING_INPUT)
	# ③ E 进 TARGETING（mech_s1=ally+single → 候选池 3 队友、向上箭头）
	manual._pick_skill(BC.Kind.SKILL)
	_check(manual.st == MANUAL.St.TARGETING and manual._candidates.size() == 3)
	_check(_arrow_visible(manual._arena))
	# ④ 移动键切换目标
	var sel0: int = manual._sel
	manual._move_selection(1)
	_check(manual._sel != sel0)
	# ⑤ Esc 取消回 WAITING_INPUT
	manual._cancel()
	_check(manual.st == MANUAL.St.WAITING_INPUT and manual._candidates.is_empty())
	# ⑥ 充满后 Q 进 TARGETING；确认释放 → cmd=[ULT, 队友]
	manual._bm.units[0].charge = 100
	await process_frame  # _process 刷新大招按钮 disabled（充满→亮起）
	manual._pick_skill(BC.Kind.ULT)
	_check(manual.st == MANUAL.St.TARGETING and manual._btn_ult.disabled == false)
	manual._confirm()
	await process_frame
	_check(got.size() == 1 and manual.st == MANUAL.St.IDLE
		and int(got[0][0]) == BC.Kind.ULT and got[0][1] != null and bool(got[0][1].is_ally))
	# ⑦ column 前后列切换（洛清弦 xian_s1）：front 3 → 切 back 3 → 确认 cmd 带 col
	pr.call_deferred(manual._bm.units[2])
	await process_frame
	await process_frame
	_check(manual.st == MANUAL.St.WAITING_INPUT)
	manual._pick_skill(BC.Kind.SKILL)
	_check(manual.st == MANUAL.St.TARGETING and manual._candidates.size() == 3
		and manual._candidates[0] == manual._bm.units[3])
	manual._move_selection(1)
	_check(manual._col == "back" and manual._candidates.size() == 3
		and manual._candidates[0] == manual._bm.units[6])
	manual._confirm()
	await process_frame
	_check(got.size() == 2 and int(got[1][0]) == BC.Kind.SKILL
		and got[1][1] == null and str(got[1][2]) == "back")
	# ⑧ all 免选直通（艾蕾雅 arcane_s1：确认即释放不进 TARGETING）
	pr.call_deferred(manual._bm.units[1])
	await process_frame
	await process_frame
	_check(manual.st == MANUAL.St.WAITING_INPUT)
	manual._pick_skill(BC.Kind.SKILL)
	await process_frame
	_check(got.size() == 3 and int(got[2][0]) == BC.Kind.SKILL and got[2][1] == null
		and manual.st == MANUAL.St.IDLE)
	print("[SMOKE] C 状态机: WAITING→TARGETING→确认/Esc回退/未满Q无效/column切换/all直通 全链通过")

func _arrow_visible(arena) -> bool:
	for s in arena._stand_units:
		var a: Polygon2D = s["arrow"]
		if a != null and a.visible:
			return true
	return false

## D. AI 占位指令（自动模式；敌方恒 AI；自足设置充能）
func _test_ai_command(manual, bm) -> void:
	manual.mode = MANUAL.Mode.AUTO
	bm.units[0].charge = 100
	var c1: Array = await manual.provide_command(bm.units[0])
	_check(int(c1[0]) == BC.Kind.ULT)                          # 满则 ult
	bm.units[0].charge = 0
	var c2: Array = await manual.provide_command(bm.units[0])
	_check(int(c2[0]) == BC.Kind.SKILL)                        # 未满 small 优先
	var c3: Array = await manual.provide_command(bm.units[4])  # 敌方单位 → 恒 AI 立即返回
	_check(int(c3[0]) == BC.Kind.SKILL or int(c3[0]) == BC.Kind.ULT)
	manual.mode = MANUAL.Mode.MANUAL
	print("[SMOKE] D AI占位: 满→ult 未满→small 敌方恒AI")

## E. 飘字组件（生成→渐隐→回收）
func _test_floating_text(arena) -> void:
	var before: int = arena.get_child_count()
	arena.spawn_floating_text(0, "18", Color(1, 1, 1))
	var ft = null
	for c in arena.get_children():
		if c.has_method("progress"):
			ft = c
	_check(ft != null and arena.get_child_count() == before + 1)
	_check(ft.progress() < 1.0)
	await create_timer(1.0).timeout
	_check(not is_instance_valid(ft))  # 0.8s 生命周期后回收
	print("[SMOKE] E 飘字: 生成+渐隐+回收 通过")

## F. damage_dealt 信号 → 飘字触发链（自动模式真跑一场）
func _test_damage_signal(dm) -> void:
	var bm = BM.new(dm, ["awakened_mech_01"], ["corrosion_beast"])
	bm.force_crit = 0
	bm.units[1].max_hp = 40
	bm.units[1].hp = 40
	var hits: Array = []
	bm.damage_dealt.connect(func(uidx: int, amount: int, crit: bool) -> void:
		hits.append([uidx, amount, crit]))
	var result: String = await bm.run_to_end(6)
	_check(result == "win" and hits.size() >= 3 and int(hits[0][0]) == 1)  # 兽=编队序下标 1
	print("[SMOKE] F damage_dealt: %d 次信号（idx=%s ...）" % [hits.size(), str(hits[0][0])])

## G. 异步 provider 全链：手动模式下 BM await command_provider 打完整场
func _test_async_provider(dm, manual, arena) -> void:
	var bm = BM.new(dm, ["awakened_mech_01"], ["corrosion_beast"])
	bm.force_crit = 0
	bm.units[1].max_hp = 40
	bm.units[1].hp = 40
	arena.attach_battle(bm)   # 飘字/血条绑新 bm
	bm.command_provider = manual.provide_command
	var waited := [0]
	var run := Callable(bm, "run_to_end")
	run.call_deferred(30)  # 4.7 协程不得同步 call：deferred 启动 + 轮询 state
	var frames := 0
	while bm.state < 3 and frames < 7200:  # 非终局逐帧喂指令（模拟玩家）
		await process_frame
		frames += 1
		if manual.st == MANUAL.St.WAITING_INPUT:
			waited[0] += 1
			manual._finish([BC.Kind.SKILL, null])  # 模拟玩家按 E 确认小技能
	_check(int(bm.state) == 3 and waited[0] >= 3)  # State.WIN=3；每轮都等待过手动输入
	print("[SMOKE] G 异步provider: 手动等待 %d 次全链 WIN（%d 帧）" % [waited[0], frames])

func _check(cond: bool) -> void:
	_n += 1
	if not cond:
		_failed = true
		print("[SmokeTest] 第 %d 个断言失败" % _n)
		push_error("[SmokeTest] 断言失败")
