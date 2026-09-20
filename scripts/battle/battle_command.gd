extends RefCounted
## =============================================================
## T3.3 BattleCommand 指令（口径：docs/系统规则/战斗系统.md §3 + 推进表 T3.3 卡）
## -------------------------------------------------------------
## 两种指令（无独立普攻，小技能即每轮可用基础攻击）：
##   SKILL 小技能：恒可用，无消耗
##   ULT   大招：需 charge==charge_max 或 charge_free=true；释放后 charge=0
## 校验返回原因字符串（数据层供 UI 图标三态查询：validate()=="" 即亮，
## 未满灰；"释放中"态由演出层 T3.6 标记，本卡不做）。
## 执行走占位伤害管线 max(1, atk*power-def)（int 截断）——T3.4 替换；
## SkillData.power 为 float 倍率制，无 energy_cost 字段（T2.8 已删，勿读）。
## 目标选择（MVP）：指令可携带目标参数，缺省自动选敌方首个存活者；
## 指定目标已死亡 → 跳过并自动改选存活者；敌方全灭 → ok=false 不空打。
##
## 对外接口（T3.7 UI / 冒烟消费，勿改名）：
##   const BC := preload("res://scripts/battle/battle_command.gd")
##   BC.validate(actor, kind) -> String      # ""=可用，否则原因
##   BC.execute(units, actor, kind, target=null) -> Dictionary
##     units=BattleManager.units（编队序）；target 可空/可为指定单位
##     返回：{"ok", "reason", "kind", "skill", "actor", "target",
##            "damage", "actor_charge", "target_hp", "target_alive"}
## =============================================================

enum Kind { SKILL, ULT }

const DMG := preload("res://scripts/battle/damage_calc.gd")  # T3.4 伤害结算

## 指令校验：返回 ""（可执行）或原因字符串（不修改任何状态）
static func validate(actor, kind: int) -> String:
	if kind == Kind.ULT and not actor.can_use_ult():
		return "充能未满(%d/%d)" % [int(actor.charge), int(actor.charge_max)]
	return ""

## ------------------------------------------------------------
## 目标集合选取器（T3.10 §3.1/§8.2 五类映射；T3.11 效果结算复用，勿改名）
## units=BM.units 编队序；actor=施法者；skill=SkillData（三字段驱动）；
## col=整列列名（"front"/"back"，仅敌方 column 消费）
## 敌方列归属按编队序推导：敌方下标（含已死者）<3=前列、>=3=后列
## （T3.9 落位规则=front×3+back×剩余，无需额外列映射表）
## 返回**候选池**（§8.2 UI 箭头遍历/切换用）：single=全部可选者（任意敌人/
## 含满血队友）、column=选定列全体、all=全体；execute 单体结算取
## chosen/首个，column/all 取全池结算
static func get_targets(units: Array, actor, skill: Variant, col := "front") -> Array:
	var side := str(skill.target_side)
	var scope := str(skill.target_scope)
	var pool: Array = []
	for t in units:
		if not t.is_alive():
			continue
		if (t.is_ally == actor.is_ally) == (side == "ally"):
			pool.append(t)
	match scope:
		"column":
			if side != "enemy":
				return pool.slice(0, 1)  # ally 无 column（§3.1），降级单体
			var out: Array = []
			var eidx := 0
			for t in units:
				if t.is_ally == actor.is_ally:
					continue
				if t.is_alive() and ((eidx < 3) == (col == "front")):
					out.append(t)
				eidx += 1
			return out
		_:
			return pool  # single=全部可选者（UI 逐个切换）；all=全体

## 执行指令：校验 → 目标选择 → 结算（damage 多目标 / 其余 T3.11）→ 充能变化 → 结果
## force_crit：-1 随机 / 0 恒不暴 / 1 恒暴（冒烟确定性通道，生产不传）
## col：整列 scope 选定列（手动模式 UI 传入；自动/缺省=前列）
## 多目标行结构 {"target","damage","crit"}；res["targets"]=多目标时存在（首目标
## 同步写 "target"/"damage" 旧字段，向后兼容既有消费方）
static func execute(units: Array, actor, kind: int, target = null, force_crit := -1, col := "front") -> Dictionary:
	var reason := validate(actor, kind)
	if reason != "":
		return {"ok": false, "reason": reason, "kind": _kind_name(kind), "damage": 0}
	var skill: Variant = actor.skill_ult if kind == Kind.ULT else actor.skill_small
	var scope := str(skill.target_scope)
	# 多目标结算（T3.10）：column/all 且 damage——逐目标 DamageCalc+扣血；充能只消耗一次
	if scope != "single" and str(skill.effect) == "damage":
		var targets := get_targets(units, actor, skill, col)
		if targets.is_empty():
			return {"ok": false, "reason": "无存活敌方目标", "kind": _kind_name(kind), "damage": 0}
		var rows: Array = []
		for t in targets:
			var dc: Dictionary = DMG.calc(actor, skill, t, force_crit)
			var dmg := int(dc["damage"])
			t.take_damage(dmg)  # 扣血 + 受击充能 +15（BattleUnit）
			rows.append({"target": t, "damage": dmg, "crit": bool(dc["crit"])})
		if kind == Kind.ULT:
			actor.consume_ult()          # 大招释放后 charge=0（§3）
		else:
			actor.charge_on_small_hit()  # 小技能命中 +20（§3，一次）
		return {"ok": true, "reason": "", "kind": _kind_name(kind), "skill": skill,
			"actor": actor, "target": rows[0]["target"], "damage": int(rows[0]["damage"]),
			"crit": bool(rows[0]["crit"]), "targets": rows,
			"actor_charge": int(actor.charge), "target_hp": int(rows[0]["target"].hp),
			"target_alive": bool(rows[0]["target"].is_alive())}
	# 单体路径（现状保持：heal/shield/amp 的 effect 分支结算归 T3.11）
	var had_target := target != null
	if target == null or not target.is_alive():
		target = _first_alive_enemy(units, actor)
		if had_target:
			push_warning("[BATTLECMD] %s 指定目标已死亡，自动改选存活者" % str(actor.name))
	if target == null:
		return {"ok": false, "reason": "无存活敌方目标", "kind": _kind_name(kind), "damage": 0}
	# 正式伤害结算（T3.4 DamageCalc：增伤乘区+暴击，替换 T3.2b 占位公式）
	var dc: Dictionary = DMG.calc(actor, skill, target, force_crit)
	var dmg := int(dc["damage"])
	target.take_damage(dmg)  # 扣血 + 受击充能 +15（BattleUnit）
	if kind == Kind.ULT:
		actor.consume_ult()          # 大招释放后 charge=0（§3）
	else:
		actor.charge_on_small_hit()  # 小技能命中 +20（§3）
	return {"ok": true, "reason": "", "kind": _kind_name(kind), "skill": skill,
		"actor": actor, "target": target, "damage": dmg, "crit": bool(dc["crit"]),
		"actor_charge": int(actor.charge), "target_hp": int(target.hp),
		"target_alive": bool(target.is_alive())}

static func _first_alive_enemy(units: Array, actor):
	for t in units:
		if t.is_alive() and t.is_ally != actor.is_ally:
			return t
	return null

static func _kind_name(kind: int) -> String:
	return "大招" if kind == Kind.ULT else "小技能"
