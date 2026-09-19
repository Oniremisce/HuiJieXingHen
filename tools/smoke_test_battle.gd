extends SceneTree
## =============================================================
## T3.2 战斗状态机常驻冒烟回归（1v1 最小战斗，占位自动放招 vs 灾蚀兽）
## 运行（headless，先设 GODOT_MCP_RUNTIME_PORT='abc' 防注册表污染）：
##   godot --headless --path . --script res://tools/smoke_test_battle.gd
## -------------------------------------------------------------
## 出手序可复算：mech spd=10 / 兽 spd=8 → 到达 tick=ceil(100/spd)=10/13
## → 每轮 order=[0,1]（mech 先手，无平局；每轮全员归 0 重算，恒 [0,1]）。
## 手工预计算（伤害=int(max(1,atk*power-def))：mech 小8.4→8/大24、兽小1/大8；
## 充能 激活+10/小命中+20/受击+15，clamp 100，满 100 放大招后归零）：
## 用例一（占位覆盖兽 max_hp=40 → win）：
##   R1 mech小8→兽32/mechc30/兽c15；兽小1→mech99/兽c45/mechc45
##   R2 mech小8→兽24/mechc75/兽c60；兽小1→mech98/兽c90/mechc90
##   R3 mech c90+10=100 满→大招24→兽0死 → WIN R3；mech charge 归 0
##   终：mech hp98 charge0；兽 hp0；orders=[[0,1]]×3
## 用例二（反转占位血量 mech max_hp=12 → lose）：
##   R1 mech小8→兽142/c30,15；兽小1→mech11/c45,45
##   R2 mech小8→兽134/c75,60；兽小1→mech10/c90,90
##   R3 mech c100大招24→兽110/mechc0受击c15；兽 c100(90+15受击clamp)大招8→mech2/兽c0
##   R4 mech小8→兽102/c45,15；兽小1→mech1/兽c45/mechc60
##   R5 mech小8→兽94/mechc90/兽c60；兽小1→mech0 → LOSE R5
##   终：mech hp0；兽 hp94；orders=[[0,1]]×5
## 用例三（占位覆盖兽 max_hp=999 → 双方 6 轮内打不死 → timeout 无死锁）：
##   受击充能加速下 mech 于 R3/R6 各放大招：6 轮总伤 8*4+24*2=80 <999；
##   兽同轨迹 R3/R6 大招：总伤 1*4+8*2=20 <100 → 无人死，轮数耗尽强制终止；
##   orders=[[0,1]]×6，双方 alive（终值 mech hp80 / 兽 hp919）
## =============================================================

const DMS := preload("res://scripts/core/DataManager.gd")
const BM := preload("res://scripts/battle/battle_manager.gd")

var _failed := false

func _init() -> void:
	var dm = DMS.new()
	dm._load_all()  # headless --script 不触发 autoload _ready，需手动同步加载
	print("=== T3.2 战斗状态机冒烟开始 ===")
	_case_win(dm)
	_case_lose(dm)
	_case_timeout(dm)
	if _failed:
		print("=== T3.2 冒烟结束：存在失败项 ===")
		quit(1)
	else:
		print("=== T3.2 冒烟结束：全部通过 ===")
		quit(0)

func _case_win(dm) -> void:
	var bm = BM.new(dm, ["awakened_mech_01"], ["corrosion_beast"])
	bm.units[1].max_hp = 40  # 占位削弱兽血量：保证占位伤害 6 轮内分胜负（不改 CSV）
	bm.units[1].hp = 40
	var result: String = bm.run_to_end(6)
	print("[SMOKE] 用例一: result=%s rounds=%d orders=%s | %s | %s" % [
		result, bm.round_num, str(bm.round_orders), str(bm.units[0]), str(bm.units[1])])
	_check(result == "win")
	_check(bm.round_num == 3)
	_check(str(bm.round_orders) == "[[0, 1], [0, 1], [0, 1]]")
	_check(bm.units[0].hp == 98)
	_check(bm.units[0].charge == 0)  # R3 充能满 100 放大招后归零
	_check(bm.units[1].hp == 0 and bm.units[1].alive == false)

func _case_lose(dm) -> void:
	var bm = BM.new(dm, ["awakened_mech_01"], ["corrosion_beast"])
	bm.units[0].max_hp = 12  # 反转占位血量：我方 6 轮内被打空 → lose
	bm.units[0].hp = 12
	var result: String = bm.run_to_end(6)
	print("[SMOKE] 用例二: result=%s rounds=%d orders=%s | %s | %s" % [
		result, bm.round_num, str(bm.round_orders), str(bm.units[0]), str(bm.units[1])])
	_check(result == "lose")
	_check(bm.round_num == 5)
	_check(str(bm.round_orders) == "[[0, 1], [0, 1], [0, 1], [0, 1], [0, 1]]")
	_check(bm.units[0].hp == 0 and bm.units[0].alive == false)
	_check(bm.units[1].hp == 94)  # R5 末兽 102-8，充能轨迹偏差会破坏此值

func _case_timeout(dm) -> void:
	var bm = BM.new(dm, ["awakened_mech_01"], ["corrosion_beast"])
	bm.units[1].max_hp = 999  # 占位高血量：6 轮内双方均无法击破 → 触发轮数上限
	bm.units[1].hp = 999
	var result: String = bm.run_to_end(6)
	print("[SMOKE] 用例三: result=%s rounds=%d orders=%s | %s | %s" % [
		result, bm.round_num, str(bm.round_orders), str(bm.units[0]), str(bm.units[1])])
	_check(result == "timeout")  # 6 轮上限强制结束，无死锁（胜负语义待制作人裁定）
	_check(bm.round_num == 6)
	_check(str(bm.round_orders) == "[[0, 1], [0, 1], [0, 1], [0, 1], [0, 1], [0, 1]]")
	_check(bm.units[0].alive == true and bm.units[1].alive == true)

func _check(cond: bool) -> void:
	if not cond:
		_failed = true
		push_error("[SmokeTest] 断言失败")
