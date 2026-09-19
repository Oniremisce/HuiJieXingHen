extends RefCounted
## =============================================================
## T3.4 DamageCalc 正式伤害结算（口径：docs/系统规则/战斗系统.md §4.1/§4.4
## + docs/系统规则/星髓系统.md §7.1 + 推进表 T3.4 卡）
## -------------------------------------------------------------
## 公式（§7.1 字面）：damage = max(1, atk*skill_power - def) * (1 + 条件增伤)
##   条件增伤 = 星髓 3 件套：目标当前 HP/max_hp >70%（严格大于）/ <50%（严格小于）
##   判定时机 = 伤害结算时（§7.1/星髓系统 §3 注）
## 暴击（§7.1）：基础暴击率 10%（占位常量）+ 星髓暴击词条；暴伤 ×1.5 + 爆伤词条
## 合击技（§4.1，T3.5 消费）：存活者 atk 之和 × 100% 走同一管线（def 减免与
##   条件增伤乘区生效）；专用暴击率 = 存活者暴击率之和 ÷ 300、专用暴伤 =
##   固定 300%（不吃爆伤词条）
## 待制作人04 裁决（本卡占位口径，裁决后仅改本文件+冒烟断言）：
##   ① 暴击乘区位置：占位=最终乘区（与条件增伤连乘，乘法交换下无实际差异）
##   ② 取整时机：占位=全部乘区完成后一次 int() 截断
##   ③ 下限作用点：按 §7.1 公式字面 max(1, ...) 作用于乘区前基础段
##   ④ 合击条件增伤：占位=各存活者满足条件的套装加成求和
##
## 星髓接口位：get_stellium_bonus(character_id)——T6.5 前空实现（无装备恒
## 无加成）；T6.5 实装时由装备实表生成（读 Inventory.starmarrow → 套装件数
## 判定 → 词条与条件规格），DamageCalc 不直连 Inventory。
##
## 对外接口（T3.4 BC.execute / T3.5 合击 / T7.1 回归消费，勿改名）：
##   const DC := preload("res://scripts/battle/damage_calc.gd")
##   DC.calc(attacker, skill, target, force_crit := -1, bonus_override := {}) -> Dictionary
##   DC.combo_calc(party, power, target, force_crit := -1, bonus_override := {}) -> Dictionary
##     force_crit：-1 随机 / 0 恒不暴 / 1 恒暴（冒烟确定性通道，生产不传）
##     bonus_override：非空时替代 get_stellium_bonus 结果（测试/T6.5 联调注入）
##     返回 {"damage"(int 已取整), "crit", "crit_rate", "crit_mult"(combo 亦回), "cond", ...}
## =============================================================

const BASE_CRIT_RATE := 0.10       # 基础暴击率 10%（§7.1 占位，CSV 无列故为常量）
const BASE_CRIT_MULT := 1.5        # 基础暴伤 ×1.5（§7.1 占位）
const COMBO_MULT := 1.0            # 合击倍率 100%（§4.1 定值）
const COMBO_CRIT_DIVISOR := 3.0    # 合击暴击率 = 暴击率之和 ÷ 300%（小数口径 ÷3.0；§4.1 例：三人各 20% → 20%）
const COMBO_CRIT_MULT := 3.0       # 合击专用暴伤固定 300%（§4.1，不吃词条）

## 星髓加成接口位（T6.5 前空实现：无装备 → 无任何加成）
## 返回 {"crit": float 暴击率加成, "crit_dmg": float 爆伤加成,
##       "cond_specs": Array[Dictionary] 条件增伤规格，每项 {"op": ">"/"<", "threshold": float, "bonus": float}}
static func get_stellium_bonus(_character_id: String) -> Dictionary:
	return {"crit": 0.0, "crit_dmg": 0.0, "cond_specs": []}

## 普通技能伤害结算（BC.execute 消费）
static func calc(attacker, skill, target, force_crit := -1, bonus_override: Dictionary = {}) -> Dictionary:
	var bonus: Dictionary = get_stellium_bonus(str(attacker.id))
	if not bonus_override.is_empty():
		bonus = bonus_override  # 测试/T6.5 联调注入
	var base := maxf(float(attacker.atk) * float(skill.power) - float(target.def), 1.0)  # 下限 1（乘区前）
	var cond := _cond_total(bonus["cond_specs"], target)
	var dmg := base * (1.0 + cond)  # 最终增伤乘区（§7.1）
	var crit_rate: float = BASE_CRIT_RATE + float(bonus["crit"])
	var crit_mult: float = BASE_CRIT_MULT + float(bonus["crit_dmg"])
	var is_crit := _roll_crit(crit_rate, force_crit)
	if is_crit:
		dmg *= crit_mult
	return {"damage": int(dmg), "crit": is_crit, "crit_rate": crit_rate,
		"crit_mult": crit_mult, "cond": cond}

## 合击技伤害入口（§4.1，T3.5 消费）；party 可传全队，内部只取与 target 敌对
## （is_ally 相异）的存活者——合击为我方机制（§4.4.4 敌人无体系），死亡不计入求和
static func combo_calc(party: Array, power: float, target, force_crit := -1, bonus_override: Dictionary = {}) -> Dictionary:
	var atk_sum := 0.0
	var crit_sum := 0.0
	var cond_specs: Array = []
	var alive_count := 0
	for u in party:
		if not u.is_alive() or bool(u.is_ally) == bool(target.is_ally):
			continue  # 死亡角色/非攻击方（同阵营）不计入求和（§4.1）
		alive_count += 1
		atk_sum += float(u.atk)
		var b: Dictionary = get_stellium_bonus(str(u.id))
		if not bonus_override.is_empty():
			b = bonus_override  # 注入作用于每个存活者（测试用）
		crit_sum += BASE_CRIT_RATE + float(b["crit"])
		cond_specs += b["cond_specs"]  # 占位口径④：全体满足条件者求和，待裁决
	var base := maxf(atk_sum * power - float(target.def), 1.0)
	var cond := _cond_total(cond_specs, target)
	var dmg := base * (1.0 + cond)
	var crit_rate: float = crit_sum / COMBO_CRIT_DIVISOR  # 专用暴击率（§4.1）
	var is_crit := _roll_crit(crit_rate, force_crit)
	if is_crit:
		dmg *= COMBO_CRIT_MULT  # 专用暴伤固定 300%，不吃词条（§4.1）
	return {"damage": int(dmg), "crit": is_crit, "crit_rate": crit_rate,
		"crit_mult": COMBO_CRIT_MULT, "cond": cond, "alive_count": alive_count}

## 目标 HP 比例条件判定（§7.1：>70% 严格大于 / <50% 严格小于，满足者求和）
static func _cond_total(specs: Array, target) -> float:
	var total := 0.0
	if specs.is_empty():
		return 0.0
	var ratio := float(target.hp) / float(target.max_hp)  # 结算时当前 HP 占 max_hp
	for s in specs:
		var th := float(s["threshold"])
		if str(s["op"]) == ">" and ratio > th:
			total += float(s["bonus"])
		elif str(s["op"]) == "<" and ratio < th:
			total += float(s["bonus"])
	return total

## 暴击判定：force_crit -1 随机 / 0 恒不暴 / 1 恒暴（冒烟确定性通道）
static func _roll_crit(crit_rate: float, force_crit: int) -> bool:
	if force_crit == 1:
		return true
	if force_crit == 0:
		return false
	return randf() < crit_rate
