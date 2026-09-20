extends SceneTree
## =============================================================
## T3.6 演出冒烟（headless：先设 GODOT_MCP_RUNTIME_PORT='abc' 再
## godot --headless --path . --script res://tools/smoke_test_cutscene.gd）
## 场景1 假演出时序（同签名 FakeCutscene 注入，无挂起=同步直通语义验证）：
##   1v1 mech charge=100、兽 hp=100（T2.9 新 power 整体上调）、force0、run_to_end(3) →
##   敌我同演（占位⑧）：active(每回合首)→ult/skill 按指令分流→先于结算；
##   兽充能轨迹 45→90（受击3×15+激活3×10+小命中2×20）→ R3 兽 ULT
## 场景2 挂起一致性：FakeCutscene pause_frames=6 + await bm.run_to_end(6)
##   与 cutscene=null 直通（同步调用）双跑 → result 与双方终值逐值一致
##   （演出期间跑条/充能冻结=演出零数值影响 §2.2）
## 场景3 真演出层跳过：实例化 BattleCutscene.tscn → play_ult 后台跑（2s）→
##   0.5s 后置 _skip → finished 应在 <1.8s 内到达（跳过生效）
## =============================================================

const DMS := preload("res://scripts/core/DataManager.gd")
const BM := preload("res://scripts/battle/battle_manager.gd")
const CS := preload("res://scripts/battle/battle_cutscene.gd")

var _failed := false
var _n := 0

class FakeCutscene extends RefCounted:
	var calls: Array = []
	var pause_frames := 0
	var tree: SceneTree = null
	func play_active(id: String) -> void:
		calls.append("active:" + id)
	func play_skill(id: String, skill_id: String) -> void:
		calls.append("skill:" + skill_id)
		await _pause()
	func play_ult(id: String, skill_id: String) -> void:
		calls.append("ult:" + skill_id)
		await _pause()
	func play_combo() -> void:
		calls.append("combo")
		await _pause()
	func _pause() -> void:
		if pause_frames > 0 and tree != null:
			for i in range(pause_frames):
				await tree.process_frame

func _initialize() -> void:
	_run()

func _run() -> void:
	var dm = DMS.new()
	dm._load_all()
	print("=== T3.6 演出冒烟开始 ===")
	_case_sequence(dm)
	await _case_pause_parity(dm)
	await _case_skip()
	if _failed:
		print("=== T3.6 演出冒烟结束：存在失败项 ===")
		quit(1)
	else:
		print("=== T3.6 演出冒烟结束：全部通过 ===")
		quit(0)

## 场景1：假演出调用序列（时序：active 每回合首、ult/skill 按指令分流、先于结算）
func _case_sequence(dm) -> void:
	var bm = BM.new(dm, ["awakened_mech_01"], ["corrosion_beast"], ["机律"])
	bm.force_crit = 0
	var fake = FakeCutscene.new()
	bm.cutscene = fake
	bm.units[0].charge = 100
	bm.units[1].max_hp = 100  # T2.9 新 power 需要更高 hp 才能撑到 R3
	bm.units[1].hp = 100
	var result: String = await bm.run_to_end(3)
	# 占位口径⑧：敌方出手同走演出（§7 未分敌我；若裁定仅我方演出，BM._take_turn 演出分流加 is_ally 过滤一处）
	var expect := ["active:awakened_mech_01", "ult:skill_mech_ult",
		"active:corrosion_beast", "skill:enemy_beast_small",
		"active:awakened_mech_01", "skill:skill_mech_s1",
		"active:corrosion_beast", "skill:enemy_beast_small",
		"active:awakened_mech_01", "skill:skill_mech_s1",
		"active:corrosion_beast", "ult:enemy_beast_ult"]
	print("[SMOKE] 场景1: result=%s calls=%s" % [result, str(fake.calls)])
	_check(result == "timeout" and str(fake.calls) == str(expect))
	_check(bm.units[1].hp == 34)  # T2.9 新数值：100-30(ult)-18(s1)-18(s1)=34

## 场景2：演出挂起（6 帧/次）与直通双跑 → 结果与双方终值逐值一致（§2.2 跑条暂停）
func _case_pause_parity(dm) -> void:
	var conf := func(b):
		b.force_crit = 0
		b.units[0].charge = 100
		b.units[1].max_hp = 100  # T2.9 同步新数值
		b.units[1].hp = 100
	var bmA = BM.new(dm, ["awakened_mech_01"], ["corrosion_beast"], ["机律"])
	conf.call(bmA)
	var fake = FakeCutscene.new()
	fake.pause_frames = 6
	fake.tree = self
	bmA.cutscene = fake
	var rA: String = await bmA.run_to_end(6)
	var bmB = BM.new(dm, ["awakened_mech_01"], ["corrosion_beast"], ["机律"])
	conf.call(bmB)
	bmB.force_crit = 0
	var rB: String = await bmB.run_to_end(6)  # cutscene=null 直通（await no-op 立即完成）
	print("[SMOKE] 场景2: async=%s sync=%s | A=%s | B=%s" % [
		rA, rB, str(bmA.units[0]), str(bmB.units[0])])
	_check(rA == rB and str(bmA.units[0]) == str(bmB.units[0]))
	_check(str(bmA.units[1]) == str(bmB.units[1]) and str(bmA.round_orders) == str(bmB.round_orders))

## 场景3：真演出层实例化 + 空格跳过提前返回（2s 演出 0.5s 置 skip → <1.8s 播毕）
func _case_skip() -> void:
	var scn: Node = load("res://scenes/BattleCutscene.tscn").instantiate()
	root.add_child(scn)
	var got_finished := [false]
	scn.finished.connect(func(): got_finished[0] = true)
	var t0 := Time.get_ticks_msec()
	scn.play_ult("awakened_mech_01", "skill_mech_ult")  # 后台 coroutine（2s 或跳过）
	await create_timer(0.5).timeout
	scn._skip = true
	await scn.finished
	var dt := Time.get_ticks_msec() - t0
	print("[SMOKE] 场景3: 跳过耗时=%dms finished=%s" % [dt, str(got_finished[0])])
	_check(dt < 1800 and got_finished[0])
	scn.queue_free()

func _check(cond: bool) -> void:
	_n += 1
	if not cond:
		_failed = true
		print("[SmokeTest] 第 %d 个断言失败" % _n)
		push_error("[SmokeTest] 断言失败")
