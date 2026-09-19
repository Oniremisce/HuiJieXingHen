extends SceneTree
## =============================================================
## T3.4 DamageCalc 手算验算（常驻回归；headless：先设 GODOT_MCP_RUNTIME_PORT='abc'
## 再 godot --headless --path . --script res://tools/smoke_test_damage_calc.gd）
## 手算预计算（force_crit 控制暴击、bonus_override 注入星髓；数值全部来自 CSV）：
## 组1 普通：mech(atk12, 小技能 power1.2) vs 兽(def6) → max(1,14.4-6)=8.4 ×(1+0) → int 8
## 组2 暴击：8.4×1.5=12.6 → 12（基础 crit_rate=0.10 / crit_mult=1.5 占位常量）
## 组3a 条件增伤 >70%（套装1 三件套 bonus0.5）：兽满血 ratio=1.0>0.7 → 8.4×1.5=12.6 → 12
## 组3b/3c 严格边界：兽 hp74/150→ratio0.4933 → >70% 不满足=8、<50% 满足=12；
##   兽 hp75 → ratio=0.5，<50% 严格小于不满足 → 8
## 组4 下限：mech atk 覆写 2 → max(1,2.4-6)=1 → 1
## 组5 合击（mech12+arcane15+xian13=40 ×100% -def6）：34；专用暴击率=(0.1×3)÷3.0=0.1；
##   暴击 34×300% 固定=102（注入爆伤词条 0.5 仍 102=不吃词条证明）
## 组5b 死亡剔除：xian hp0 → atk 和 27-6=21、alive_count=2（§4.1 死亡不计入求和）
## =============================================================

const DMS := preload("res://scripts/core/DataManager.gd")
const BU := preload("res://scripts/battle/battle_unit.gd")
const DC := preload("res://scripts/battle/damage_calc.gd")

var _failed := false

func _init() -> void:
	var dm = DMS.new()
	dm._load_all()  # headless --script 手动同步加载
	var mech = _unit(dm, "awakened_mech_01", true)
	var beast = _unit(dm, "corrosion_beast", false)
	var skill = dm.get_skill("skill_mech_s1")
	print("=== T3.4 DamageCalc 手算验算开始 ===")
	var r1: Dictionary = DC.calc(mech, skill, beast, 0)
	print("[SMOKE] 组1 普通: dmg=%d crit=%s" % [int(r1["damage"]), str(r1["crit"])])
	_check(int(r1["damage"]) == 8 and not bool(r1["crit"]))
	var r2: Dictionary = DC.calc(mech, skill, beast, 1)
	print("[SMOKE] 组2 暴击: dmg=%d crit=%s rate=%.2f mult=%.1f" % [int(r2["damage"]), str(r2["crit"]), float(r2["crit_rate"]), float(r2["crit_mult"])])
	_check(int(r2["damage"]) == 12 and bool(r2["crit"]))
	_check(absf(float(r2["crit_rate"]) - 0.10) < 0.0001 and absf(float(r2["crit_mult"]) - 1.5) < 0.0001)
	var spec1 := {"crit": 0.0, "crit_dmg": 0.0, "cond_specs": [{"op": ">", "threshold": 0.7, "bonus": 0.5}]}
	var spec2 := {"crit": 0.0, "crit_dmg": 0.0, "cond_specs": [{"op": "<", "threshold": 0.5, "bonus": 0.5}]}
	var r3a: Dictionary = DC.calc(mech, skill, beast, 0, spec1)
	print("[SMOKE] 组3a 条件增伤>70%%(满血): dmg=%d cond=%.1f" % [int(r3a["damage"]), float(r3a["cond"])])
	_check(int(r3a["damage"]) == 12 and absf(float(r3a["cond"]) - 0.5) < 0.0001)
	beast.hp = 74
	var r3b: Dictionary = DC.calc(mech, skill, beast, 0, spec1)
	var r3c: Dictionary = DC.calc(mech, skill, beast, 0, spec2)
	beast.hp = 75
	var r3d: Dictionary = DC.calc(mech, skill, beast, 0, spec2)
	beast.hp = beast.max_hp
	print("[SMOKE] 组3b/c/d 边界: hp74>=%d <=%d；hp75<=%d（严格边界）" % [int(r3b["damage"]), int(r3c["damage"]), int(r3d["damage"])])
	_check(int(r3b["damage"]) == 8 and int(r3c["damage"]) == 12 and int(r3d["damage"]) == 8)
	mech.atk = 2
	var r4: Dictionary = DC.calc(mech, skill, beast, 0)
	mech.atk = 12
	print("[SMOKE] 组4 下限: dmg=%d" % int(r4["damage"]))
	_check(int(r4["damage"]) == 1)
	var allies: Array = [_unit(dm, "awakened_mech_01", true), _unit(dm, "awakened_arcane_01", true), _unit(dm, "awakened_xian_01", true)]
	var crit_dmg_spec := {"crit": 0.0, "crit_dmg": 0.5, "cond_specs": []}
	var c1: Dictionary = DC.combo_calc(allies, 1.0, beast, 0)
	var c2: Dictionary = DC.combo_calc(allies, 1.0, beast, 1, crit_dmg_spec)
	print("[SMOKE] 组5 合击: 非暴=%d 暴击=%d crit_rate=%.2f" % [int(c1["damage"]), int(c2["damage"]), float(c1["crit_rate"])])
	_check(int(c1["damage"]) == 34 and int(c2["damage"]) == 102)  # ×300% 固定（爆伤词条不生效证明）
	_check(absf(float(c1["crit_rate"]) - 0.1) < 0.0001)
	allies[2].hp = 0
	allies[2].alive = false
	var c3: Dictionary = DC.combo_calc(allies, 1.0, beast, 0)
	print("[SMOKE] 组5b 死亡剔除: dmg=%d alive=%d" % [int(c3["damage"]), int(c3["alive_count"])])
	_check(int(c3["damage"]) == 21 and int(c3["alive_count"]) == 2)  # (12+15)-6
	if _failed:
		print("=== T3.4 手算验算结束：存在失败项 ===")
		quit(1)
	else:
		print("=== T3.4 手算验算结束：全部通过 ===")
		quit(0)

func _unit(dm, uid: String, is_ally: bool):
	var u = BU.new()
	u.setup(dm, uid, is_ally)
	return u

func _check(cond: bool) -> void:
	if not cond:
		_failed = true
		push_error("[SmokeTest] 断言失败")
