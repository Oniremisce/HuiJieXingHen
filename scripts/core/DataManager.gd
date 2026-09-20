## =============================================================
## 《汇界星痕》T0.3 DataManager（Autoload 单例）
## -------------------------------------------------------------
## 启动时加载 data/csv/ 全部配表到内存索引，提供查询接口。
## 新增表：只需在 _load_all() 注册路径与模型构造，不污染业务代码。
## 数据模型见 scripts/core/data_models.gd（推进表 §2.3）。
## =============================================================
extends Node

const CSV_DIR := "res://data/csv"
const CSVParserLib := preload("res://scripts/core/CSVParser.gd")
const DM := preload("res://scripts/core/data_models.gd")
const LS := preload("res://scripts/core/level_system.gd")

var _characters: Dictionary = {}   # id -> CharacterData
var _skills: Dictionary = {}       # id -> SkillData
var _enemies: Dictionary = {}      # id -> EnemyData
var _stelliums: Dictionary = {}    # id -> StelliumData
var _summon_pool: Array = []       # Array[SummonEntryData]
var _quests: Dictionary = {}       # quest_id -> Array[QuestData]（按 step 升序）
var _dialogues: Dictionary = {}    # timeline_id -> Array[Dictionary]（按 order 升序）
var _level_growth: Dictionary = {} # T2.11 system英文代号 -> {hp,atk,def,spd} 成长值

func _ready() -> void:
	_load_all()
	_print_report()


## ------------------------------------------------------------
## 加载管线
## ------------------------------------------------------------
func _load_all() -> void:
	for row in CSVParserLib.parse(CSV_DIR + "/characters.csv"):
		var c: DM.CharacterData = DM.CharacterData.from_csv_row(row)
		_characters[c.id] = c

	# T2.11 成长值表：按体系英文代号 mech/arcane/xian 读入并注入各角色 CharacterData.growth
	_load_level_growth()
	_inject_growth()

	for row in CSVParserLib.parse(CSV_DIR + "/skills.csv"):
		var s: DM.SkillData = DM.SkillData.from_csv_row(row)
		_skills[s.id] = s

	for row in CSVParserLib.parse(CSV_DIR + "/enemies.csv"):
		var e: DM.EnemyData = DM.EnemyData.from_csv_row(row)
		_enemies[e.id] = e

	for row in CSVParserLib.parse(CSV_DIR + "/stellium.csv"):
		var st: DM.StelliumData = DM.StelliumData.from_csv_row(row)
		_stelliums[st.id] = st

	for row in CSVParserLib.parse(CSV_DIR + "/summon_pool.csv"):
		_summon_pool.append(DM.SummonEntryData.from_csv_row(row))

	# 任务步骤：按 quest_id 分组
	for row in CSVParserLib.parse(CSV_DIR + "/quests.csv"):
		var q: DM.QuestData = DM.QuestData.from_csv_row(row)
		if not _quests.has(q.quest_id):
			_quests[q.quest_id] = []
		_quests[q.quest_id].append(q)
	for quest_id in _quests:
		_quests[quest_id].sort_custom(func(a, b): return a.step < b.step)

	# 台词表：跨文件按 timeline_id 汇总，行保留原始 Dictionary
	_load_dialogues("dialogues_main_01.csv")
	_load_dialogues("dialogues_npc_chat.csv")
	for timeline_id in _dialogues:
		_dialogues[timeline_id].sort_custom(func(a, b): return int(a.get("order", "0")) < int(b.get("order", "0")))


## 台词表登记：新章节/新闲聊表在此追加一行即可
func _load_dialogues(file_name: String) -> void:
	for row in CSVParserLib.parse(CSV_DIR + "/" + file_name):
		var timeline_id: String = str(row.get("timeline_id", ""))
		if timeline_id.is_empty():
			continue
		if not _dialogues.has(timeline_id):
			_dialogues[timeline_id] = []
		_dialogues[timeline_id].append(row)


## T2.11 成长值表加载：system英文代号 -> {hp,atk,def,spd}
func _load_level_growth() -> void:
	_level_growth.clear()
	for row in CSVParserLib.parse(CSV_DIR + "/level_growth.csv"):
		var code := str(row.get("system", "")).strip_edges()
		if code.is_empty():
			continue
		_level_growth[code] = {
			"hp": _growth_int(row, "hp_growth"),
			"atk": _growth_int(row, "atk_growth"),
			"def": _growth_int(row, "def_growth"),
			"spd": _growth_int(row, "spd_growth"),
		}

## T2.11 注入成长值：按角色 system 英文代号查表写入 CharacterData.growth
func _inject_growth() -> void:
	for id: Variant in _characters:
		var ch: DM.CharacterData = _characters[id]
		var code := ch.system_code()
		if _level_growth.has(code):
			ch.growth = _level_growth[code]

func _growth_int(row: Dictionary, key: String) -> int:
	var s := str(row.get(key, "0")).strip_edges()
	return s.to_int() if s.is_valid_int() else 0


func _print_report() -> void:
	var quest_tasks := _quests.size()
	var quest_steps := 0
	for quest_id in _quests:
		quest_steps += (_quests[quest_id] as Array).size()
	var dialogue_detail := PackedStringArray()
	for timeline_id in _dialogues:
		dialogue_detail.append("%s=%d" % [timeline_id, (_dialogues[timeline_id] as Array).size()])
	print("[DataManager] 加载完成：characters=%d, skills=%d, enemies=%d, stellium=%d, summon_pool=%d, quests=%d 步/%d 任务, dialogues(%s)" % [
		_characters.size(), _skills.size(), _enemies.size(), _stelliums.size(),
		_summon_pool.size(), quest_steps, quest_tasks, " ".join(dialogue_detail),
	])
	# 自检：验收项 get_character("awakened_mech_01") 字段完整正确
	var self_check: DM.CharacterData = get_character("awakened_mech_01")
	if self_check != null:
		print("[DataManager] 自检 get_character(\"awakened_mech_01\") -> ", self_check)
	else:
		push_error("[DataManager] 自检失败：get_character(\"awakened_mech_01\") 返回 null")


## ------------------------------------------------------------
## 查询接口（找不到时警告并返回 null/空，不崩溃）
## ------------------------------------------------------------
func get_character(id: String) -> DM.CharacterData:
	return _lookup(_characters, id, "character")


## 全部角色 id（T2.5 角色列表遍历用；CSV 增行自动纳入）
func get_character_ids() -> Array:
	return _characters.keys()

## T2.11 成长值查询（供面板/战斗属性预览用；未知代号返回空字典）
func get_level_growth(code: String) -> Dictionary:
	if _level_growth.has(code):
		return _level_growth[code]
	return {}

## T2.11 存档回填：data 形如 {char_id: [level, exp]}，逐角色写入 level/exp
## 先全量复位 level=1/exp=0 再回填（version=1 无 character_progress → 兜底 1/0）
func apply_character_progress(data: Dictionary) -> void:
	for id: Variant in _characters:
		var any_ch: DM.CharacterData = _characters[id]
		any_ch.level = 1
		any_ch.exp = 0
	for id: Variant in data:
		var ch := get_character(str(id))
		if ch == null:
			continue
		var pair: Variant = data[id]
		if pair is Array and pair.size() >= 2:
			ch.level = int(pair[0])
			ch.exp = int(pair[1])

## T2.11 存档序列化：汇总各角色 level/exp -> {char_id: [level, exp]}
func get_character_progress() -> Dictionary:
	var out := {}
	for id: Variant in _characters:
		var ch: DM.CharacterData = _characters[id]
		out[id] = [ch.level, ch.exp]
	return out

## T2.11 升级接口：累计经验并结算升级（溢出结转/多级连升/封顶），返回最终等级
## TODO T3.12 收工后：battle_finished 结算链按 EXP_PER_ENEMY × 击杀数调用本接口发放战斗经验
func add_exp(character_id: String, amount: int) -> int:
	var ch := get_character(character_id)
	if ch == null:
		return 1
	return LS.add_exp(ch, amount)

func level_up(character_id: String) -> int:
	var ch := get_character(character_id)
	if ch == null:
		return 1
	return LS.level_up(ch)

func get_skill(id: String) -> DM.SkillData:
	return _lookup(_skills, id, "skill")

func get_enemy(id: String) -> DM.EnemyData:
	return _lookup(_enemies, id, "enemy")

func get_stellium(id: String) -> DM.StelliumData:
	return _lookup(_stelliums, id, "stellium")

## 抽卡池全量条目（gold/weight 供 P6 唤星加权抽取）
func get_summon_pool() -> Array:
	return _summon_pool

## 指定任务的全部步骤（按 step 升序），如 get_quest("heartbond_01") -> 4 步
func get_quest(quest_id: String) -> Array:
	if _quests.has(quest_id):
		return _quests[quest_id]
	push_warning("[DataManager] 未找到任务 \"%s\"" % quest_id)
	return []


## 全部任务 id（T2.5 任务面板遍历用；CSV 增任务自动纳入）
func get_quest_ids() -> Array:
	return _quests.keys()

## 指定任务的某一步
func get_quest_step(quest_id: String, step: int) -> DM.QuestData:
	for q in get_quest(quest_id):
		if (q as DM.QuestData).step == step:
			return q
	push_warning("[DataManager] 任务 \"%s\" 不存在步骤 %d" % [quest_id, step])
	return null

## 指定 timeline 的全部台词行（按 order 升序，原始 Dictionary）
func get_dialogue_rows(timeline_id: String) -> Array:
	if _dialogues.has(timeline_id):
		return _dialogues[timeline_id]
	push_warning("[DataManager] 未找到台词 timeline \"%s\"" % timeline_id)
	return []


func _lookup(table: Dictionary, id: String, kind: String) -> Variant:
	if table.has(id):
		return table[id]
	push_warning("[DataManager] 未找到 %s \"%s\"" % [kind, id])
	return null
