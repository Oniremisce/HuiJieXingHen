extends SceneTree
## =============================================================
## T3.8 速度条/参战行表现层冒烟（headless；先设 GODOT_MCP_RUNTIME_PORT='abc'
## 再 godot --headless --path . --script res://tools/smoke_test_speed_bar.gd）
## 断言：
##   1. RUNBAR_FULL_TIME 存在且默认 =1.0（§2.3 契约）
##   2. 头像条位随模拟位置连续移动（非跳变；匀速增量一致）
##   3. 到达 100 → 跑条暂停 + 冻结 + acting_uid 标记（§2.3/§2.6）
##   4. 演出播毕通知 → 出手单位归 0、其余恢复前推（§2.2）
##   5. 改值生效：RUNBAR_FULL_TIME=0.5 时到达时刻按比例减半（非硬编码）
##   6. 终局（state>=3）冻结（WIN=3/LOSE=4 同构 int）
##   7. 右下参战行：血条随 hp 变化、<30% 低位、激活高亮跟随 acting_uid
##   8. 演出代理转发：四方法透传假演出 + 播毕通知（bm.cutscene 契约不破坏）
## 鸭子注入（同构字段 units/round_orders/round_num/state），不碰 BM/SIM。
## =============================================================

const SB := preload("res://scripts/battle/battle_speed_bar.gd")
const PR := preload("res://scripts/battle/battle_party_row.gd")

var _failed := false
var _n := 0

class DuckUnit:
	extends RefCounted
	var id := ""
	var name := ""
	var spd := 10
	var is_ally := true
	var hp := 100
	var max_hp := 100
	func is_alive() -> bool:
		return hp > 0

class DuckBM:
	extends RefCounted
	var units: Array = []
	var round_orders: Array = []
	var round_num := 1
	var state := 1  # RUNNING（INTRO0/RUNNING1/ACTION2/WIN3/LOSE4 同构）

class FakeRealCutscene:
	extends RefCounted
	var calls: Array = []
	func play_active(id: String) -> void:
		calls.append("active:" + id)
	func play_skill(id: String, skill_id: String) -> void:
		calls.append("skill:" + skill_id)
	func play_ult(id: String, skill_id: String) -> void:
		calls.append("ult:" + skill_id)
	func play_combo(combo_name: String = "三人合击") -> void:
		calls.append("combo:" + combo_name)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("=== T3.8 速度条表现层冒烟开始 ===")
	# ---- 环境：速度条 + 参战行 + 鸭子 BM（mech10/arcane20 均我方，beast25 敌方）----
	var bar: Control = SB.new()
	bar.name = "SpeedBarTest"
	root.add_child(bar)
	var pr: Control = PR.new()
	pr.name = "PartyRowTest"
	pr.size = Vector2(1152, 648)
	root.add_child(pr)
	var bm := DuckBM.new()
	for cfg in [["awakened_mech_01", 10, true], ["awakened_arcane_01", 20, true], ["corrosion_beast", 25, false]]:
		var u := DuckUnit.new()
		u.id = cfg[0]
		u.name = cfg[0]
		u.spd = cfg[1]
		u.is_ally = cfg[2]
		bm.units.append(u)
	bm.round_orders = [[2, 1, 0]]  # ceil(100/spd)=4/5/10 → 后台序 beast→arcane→mech
	bm.round_num = 1
	bm.state = 1
	bar.attach_battle(bm)
	pr.setup(bm, bar)

	# ---- 断言1：RUNBAR_FULL_TIME 默认 1.0 ----
	print("[SMOKE] RUNBAR_FULL_TIME=%s" % str(SB.RUNBAR_FULL_TIME))
	_check(float(SB.RUNBAR_FULL_TIME) == 1.0)

	# ---- 断言2：条位连续移动（rate=25/18.333=1.3636 → 0.1s 增量 13.64）----
	var avg := 55.0 / 3.0
	bar._advance(0.1)
	var p1: float = bar.avatar_bar_pos(2)
	bar._advance(0.1)
	var p2: float = bar.avatar_bar_pos(2)
	bar._advance(0.1)
	var p3: float = bar.avatar_bar_pos(2)
	print("[SMOKE] 条位 t=0.1/0.2/0.3 → %.3f / %.3f / %.3f" % [p1, p2, p3])
	_check(p1 > 0.0 and p2 > p1 and p3 > p2)  # 连续移动非跳变
	_check(absf(p1 - 100.0 * (25.0 / avg) * 0.1 / float(SB.RUNBAR_FULL_TIME)) < 0.01)
	_check(absf((p2 - p1) - (p1 - 0.0)) < 0.01)  # 匀速（同窗口增量一致）
	var expected_pos1: float = bar.avatar_bar_pos(0)
	_check(absf(expected_pos1 - 100.0 * (10.0 / avg) * 0.3 / float(SB.RUNBAR_FULL_TIME)) < 0.01)

	# ---- 断言3：beast 到达 100（τ=1.0×18.333/25=0.7333s）→ 暂停+冻结+激活标记 ----
	for i in range(5):
		bar._advance(0.1)  # clock 0.3→0.8，遇 0.7333 截停（时钟单调，过冲≤步长）
	print("[SMOKE] paused=%s clock=%.4f last_arrival=%.4f acting=%s" % [
		str(bar._paused), bar._clock, bar.last_arrival_clock, bar.acting_uid])
	_check(bar._paused)
	_check(absf(bar.last_arrival_clock - float(SB.RUNBAR_FULL_TIME) * avg / 25.0) < 0.001)  # 到达时刻=RUNBAR_FULL_TIME/rate
	_check(bar.avatar_bar_pos(2) == 100.0)
	_check(bar.acting_uid == "corrosion_beast")
	var frozen_arcane: float = bar.avatar_bar_pos(1)
	_check(frozen_arcane > 0.0 and frozen_arcane < 100.0)  # 未到达者保持途中位置
	bar._advance(0.3)
	_check(bar.avatar_bar_pos(1) == frozen_arcane)  # 暂停期冻结（跑条动画暂停 §2.3）

	# ---- 断言4：演出播毕 → beast 归 0，其余恢复前推 ----
	bar._on_window_closed()
	_check(bar.avatar_bar_pos(2) == 0.0)  # 出手后归 0 §2.2
	_check(not bar._paused)
	bar._advance(0.1)
	var resumed_arcane: float = bar.avatar_bar_pos(1)
	print("[SMOKE] 恢复后 arcane=%.3f（暂停前 %.3f）" % [resumed_arcane, frozen_arcane])
	_check(resumed_arcane > frozen_arcane)
	for i in range(2):
		bar._advance(0.1)  # arcane τ=0.9167 到达
	_check(bar._paused and bar.acting_uid == "awakened_arcane_01" and bar.avatar_bar_pos(1) == 100.0)
	bar._on_window_closed()
	for i in range(10):
		bar._advance(0.1)  # mech τ=1.8333 到达
	_check(bar._paused and bar.acting_uid == "awakened_mech_01" and bar.avatar_bar_pos(0) == 100.0)
	bar._on_window_closed()
	_check(bar.avatar_bar_pos(0) == 0.0 and bar.avatar_bar_pos(1) == 0.0 and bar.avatar_bar_pos(2) == 0.0)

	# ---- 断言6：终局冻结 ----
	bm.state = 3  # WIN
	bar._advance(0.1)
	var q: float = bar.avatar_bar_pos(1)
	bar._advance(0.5)
	_check(bar.avatar_bar_pos(1) == q)
	print("[SMOKE] 终局冻结：%.3f → %.3f（不变）" % [q, bar.avatar_bar_pos(1)])

	# ---- 断言5：改值生效（0.5 → 到达时刻减半；走产线重绑路径 attach_battle）----
	SB.RUNBAR_FULL_TIME = 0.5
	bm.state = 1
	bm.round_num = 2
	bm.round_orders.append([2, 1, 0])
	bar.attach_battle(bm)  # 与产线重试同路径：重绑重置终局冻结并重建头像
	bar._advance(0.1)
	print("[SMOKE] 改值 0.5 后 R2：期望首达 %.4f" % (float(SB.RUNBAR_FULL_TIME) * avg / 25.0))
	for i in range(5):
		bar._advance(0.1)
	_check(bar._paused)
	_check(absf(bar.last_arrival_clock - float(SB.RUNBAR_FULL_TIME) * avg / 25.0) < 0.001)  # 0.5×18.333/25=0.3667
	SB.RUNBAR_FULL_TIME = 1.0  # 还原
	print("[SMOKE] RUNBAR_FULL_TIME 已还原 =%s" % str(SB.RUNBAR_FULL_TIME))

	# ---- 断言7：参战行血条/激活高亮 ----
	bar.acting_uid = "awakened_mech_01"
	pr._tick(0.016)
	_check(pr._slots.size() == 2)  # 我方 mech+arcane 两槽
	var slot0: Dictionary = pr._slots[0]
	_check(slot0["id"] == "awakened_mech_01")
	_check((slot0["ring"] as Panel).visible)  # 激活高亮
	var mech: DuckUnit = bm.units[0]
	mech.hp = 50
	pr._tick(0.016)
	var fg: ColorRect = slot0["hp_fg"]
	print("[SMOKE] hp50 fg宽=%.1f（期望24.0）" % fg.size.x)
	_check(absf(fg.size.x - 24.0) < 0.01)
	mech.hp = 20  # <30% → 低位色+闪烁
	pr._tick(0.1)
	var fg_low: Color = fg.color
	_check(fg_low.r < 0.8 and fg_low.a < 1.0)  # #B34A3C 且闪烁半透明
	mech.hp = 0
	pr._tick(0.016)
	_check(fg.size.x == 0.0)  # 阵亡血条空
	bar.acting_uid = ""
	pr._tick(0.016)
	_check(not (slot0["ring"] as Panel).visible)  # 无激活不高亮

	# ---- 断言8：演出代理转发 + 播毕通知 ----
	var real := FakeRealCutscene.new()
	var proxy: RefCounted = bar.make_cutscene_proxy(real)
	bar._paused = true  # 模拟到达暂停
	bar._last_arrived = 1
	await proxy.play_skill("awakened_arcane_01", "skill_arcane_01_s1")
	_check(real.calls.size() == 1 and real.calls[0] == "skill:skill_arcane_01_s1")
	_check(not bar._paused and bar._parked.has(1))  # 播毕通知放行
	await proxy.play_active("awakened_mech_01")
	_check(real.calls.size() == 2 and real.calls[0] == "skill:skill_arcane_01_s1" and real.calls[1] == "active:awakened_mech_01")

	if _failed:
		print("=== T3.8 冒烟结束：存在失败项 ===")
		quit(1)
	else:
		print("=== T3.8 冒烟结束：全部通过 ===")
		quit(0)

func _check(cond: bool) -> void:
	_n += 1
	if not cond:
		_failed = true
		print("[SmokeTest] 第 %d 个断言失败" % _n)
		push_error("[SmokeTest] 断言失败")
