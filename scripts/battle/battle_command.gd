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

## 执行指令：校验 → 目标选择 → 伤害结算（T3.4 DamageCalc）→ 充能变化 → 结构化结果
## force_crit：-1 随机 / 0 恒不暴 / 1 恒暴（冒烟确定性通道，生产不传）
static func execute(units: Array, actor, kind: int, target = null, force_crit := -1) -> Dictionary:
	var reason := validate(actor, kind)
	if reason != "":
		return {"ok": false, "reason": reason, "kind": _kind_name(kind), "damage": 0}
	var had_target := target != null
	if target == null or not target.is_alive():
		target = _first_alive_enemy(units, actor)
		if had_target:
			push_warning("[BATTLECMD] %s 指定目标已死亡，自动改选存活者" % str(actor.name))
	if target == null:
		return {"ok": false, "reason": "无存活敌方目标", "kind": _kind_name(kind), "damage": 0}
	var skill: Variant = actor.skill_ult if kind == Kind.ULT else actor.skill_small
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
