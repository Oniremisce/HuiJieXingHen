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

var _characters: Dictionary = {}   # id -> CharacterData
var _skills: Dictionary = {}       # id -> SkillData
var _enemies: Dictionary = {}      # id -> EnemyData
var _stelliums: Dictionary = {}    # id -> StelliumData
var _summon_pool: Array = []       # Array[SummonEntryData]
var _quests: Dictionary = {}       # quest_id -> Array[QuestData]（按 step 升序）
var _dialogues: Dictionary = {}    # timeline_id -> Array[Dictionary]（按 order 升序）

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
