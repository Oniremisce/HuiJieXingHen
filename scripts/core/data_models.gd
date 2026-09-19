## =============================================================
## 《汇界星痕》T0.2 核心数据模型（推进表 §2.3）
## -------------------------------------------------------------
## 职责：CSV 行（Dictionary，列名 → 原始值）→ 数据对象模型。
## 全部为 RefCounted（后续如需 Resource 再迁移），字段可扩展。
## 用法：DataModels.CharacterData.from_csv_row(row_dict)
## 容错规则（推进表 §2.4-③）：
##   空值 / 缺键 → 默认值（数值 0、字符串 ""、布尔 false）
##   非法值     → push_warning 并取默认值，不中断解析
## =============================================================
class_name DataModels
extends RefCounted


## ------------------------------------------------------------
## 数据模型基类：容错字段转换静态工具，所有数据模型继承自它
## ------------------------------------------------------------
class BaseRow extends RefCounted:

	## 字符串字段：空值/缺键 → ""，其余原样返回（去首尾空白）
	static func field_str(row: Dictionary, key: String) -> String:
		var value: Variant = row.get(key)
		if value == null:
			return ""
		return str(value).strip_edges()

	## 整数字段：空值/缺键 → 0；非法值警告后取 0，不中断
	static func field_int(row: Dictionary, key: String) -> int:
		var s := field_str(row, key)
		if s.is_empty():
			return 0
		if s.is_valid_int():
			return s.to_int()
		if s.is_valid_float():
			push_warning("[DataModels] 字段 \"%s\" 期望整数，实际为浮点 \"%s\"，已截断取整" % [key, s])
			return int(s.to_float())
		push_warning("[DataModels] 字段 \"%s\" 非法整数值 \"%s\"，取默认值 0" % [key, s])
		return 0

	## 浮点字段：空值/缺键 → 0.0；非法值警告后取 0.0，不中断
	static func field_float(row: Dictionary, key: String) -> float:
		var s := field_str(row, key)
		if s.is_empty():
			return 0.0
		if s.is_valid_float():
			return s.to_float()
		push_warning("[DataModels] 字段 \"%s\" 非法数值 \"%s\"，取默认值 0.0" % [key, s])
		return 0.0

	## 布尔字段（如 summon_pool.gold）：true/1/yes/y/是 → true，false/0/no/n/否 → false；
	## 空值/缺键 → false；非法值警告后取 false，不中断
	static func field_bool(row: Dictionary, key: String) -> bool:
		var s := field_str(row, key).to_lower()
		if s.is_empty():
			return false
		if s in ["true", "1", "yes", "y", "是"]:
			return true
		if s in ["false", "0", "no", "n", "否"]:
			return false
		push_warning("[DataModels] 字段 \"%s\" 非法布尔值 \"%s\"，取默认值 false" % [key, s])
		return false


## ------------------------------------------------------------
## 觉醒者数据（characters.csv 一行）
## faction ∈ 机律联邦·秘法评议会·太微仙盟；system ∈ 机律|秘法|玄门
## ------------------------------------------------------------
class CharacterData extends BaseRow:

	const SYSTEM_NAMES := {
		"机律": "机律", "秘法": "秘法", "玄门": "玄门",
		"mech": "机律", "arcane": "秘法", "xian": "玄门",
	}
	const FACTION_NAMES := {
		"机律联邦": "机律联邦", "秘法评议会": "秘法评议会", "太微仙盟": "太微仙盟",
		"mech": "机律联邦", "arcane": "秘法评议会", "xian": "太微仙盟",
	}

	var id: String = ""
	var name: String = ""
	var faction: String = ""
	var system: String = ""
	var hp: int = 0
	var atk: int = 0
	var def: int = 0
	var spd: int = 0
	var skill_small: String = ""
	var skill_ult: String = ""
	var portrait_id: String = ""
	var sprite_id: String = ""

	static func from_csv_row(row: Dictionary) -> CharacterData:
		var d := CharacterData.new()
		d.id = BaseRow.field_str(row, "id")
		d.name = BaseRow.field_str(row, "name")
		d.faction = BaseRow.field_str(row, "faction")
		d.system = BaseRow.field_str(row, "system")
		d.hp = BaseRow.field_int(row, "hp")
		d.atk = BaseRow.field_int(row, "atk")
		d.def = BaseRow.field_int(row, "def")
		d.spd = BaseRow.field_int(row, "spd")
		d.skill_small = BaseRow.field_str(row, "skill_small")
		d.skill_ult = BaseRow.field_str(row, "skill_ult")
		d.portrait_id = BaseRow.field_str(row, "portrait_id")
		d.sprite_id = BaseRow.field_str(row, "sprite_id")
		return d

	## 体系中文名：机律/秘法/玄门（兼容代码输入，未知值原样返回并警告）
	func system_name() -> String:
		var key := system.strip_edges()
		if SYSTEM_NAMES.has(key):
			return SYSTEM_NAMES[key]
		push_warning("[DataModels] CharacterData.system 未知取值 \"%s\"（id=%s）" % [key, id])
		return key

	## 阵营中文名：机律联邦/秘法评议会/太微仙盟（兼容代码输入，未知值原样返回并警告）
	func faction_name() -> String:
		var key := faction.strip_edges()
		if FACTION_NAMES.has(key):
			return FACTION_NAMES[key]
		push_warning("[DataModels] CharacterData.faction 未知取值 \"%s\"（id=%s）" % [key, id])
		return key

	func _to_string() -> String:
		return "CharacterData{id=%s, name=%s, faction=%s, system=%s, hp=%d, atk=%d, def=%d, spd=%d, skill_small=%s, skill_ult=%s, portrait_id=%s, sprite_id=%s}" % [
			id, name, faction, system, hp, atk, def, spd, skill_small, skill_ult, portrait_id, sprite_id,
		]


## ------------------------------------------------------------
## 技能数据（skills.csv 一行）；type ∈ small|ult
## 战斗为大招充能制（战斗系统 §3：小技能无消耗、大招需充能满），
## 无耗能字段；power = 倍率（damage = max(1, atk*power - def)）
## ------------------------------------------------------------
class SkillData extends BaseRow:

	var id: String = ""
	var name: String = ""
	var type: String = ""
	var power: float = 0.0
	var cutscene_id: String = ""

	static func from_csv_row(row: Dictionary) -> SkillData:
		var d := SkillData.new()
		d.id = BaseRow.field_str(row, "id")
		d.name = BaseRow.field_str(row, "name")
		d.type = BaseRow.field_str(row, "type")
		d.power = BaseRow.field_float(row, "power")
		d.cutscene_id = BaseRow.field_str(row, "cutscene_id")
		return d

	func _to_string() -> String:
		return "SkillData{id=%s, name=%s, type=%s, power=%.2f, cutscene_id=%s}" % [
			id, name, type, power, cutscene_id,
		]


## ------------------------------------------------------------
## 敌人数据（enemies.csv 一行）；drop_sand = 掉落星砂数量
## skill_small/skill_ult → skills.csv 敌人技能行（战斗系统 §3：敌人同有小技能/大招）
## ------------------------------------------------------------
class EnemyData extends BaseRow:

	var id: String = ""
	var name: String = ""
	var hp: int = 0
	var atk: int = 0
	var def: int = 0
	var spd: int = 0
	var ai_pattern: String = ""
	var drop_sand: int = 0
	var skill_small: String = ""
	var skill_ult: String = ""

	static func from_csv_row(row: Dictionary) -> EnemyData:
		var d := EnemyData.new()
		d.id = BaseRow.field_str(row, "id")
		d.name = BaseRow.field_str(row, "name")
		d.hp = BaseRow.field_int(row, "hp")
		d.atk = BaseRow.field_int(row, "atk")
		d.def = BaseRow.field_int(row, "def")
		d.spd = BaseRow.field_int(row, "spd")
		d.ai_pattern = BaseRow.field_str(row, "ai_pattern")
		d.drop_sand = BaseRow.field_int(row, "drop_sand")
		d.skill_small = BaseRow.field_str(row, "skill_small")
		d.skill_ult = BaseRow.field_str(row, "skill_ult")
		return d

	func _to_string() -> String:
		return "EnemyData{id=%s, name=%s, hp=%d, atk=%d, def=%d, spd=%d, ai_pattern=%s, drop_sand=%d, skill_small=%s, skill_ult=%s}" % [
			id, name, hp, atk, def, spd, ai_pattern, drop_sand, skill_small, skill_ult,
		]


## ------------------------------------------------------------
## 星髓数据（stellium.csv 一行）；套装×槽位制（星髓系统.md §2~§4），无稀有度
## (set_id, slot) 唯一确定星髓类型；slot 1-3 主词条固定（atk/def/hp），
## slot 4-6 主词条为随机池：main_stat 与 main_base/main_max 均为 `|` 分隔串，
## 三者按位一一对应（如 crit|crit_dmg|pct_atk 与 5|8|6 / 12|20|15）。
## 百分比词条（pct_*/crit/crit_dmg/charge）数值单位 = 百分点（6 即 +6%）；
## set_2_bonus/set_3_bonus 格式 "attr:value;attr:value"（cond_dmg 值形如 hp>70%,50）
## ------------------------------------------------------------
class StelliumData extends BaseRow:

	var id: String = ""
	var name: String = ""
	var set_id: String = ""
	var set_name: String = ""
	var slot: int = 0
	var main_stat: String = ""
	var main_base: String = ""
	var main_max: String = ""
	var set_2_bonus: String = ""
	var set_3_bonus: String = ""

	static func from_csv_row(row: Dictionary) -> StelliumData:
		var d := StelliumData.new()
		d.id = BaseRow.field_str(row, "id")
		d.name = BaseRow.field_str(row, "name")
		d.set_id = BaseRow.field_str(row, "set_id")
		d.set_name = BaseRow.field_str(row, "set_name")
		d.slot = BaseRow.field_int(row, "slot")
		d.main_stat = BaseRow.field_str(row, "main_stat")
		d.main_base = BaseRow.field_str(row, "main_base")
		d.main_max = BaseRow.field_str(row, "main_max")
		d.set_2_bonus = BaseRow.field_str(row, "set_2_bonus")
		d.set_3_bonus = BaseRow.field_str(row, "set_3_bonus")
		return d

	func _to_string() -> String:
		return "StelliumData{id=%s, name=%s, set_id=%s, set_name=%s, slot=%d, main_stat=%s, main_base=%s, main_max=%s, set_2_bonus=%s, set_3_bonus=%s}" % [
			id, name, set_id, set_name, slot, main_stat, main_base, main_max, set_2_bonus, set_3_bonus,
		]


## ------------------------------------------------------------
## 抽卡池条目（summon_pool.csv 一行）
## kind ∈ starlink_token/cg/material/stellium/stellium_material
## gold = 是否稀有金卡（星缘令/角色 CG）；weight = 抽取权重
## ------------------------------------------------------------
class SummonEntryData extends BaseRow:

	var entry_id: String = ""
	var name: String = ""
	var kind: String = ""
	var gold: bool = false
	var weight: float = 0.0

	static func from_csv_row(row: Dictionary) -> SummonEntryData:
		var d := SummonEntryData.new()
		d.entry_id = BaseRow.field_str(row, "entry_id")
		d.name = BaseRow.field_str(row, "name")
		d.kind = BaseRow.field_str(row, "kind")
		d.gold = BaseRow.field_bool(row, "gold")
		d.weight = BaseRow.field_float(row, "weight")
		return d

	func _to_string() -> String:
		return "SummonEntryData{entry_id=%s, name=%s, kind=%s, gold=%s, weight=%.4f}" % [
			entry_id, name, kind, str(gold), weight,
		]


## ------------------------------------------------------------
## 心契任务步骤（quests.csv 一行 = 一个任务的某一步）
## requirement/target 为占位 id，next_step 指向下一步（末步为空）
## ------------------------------------------------------------
class QuestData extends BaseRow:

	var quest_id: String = ""
	var step: int = 0
	var step_name: String = ""
	var requirement: String = ""
	var target: String = ""
	var reward: String = ""
	var next_step: String = ""

	static func from_csv_row(row: Dictionary) -> QuestData:
		var d := QuestData.new()
		d.quest_id = BaseRow.field_str(row, "quest_id")
		d.step = BaseRow.field_int(row, "step")
		d.step_name = BaseRow.field_str(row, "step_name")
		d.requirement = BaseRow.field_str(row, "requirement")
		d.target = BaseRow.field_str(row, "target")
		d.reward = BaseRow.field_str(row, "reward")
		d.next_step = BaseRow.field_str(row, "next_step")
		return d

	func _to_string() -> String:
		return "QuestData{quest_id=%s, step=%d, step_name=%s, requirement=%s, target=%s, reward=%s, next_step=%s}" % [
			quest_id, step, step_name, requirement, target, reward, next_step,
		]
