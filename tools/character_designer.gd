## =============================================================
## 《汇界星痕》T2.10 角色设计器（docs/系统规则/角色系统.md §7 · headless 可跑）
## -------------------------------------------------------------
## 用途：每次角色 CSV 变更后跑一次——校验 characters.csv / skills.csv 全行合规，
##   再对 DataManager 加载结果与 ArtProvider 占位纹理做冒烟，逐项 PASS/FAIL 输出，
##   EXIT=0（全通过）/ EXIT=1（存在 FAIL），供 CI 与人读。
## 运行：
##   GODOT_MCP_RUNTIME_PORT=abc godot --headless --path . --script res://tools/character_designer.gd
## 可选环境变量 CHAR_DESIGNER_CSV_DIR（res:// 或绝对路径）：
##   仅替换「校验」读取的 CSV 目录（坏数据注入 / CI 回归用，不改仓库数据）；
##   覆盖模式下冒烟段跳过（DataManager 恒读 res://data/csv，两份数据非同一源）。
## 校验口径（与制作人04 预裁定一致）：
##   ① 体系映射 机律=mech / 秘法=arcane / 玄门=xian：id 只认英文体系段
##      awakened_<mech|arcane|xian>_<两位序号>；characters.system 列按中文三值
##      白名单单独校验，两者不通兑（不可用英文校验中文列，反之亦然）。
##   ② skills.csv 中 enemy_ 前缀行不套 skill_<体系>_<s1|ult> 规则：仅校验
##      列数 / 枚举 / id 唯一性，cutscene_id 允许空。
##   ③ portrait/sprite 资源存在性不做文件名猜测（portrait_mech_01 是逻辑 id 非文件名），
##      统一以角色 id 走 ArtProvider 取纹理做非空判定；真实资源接入后同一判定仍成立。
##   ④ 数值边界（数值策划01 T2.10 协作行口径④）：hp/atk/def/spd 正整数（≥1）；
##      power>0；effect=amp 时 power 须为正整数百分点（30 即 +30%）。
## 报告格式：FAIL 明细恒含「文件:行号 列[列名] 说明」，CI 可直接定位。
## 与 tools/smoke_test_data_models.gd 互补：后者断言数据模型结构，本工具断言角色内容合规。
## =============================================================
extends SceneTree

const DEFAULT_CSV_DIR := "res://data/csv"
const CHARS_FILE := "characters.csv"
const SKILLS_FILE := "skills.csv"

## 列契约（角色系统.md §2 / §3）
const CHAR_COLUMNS: Array[String] = [
	"id", "name", "faction", "system", "hp", "atk", "def", "spd",
	"skill_small", "skill_ult", "portrait_id", "sprite_id", "background",
]
const SKILL_COLUMNS: Array[String] = [
	"id", "name", "type", "power", "cutscene_id", "target_side", "target_scope", "effect",
]

## 体系映射表（预裁定①）
const SYSTEM_CN := ["机律", "秘法", "玄门"]
const SYSTEM_CN_TO_EN := {"机律": "mech", "秘法": "arcane", "玄门": "xian"}

## 枚举白名单（target_side/target_scope/effect 的空值按 §3 缺省回退，不算错）
const TYPE_WHITELIST := ["small", "ult"]
const SIDE_WHITELIST := ["enemy", "ally"]
const SCOPE_WHITELIST := ["single", "column", "all"]
const EFFECT_WHITELIST := ["damage", "heal", "shield", "amp"]
const SIDE_DEFAULT := "enemy"
const SCOPE_DEFAULT := "single"
const EFFECT_DEFAULT := "damage"
const ENEMY_SKILL_PREFIX := "enemy_"

var _csv_dir := DEFAULT_CSV_DIR
var _override := false
var _pass_count := 0
var _fail_list: Array[String] = []
var _re_char_id: RegEx
var _re_skill_id: RegEx


func _initialize() -> void:
	# autoload（DataManager/ArtProvider）在 --script 模式照常加载，deferred 后即可用（T3.7 实证）
	_run.call_deferred()


func _run() -> void:
	_re_char_id = RegEx.new()
	_re_char_id.compile("^awakened_(mech|arcane|xian)_\\d{2}$")
	_re_skill_id = RegEx.new()
	_re_skill_id.compile("^skill_(mech|arcane|xian)_(s1|ult)$")

	_csv_dir = OS.get_environment("CHAR_DESIGNER_CSV_DIR").strip_edges()
	if _csv_dir.is_empty():
		_csv_dir = DEFAULT_CSV_DIR
	else:
		_override = true

	print("=== T2.10 角色设计器 · 报告（角色系统.md §7）===")
	print("[源] 校验目录 = %s %s" % [
		_csv_dir,
		"（CHAR_DESIGNER_CSV_DIR 覆盖 → 冒烟段跳过）" if _override else "（校验与冒烟同源）",
	])

	var skills := _read_csv(_csv_dir + "/" + SKILLS_FILE)
	var chars := _read_csv(_csv_dir + "/" + CHARS_FILE)

	_section("1/4 skills.csv 结构校验")
	_check_header(SKILLS_FILE, skills, SKILL_COLUMNS)
	var skill_map := _validate_skills(skills)

	_section("2/4 characters.csv 结构校验与引用检查")
	_check_header(CHARS_FILE, chars, CHAR_COLUMNS)
	_validate_characters(chars, skill_map)

	_section("3/4 冒烟：DataManager 加载断言 + ArtProvider 占位非空")
	_run_smoke(chars, skill_map)

	_section("4/4 汇总")
	for line in _fail_list:
		print(line)
	if _fail_list.is_empty():
		print("[PASS] 通过 %d 项，失败 0 项" % _pass_count)
		print("EXIT=0")
		quit(0)
	else:
		print("[FAIL] 通过 %d 项，失败 %d 项（明细见上，格式 文件:行号 列[列名]）" % [_pass_count, _fail_list.size()])
		print("EXIT=1")
		quit(1)


# ---------------------------------------------------------------
# 报告工具
# ---------------------------------------------------------------

func _section(title: String) -> void:
	print("\n--- %s ---" % title)


func _pass(text: String) -> void:
	_pass_count += 1
	print("[PASS] %s" % text)


func _fail(detail: String) -> void:
	_fail_list.append("FAIL " + detail)
	print("[FAIL] %s" % detail)


# ---------------------------------------------------------------
# CSV 读取（保留物理行号；引号内逗号/换行按 CSV 规范处理）
# 返回 {ok, header: Array[String], header_line: int, rows: Array[{line, fields}]}
# ---------------------------------------------------------------

func _read_csv(path: String) -> Dictionary:
	var out := {"ok": false, "header": [] as Array[String], "header_line": 1, "rows": []}
	if not FileAccess.file_exists(path):
		_fail("%s:0 列[(文件)] 文件不存在：%s" % [path.get_file(), path])
		return out
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		_fail("%s:0 列[(文件)] 文件为空：%s" % [path.get_file(), path])
		return out
	if text.begins_with("\ufeff"):
		text = text.substr(1)
	out["ok"] = true

	var header: Array[String] = []
	var fields: Array[String] = []
	var field := ""
	var in_quotes := false
	var line := 1
	var record_line := 1
	var i := 0
	var n := text.length()
	while i < n:
		var ch := text[i]
		if in_quotes:
			if ch == "\"":
				if i + 1 < n and text[i + 1] == "\"":
					field += "\""
					i += 1
				else:
					in_quotes = false
			elif ch == "\n":
				field += "\n"
				line += 1
			elif ch == "\r":
				if i + 1 < n and text[i + 1] == "\n":
					i += 1
				field += "\n"
				line += 1
			else:
				field += ch
		else:
			if ch == "\"":
				in_quotes = true
			elif ch == ",":
				fields.append(field)
				field = ""
			elif ch == "\n" or ch == "\r":
				if ch == "\r" and i + 1 < n and text[i + 1] == "\n":
					i += 1
				fields.append(field)
				field = ""
				line += 1
				_flush_record(out, header, fields, record_line)
				fields = []
				record_line = line
			else:
				field += ch
		i += 1
	if not field.is_empty() or not fields.is_empty():
		if in_quotes:
			_fail("%s:%d 列[(文件)] 双引号未闭合" % [path.get_file(), record_line])
		else:
			fields.append(field)
			_flush_record(out, header, fields, record_line)
	return out


func _flush_record(out: Dictionary, header: Array[String], fields: Array[String], line_no: int) -> void:
	if fields.size() == 1 and fields[0].strip_edges().is_empty():
		return
	if header.is_empty():
		header.append_array(fields)
		out["header"] = header
		out["header_line"] = line_no
		return
	out["rows"].append({"line": line_no, "fields": fields})


func _field(row: Dictionary, header: Array, col: String) -> String:
	var idx := header.find(col)
	var fields: Array = row["fields"]
	if idx < 0 or idx >= fields.size():
		return ""
	return str(fields[idx]).strip_edges()


func _field_int(row: Dictionary, header: Array, col: String) -> int:
	var s := _field(row, header, col)
	return s.to_int() if s.is_valid_int() else 0


func _field_float(row: Dictionary, header: Array, col: String) -> float:
	var s := _field(row, header, col)
	return s.to_float() if s.is_valid_float() else 0.0


## 表头契约检查（列数 + 缺列 + 多列）
func _check_header(file_name: String, parsed: Dictionary, expected: Array[String]) -> void:
	var header: Array = parsed.get("header", [])
	var line_no := int(parsed.get("header_line", 1))
	if not parsed.get("ok", false):
		return
	if header.size() != expected.size():
		_fail("%s:%d 列[(表头)] 列数 %d 与契约 %d 列不符（契约：%s）" % [
			file_name, line_no, header.size(), expected.size(), ",".join(expected)])
	var missing: Array[String] = []
	for col in expected:
		if not (col in header):
			missing.append(col)
	if not missing.is_empty():
		_fail("%s:%d 列[%s] 表头缺列（契约见 docs/系统规则/角色系统.md §2/§3）" % [
			file_name, line_no, ",".join(missing)])
	var extra: Array[String] = []
	for col in header:
		if not (col in expected):
			extra.append(str(col))
	if not extra.is_empty():
		_fail("%s:%d 列[%s] 表头多列（不在角色系统.md 契约内）" % [file_name, line_no, ",".join(extra)])
	if missing.is_empty() and extra.is_empty() and header.size() == expected.size():
		_pass("%s 表头契约齐备（%d 列，第 %d 行）" % [file_name, expected.size(), line_no])


## 枚举检查；allow_default 非空表示空值按该缺省回退（合法）
func _enum_check(file_name: String, line_no: int, col: String, value: String,
		whitelist: Array, allow_default: String) -> void:
	if value.is_empty():
		if allow_default.is_empty():
			_fail("%s:%d 列[%s] 为空（必填，允许值：%s）" % [file_name, line_no, col, "/".join(whitelist)])
		else:
			_pass_count += 1  # 缺省回退（§3），合法
		return
	if value in whitelist:
		_pass_count += 1
		return
	_fail("%s:%d 列[%s] 非法枚举 \"%s\"（允许：%s）" % [file_name, line_no, col, value, "/".join(whitelist)])


func _is_positive_int(s: String) -> bool:
	return s.is_valid_int() and s.to_int() > 0


## power 数值边界（口径④）：>0 浮点；effect=amp 时须正整数百分点
func _check_power(file_name: String, line_no: int, power_s: String, effect: String) -> void:
	if not power_s.is_valid_float():
		_fail("%s:%d 列[power] 非数值 \"%s\"（须 >0：damage/heal/shield=倍率系数，amp=增伤百分点）" % [
			file_name, line_no, power_s])
	elif power_s.to_float() <= 0.0:
		_fail("%s:%d 列[power] 须 >0，实为 \"%s\"" % [file_name, line_no, power_s])
	elif effect == "amp" and not _is_positive_int(power_s):
		_fail("%s:%d 列[power] effect=amp 时须为正整数百分点（如 30 即 +30%%），实为 \"%s\"" % [
			file_name, line_no, power_s])
	else:
		_pass_count += 1


# ---------------------------------------------------------------
# skills.csv 校验；返回 id -> {line, row, header}（供角色引用检查与冒烟回读）
# ---------------------------------------------------------------

func _validate_skills(parsed: Dictionary) -> Dictionary:
	var header: Array = parsed.get("header", [])
	var rows: Array = parsed.get("rows", [])
	var seen := {}
	var map := {}
	var checked := 0
	for row in rows:
		var line_no := int(row["line"])
		var fields: Array = row["fields"]
		if fields.size() != header.size():
			_fail("%s:%d 列[(行)] 列数 %d 与表头 %d 不符" % [SKILLS_FILE, line_no, fields.size(), header.size()])
			continue
		var sid := _field(row, header, "id")
		if sid.is_empty():
			_fail("%s:%d 列[id] 为空（技能 id 必填）" % [SKILLS_FILE, line_no])
		elif seen.has(sid):
			_fail("%s:%d 列[id] 重复技能 id \"%s\"（首见第 %d 行）" % [SKILLS_FILE, line_no, sid, seen[sid]])
		else:
			seen[sid] = line_no
			_pass_count += 1
		_enum_check(SKILLS_FILE, line_no, "type", _field(row, header, "type"), TYPE_WHITELIST, "")
		_enum_check(SKILLS_FILE, line_no, "target_side", _field(row, header, "target_side"), SIDE_WHITELIST, SIDE_DEFAULT)
		_enum_check(SKILLS_FILE, line_no, "target_scope", _field(row, header, "target_scope"), SCOPE_WHITELIST, SCOPE_DEFAULT)
		_enum_check(SKILLS_FILE, line_no, "effect", _field(row, header, "effect"), EFFECT_WHITELIST, EFFECT_DEFAULT)
		# §3：column（整列）仅敌方，ally 侧只用 single/all
		var side := _skill_effective(row, header, "target_side", SIDE_DEFAULT)
		var scope := _skill_effective(row, header, "target_scope", SCOPE_DEFAULT)
		if side == "ally" and scope == "column":
			_fail("%s:%d 列[target_scope] ally 侧不适用 column（§3：column 仅敌方、上限 3）" % [SKILLS_FILE, line_no])
		else:
			_pass_count += 1
		_check_power(SKILLS_FILE, line_no, _field(row, header, "power"),
			_skill_effective(row, header, "effect", EFFECT_DEFAULT))
		if sid.begins_with(ENEMY_SKILL_PREFIX):
			_pass_count += 1  # 预裁定②：enemy_ 前缀行豁免 id 命名/type 配对/cutscene 约定
		else:
			_validate_character_skill_id(row, header, sid, line_no)
		map[sid] = {"line": line_no, "row": row, "header": header}
		checked += 1
	_pass("%s 数据行 %d 行：列数/枚举/id 唯一性/命名与 cutscene 约定逐行检查完成" % [SKILLS_FILE, checked])
	return map


## 角色技能 id 规则 + type 配对 + cutscene 约定（§3）
func _validate_character_skill_id(row: Dictionary, header: Array, sid: String, line_no: int) -> void:
	var m := _re_skill_id.search(sid)
	if m == null:
		_fail("%s:%d 列[id] 非法角色技能 id \"%s\"（契约 skill_<mech|arcane|xian>_<s1|ult>；敌人技能用 enemy_ 前缀）" % [
			SKILLS_FILE, line_no, sid])
		return
	var en := m.get_string(1)
	var suffix := m.get_string(2)
	var expect_type := "small" if suffix == "s1" else "ult"
	var type_value := _field(row, header, "type")
	if type_value != expect_type:
		_fail("%s:%d 列[type] id 段 \"%s\" 要求 type=%s，实为 \"%s\"" % [SKILLS_FILE, line_no, suffix, expect_type, type_value])
	var cut := _field(row, header, "cutscene_id")
	if suffix == "s1":
		if not cut.is_empty():
			_fail("%s:%d 列[cutscene_id] 小技能须留空（§3 约定），实为 \"%s\"" % [SKILLS_FILE, line_no, cut])
		else:
			_pass_count += 1
	else:
		var expect_cut := "cut_%s_ult" % en
		if cut != expect_cut:
			_fail("%s:%d 列[cutscene_id] 应为 \"%s\"（§3 约定 cut_<体系>_ult），实为 \"%s\"" % [SKILLS_FILE, line_no, expect_cut, cut])
		else:
			_pass_count += 1


## 技能三字段取值（空 → 规则缺省，§3）
func _skill_effective(row: Dictionary, header: Array, col: String, default_value: String) -> String:
	var v := _field(row, header, col)
	return default_value if v.is_empty() else v


# ---------------------------------------------------------------
# characters.csv 校验（id 规则 / system 枚举 / 技能引用 / 占位资源）
# ---------------------------------------------------------------

func _validate_characters(parsed: Dictionary, skill_map: Dictionary) -> void:
	var header: Array = parsed.get("header", [])
	var rows: Array = parsed.get("rows", [])
	var art: Node = root.get_node_or_null("ArtProvider")
	var seen := {}
	var checked := 0
	for row in rows:
		var line_no := int(row["line"])
		var fields: Array = row["fields"]
		if fields.size() != header.size():
			_fail("%s:%d 列[(行)] 列数 %d 与表头 %d 不符" % [CHARS_FILE, line_no, fields.size(), header.size()])
			continue
		var cid := _field(row, header, "id")
		if _re_char_id.search(cid) == null:
			_fail("%s:%d 列[id] 非法角色 id \"%s\"（契约 awakened_<mech|arcane|xian>_<两位序号>，预裁定①）" % [
				CHARS_FILE, line_no, cid])
		else:
			_pass_count += 1
		if seen.has(cid):
			_fail("%s:%d 列[id] 重复角色 id \"%s\"（首见第 %d 行）" % [CHARS_FILE, line_no, cid, seen[cid]])
		else:
			seen[cid] = line_no
		var sys_cn := _field(row, header, "system")
		if sys_cn in SYSTEM_CN:
			_pass_count += 1
		else:
			_fail("%s:%d 列[system] 非法体系 \"%s\"（中文三值白名单：%s；预裁定①：与 id 英文段各自校验）" % [
				CHARS_FILE, line_no, sys_cn, "/".join(SYSTEM_CN)])
		var en := str(SYSTEM_CN_TO_EN.get(sys_cn, ""))
		# 四维数值边界（口径④）：正整数 ≥1
		for stat in ["hp", "atk", "def", "spd"]:
			var v := _field(row, header, stat)
			if _is_positive_int(v):
				_pass_count += 1
			else:
				_fail("%s:%d 列[%s] 须为正整数（≥1），实为 \"%s\"" % [CHARS_FILE, line_no, stat, v])
		_check_skill_ref(row, header, line_no, cid, en, "skill_small", "s1", "small", skill_map)
		_check_skill_ref(row, header, line_no, cid, en, "skill_ult", "ult", "ult", skill_map)
		_check_art(row, header, line_no, cid, art, "portrait_id", true)
		_check_art(row, header, line_no, cid, art, "sprite_id", false)
		checked += 1
	_pass("%s 数据行 %d 行：id 规则/system 枚举/技能引用/占位资源逐行检查完成" % [CHARS_FILE, checked])


## 技能引用存在性 + 命名与体系一致 + type 配对
func _check_skill_ref(row: Dictionary, header: Array, line_no: int, cid: String, en: String,
		col: String, suffix: String, expect_type: String, skill_map: Dictionary) -> void:
	var sid := _field(row, header, col)
	if sid.is_empty():
		_fail("%s:%d 列[%s] 引用为空（角色须挂小技能 + 大招，§3）" % [CHARS_FILE, line_no, col])
		return
	if not en.is_empty():
		var expect_id := "skill_%s_%s" % [en, suffix]
		if sid != expect_id:
			_fail("%s:%d 列[%s] 技能 id \"%s\" 与角色体系（system→%s）不符，契约 \"%s\"" % [
				CHARS_FILE, line_no, col, sid, en, expect_id])
		else:
			_pass_count += 1
	if not skill_map.has(sid):
		_fail("%s:%d 列[%s] 引用不存在：skills.csv 无 \"%s\"（角色 %s）" % [CHARS_FILE, line_no, col, sid, cid])
		return
	var sk: Dictionary = skill_map[sid]
	var srow: Dictionary = sk["row"]
	var sheader: Array = sk["header"]
	var actual_type := _field(srow, sheader, "type")
	if actual_type != expect_type:
		_fail("%s:%d 列[%s] 引用 \"%s\" 的 type=%s，应为 %s（%s:%d）" % [
			CHARS_FILE, line_no, col, sid, actual_type, expect_type, SKILLS_FILE, int(sk["line"])])
	else:
		_pass_count += 1


## 占位/真实资源非空判定（预裁定③：统一走 ArtProvider，不做文件名猜测）
func _check_art(row: Dictionary, header: Array, line_no: int, cid: String, art: Node,
		col: String, is_portrait: bool) -> void:
	var contract := _field(row, header, col)
	if contract.is_empty():
		_fail("%s:%d 列[%s] 契约 id 为空（立绘/精灵契约 id 必填，§2）" % [CHARS_FILE, line_no, col])
		return
	if art == null:
		_fail("%s:%d 列[%s] ArtProvider 未就绪，无法做资源非空判定" % [CHARS_FILE, line_no, col])
		return
	var tex: Texture2D = art.get_portrait(cid) if is_portrait else art.get_character_sprite(cid)
	var api := "get_portrait" if is_portrait else "get_character_sprite"
	if tex == null:
		_fail("%s:%d 列[%s] ArtProvider.%s(%s) 返回空纹理" % [CHARS_FILE, line_no, col, api, cid])
	else:
		_pass_count += 1


# ---------------------------------------------------------------
# 冒烟：DataManager 加载断言 + ArtProvider 占位非空（§7）
# ---------------------------------------------------------------

func _run_smoke(chars: Dictionary, skill_map: Dictionary) -> void:
	if _override:
		print("[SKIP] 冒烟段：CHAR_DESIGNER_CSV_DIR 覆盖模式下 DataManager 仍读 res://data/csv，非同一数据源")
		return
	var dm: Node = root.get_node_or_null("DataManager")
	var art: Node = root.get_node_or_null("ArtProvider")
	if dm == null:
		_fail("冒烟 DataManager 未就绪（autoload 缺失）")
		return
	if art == null:
		_fail("冒烟 ArtProvider 未就绪（autoload 缺失）")
		return
	var header: Array = chars.get("header", [])
	var rows: Array = chars.get("rows", [])

	# 角色数：DataManager 载入数 == CSV 数据行数
	var ids: Array = dm.get_character_ids()
	if ids.size() == rows.size():
		_pass("冒烟 角色数 DataManager=%d == characters.csv 数据行 %d" % [ids.size(), rows.size()])
	else:
		_fail("冒烟 角色数不一致：DataManager=%d，characters.csv 数据行=%d（characters.csv:0 列[(行数)]）" % [
			ids.size(), rows.size()])

	for row in rows:
		var line_no := int(row["line"])
		if (row["fields"] as Array).size() != header.size():
			continue
		var cid := _field(row, header, "id")
		var ch = dm.get_character(cid)
		if ch == null:
			_fail("冒烟 characters.csv:%d 列[id] DataManager 回读 \"%s\" 为空" % [line_no, cid])
			continue
		# 字段回读（逐列对照 CSV 原值）
		var pairs := {
			"name": [ch.name, _field(row, header, "name")],
			"faction": [ch.faction, _field(row, header, "faction")],
			"system": [ch.system, _field(row, header, "system")],
			"hp": [str(ch.hp), str(_field_int(row, header, "hp"))],
			"atk": [str(ch.atk), str(_field_int(row, header, "atk"))],
			"def": [str(ch.def), str(_field_int(row, header, "def"))],
			"spd": [str(ch.spd), str(_field_int(row, header, "spd"))],
			"skill_small": [ch.skill_small, _field(row, header, "skill_small")],
			"skill_ult": [ch.skill_ult, _field(row, header, "skill_ult")],
			"portrait_id": [ch.portrait_id, _field(row, header, "portrait_id")],
			"sprite_id": [ch.sprite_id, _field(row, header, "sprite_id")],
			"background": [ch.background, _field(row, header, "background")],
		}
		var diffs: Array[String] = []
		for key in pairs:
			if str(pairs[key][0]) != str(pairs[key][1]):
				diffs.append("%s（期望 \"%s\"，实得 \"%s\"）" % [key, pairs[key][1], pairs[key][0]])
		if diffs.is_empty():
			_pass("冒烟 字段回读 %s：%d 列逐值一致" % [cid, pairs.size()])
		else:
			_fail("冒烟 characters.csv:%d 字段回读 %s 不一致：%s" % [line_no, cid, "；".join(diffs)])
		# 技能回读（含三字段缺省回退口径）
		_check_skill_readback(dm, cid, line_no, "skill_small", _field(row, header, "skill_small"), skill_map)
		_check_skill_readback(dm, cid, line_no, "skill_ult", _field(row, header, "skill_ult"), skill_map)
		# ArtProvider 占位非空
		if art.get_portrait(cid) != null and art.get_character_sprite(cid) != null:
			_pass("冒烟 ArtProvider 占位非空 %s（portrait + sprite）" % cid)
		else:
			_fail("冒烟 characters.csv:%d ArtProvider 占位为空（portrait/sprite，逻辑 id=%s）" % [line_no, cid])


func _check_skill_readback(dm: Node, cid: String, line_no: int, col: String, sid: String,
		skill_map: Dictionary) -> void:
	if sid.is_empty():
		return
	var sk = dm.get_skill(sid)
	if sk == null:
		_fail("冒烟 characters.csv:%d 列[%s] DataManager 回读技能 \"%s\" 为空" % [line_no, col, sid])
		return
	if not skill_map.has(sid):
		return
	var srow: Dictionary = skill_map[sid]["row"]
	var sheader: Array = skill_map[sid]["header"]
	var pairs := {
		"name": [sk.name, _field(srow, sheader, "name")],
		"type": [sk.type, _field(srow, sheader, "type")],
		"power": [str(sk.power), str(_field_float(srow, sheader, "power"))],
		"cutscene_id": [sk.cutscene_id, _field(srow, sheader, "cutscene_id")],
		"target_side": [sk.target_side, _skill_effective(srow, sheader, "target_side", SIDE_DEFAULT)],
		"target_scope": [sk.target_scope, _skill_effective(srow, sheader, "target_scope", SCOPE_DEFAULT)],
		"effect": [sk.effect, _skill_effective(srow, sheader, "effect", EFFECT_DEFAULT)],
	}
	var diffs: Array[String] = []
	for key in pairs:
		if str(pairs[key][0]) != str(pairs[key][1]):
			diffs.append("%s（期望 \"%s\"，实得 \"%s\"）" % [key, pairs[key][1], pairs[key][0]])
	if diffs.is_empty():
		_pass("冒烟 技能回读 %s（%s 列，%d 字段逐值一致）" % [sid, col, pairs.size()])
	else:
		_fail("冒烟 characters.csv:%d 列[%s] 技能回读 %s 不一致：%s" % [line_no, col, sid, "；".join(diffs)])