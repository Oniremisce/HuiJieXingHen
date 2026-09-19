@tool
extends EditorScript
## =============================================================
## 《汇界星痕》T4.2 CSV→Dialogic timeline 转换管线
## -------------------------------------------------------------
## 扫描 data/csv/dialogues_*.csv（9 列规范）→ 生成 dialogues/timelines/<timeline_id>.dtl。
## 幂等：同一 CSV 重跑输出字节一致。
## 运行方式：
##   - 编辑器内：Script Editor 打开本文件 → File → Run（编辑器 Output 打印转换统计）
##   - headless 自检：load 本脚本后调用 convert_all()（返回统计字典，含 skipped 明细）
## 列规范（首行列头必须一致）：
##   timeline_id, order, speaker_id, emotion, text, set_flag, flag_condition, choice_a, choice_b
## 生成规则（Dialogic 2 官方 Timeline Text Syntax）：
##   - order 决定行序（数值升序，同 order 按 CSV 行序稳定排序）
##   - speaker 首次出现 → join <speaker> [(emotion)] center（TextEvent 不会自动上台）
##   - speaker 切换（A→B）→ 先 leave <A> 再 join <B>（同台单人制；旁白不改变台上状态；
##     同 speaker 连续台词只换表情不重复 join）
##   - 说话行：speaker+emotion → "<speaker> (<emotion>): <text>"；
##     仅 speaker → "<speaker>: <text>"；speaker 空 → 纯旁白行 "<text>"
##   - set_flag 非空 → 该行后追加 [signal arg="set_flag:<spec>"]（DialogicBridge→GameState 写 flag）
##   - flag_condition 非空 → "if <表达式>:" 行 + 本行内容 tab 缩进；
##     表达式直接引用 GameState autoload（Dialogic Expression 注入 autoload 求值）：
##     裸 flag 名 → GameState.has_flag('<名>')；<名>=<值> → GameState.get_flag('<名>', 默认) == <值>
##   - choice_a/choice_b 非空 → 生成 "- <选项文本>"（无跳转目标=选择后继续主线）
## 转义：text 内半角冒号 → 全角：（打印警告）；换行 → 空格。
## 校验：speaker_id 非空时要求 dialogues/characters/<speaker_id>.dch 已存在，
##       否则该 timeline 整体跳过并登记（等 Character 资源落地后重跑即可）。
## =============================================================

const _CsvParser := preload("res://scripts/core/CSVParser.gd")

const CSV_DIR := "res://data/csv"
const CSV_PREFIX := "dialogues_"
const OUT_DIR := "res://dialogues/timelines"
const CHAR_DIR := "res://dialogues/characters"
const COLUMNS: Array[String] = [
	"timeline_id", "order", "speaker_id", "emotion", "text",
	"set_flag", "flag_condition", "choice_a", "choice_b",
]


## 全量转换入口。返回统计：{"files", "timelines", "rows", "skipped": Array[String]}
static func convert_all() -> Dictionary:
	var stats := {"files": 0, "timelines": 0, "rows": 0, "skipped": [] as Array[String]}
	var dir := DirAccess.open(CSV_DIR)
	if dir == null:
		push_error("[csv_to_dialogic] 无法打开目录 " + CSV_DIR)
		return stats
	for fname in dir.get_files():
		if not (fname.begins_with(CSV_PREFIX) and fname.ends_with(".csv")):
			continue
		stats.files += 1
		var rows := _CsvParser.parse(CSV_DIR + "/" + fname)
		if rows.is_empty():
			push_error("[csv_to_dialogic] %s：无可解析数据行，跳过" % fname)
			stats.skipped.append(fname)
			continue
		if not _has_required_columns(rows[0]):
			push_error("[csv_to_dialogic] %s：列头与 9 列规范不符，跳过（要求：%s）" % [fname, ", ".join(COLUMNS)])
			stats.skipped.append(fname)
			continue
		var groups := _group_by_timeline(rows)
		for tid in groups:
			var tl_rows: Array = groups[tid]
			var missing := _validate_characters(tl_rows)
			if not missing.is_empty():
				push_error("[csv_to_dialogic] %s/%s：Character 资源缺失 dialogues/characters/%s.dch，跳过该 timeline（Character 落地后重跑）" % [fname, tid, missing])
				stats.skipped.append(tid)
				continue
			_write_timeline(tid, _build_timeline_text(tl_rows))
			stats.timelines += 1
			stats.rows += tl_rows.size()
	print("[csv_to_dialogic] 完成：CSV 文件 %d 个，生成 timeline %d 个，数据行 %d 行，跳过 %s" % [
		stats.files, stats.timelines, stats.rows, str(stats.skipped)])
	return stats


## EditorScript 入口（编辑器内 File → Run）
func _run() -> void:
	convert_all()


# ------------------------------------------------------------
# 内部实现
# ------------------------------------------------------------

static func _has_required_columns(first_row: Dictionary) -> bool:
	for col in COLUMNS:
		if not first_row.has(col):
			return false
	return true


## 按 timeline_id 分组，保持首次出现顺序；组内按 order 数值稳定排序（同 order 保持 CSV 行序）
static func _group_by_timeline(rows: Array[Dictionary]) -> Dictionary:
	var groups := {}
	for i in rows.size():
		var row := rows[i]
		var tid := str(row.get("timeline_id", "")).strip_edges()
		if tid.is_empty():
			push_error("[csv_to_dialogic] 第 %d 行：timeline_id 为空，跳过该行" % (i + 2))
			continue
		if not groups.has(tid):
			groups[tid] = []
		groups[tid].append({"idx": i, "row": row})
	for tid in groups:
		var arr: Array = groups[tid]
		arr.sort_custom(func(a, b):
			var oa := int(str(a.row.get("order", "0")))
			var ob := int(str(b.row.get("order", "0")))
			if oa != ob:
				return oa < ob
			return a.idx < b.idx)
		groups[tid] = arr.map(func(e): return e.row)
	return groups


## speaker 齐备校验：返回首个缺失 .dch 的 speaker_id（全齐返回空串）
static func _validate_characters(tl_rows: Array) -> String:
	for row in tl_rows:
		var speaker := str(row.get("speaker_id", "")).strip_edges()
		if not speaker.is_empty() and not FileAccess.file_exists(CHAR_DIR + "/" + speaker + ".dch"):
			return speaker
	return ""


## 组装单个 timeline 的 .dtl 文本（\n 行尾，末尾一个换行）
static func _build_timeline_text(tl_rows: Array) -> String:
	var joined := {}
	var on_stage := ""  # 当前台上角色（T4.3：speaker 切换时 leave 旧角色）
	var out := PackedStringArray()
	for row in tl_rows:
		var speaker := str(row.get("speaker_id", "")).strip_edges()
		var emotion := str(row.get("emotion", "")).strip_edges()
		var text := _sanitize_text(str(row.get("text", "")))
		var set_flag := str(row.get("set_flag", "")).strip_edges()
		var cond := str(row.get("flag_condition", "")).strip_edges()
		var choice_a := _sanitize_choice(str(row.get("choice_a", "")))
		var choice_b := _sanitize_choice(str(row.get("choice_b", "")))
		var indent := ""
		if not cond.is_empty():
			out.append("if " + _condition_expression(cond) + ":")
			indent = "\t"
		if not speaker.is_empty():
			if on_stage != speaker:
				if not on_stage.is_empty():
					out.append(indent + "leave " + on_stage)
					joined.erase(on_stage)
				if not joined.has(speaker):
					if emotion.is_empty():
						out.append(indent + "join " + speaker + " center")
					else:
						out.append(indent + "join " + speaker + " (" + emotion + ") center")
					joined[speaker] = true
				on_stage = speaker
		out.append(indent + _text_line(speaker, emotion, text))
		if not set_flag.is_empty():
			out.append(indent + '[signal arg="set_flag:' + set_flag + '"]')
		if not choice_a.is_empty():
			out.append(indent + "- " + choice_a)
		if not choice_b.is_empty():
			out.append(indent + "- " + choice_b)
	return "\n".join(out) + "\n"


## 说话行格式（speaker 空为纯旁白）
static func _text_line(speaker: String, emotion: String, text: String) -> String:
	if speaker.is_empty():
		return text
	if emotion.is_empty():
		return speaker + ": " + text
	return "%s (%s): %s" % [speaker, emotion, text]


## flag_condition 列 → Dialogic 条件表达式（Expression 引用 GameState autoload）
static func _condition_expression(cond: String) -> String:
	var eq := cond.find("=")
	if eq < 0:
		return "GameState.has_flag('%s')" % cond
	var flag_name := cond.substr(0, eq).strip_edges()
	var flag_value := cond.substr(eq + 1).strip_edges()
	if flag_value.is_empty():
		return "GameState.has_flag('%s')" % flag_name
	if flag_value.is_valid_int():
		return "GameState.get_flag('%s', 0) == %d" % [flag_name, int(flag_value)]
	return "GameState.get_flag('%s', '') == '%s'" % [flag_name, flag_value]


## 台词文本转义：换行→空格；半角冒号→全角（警告）
static func _sanitize_text(text: String) -> String:
	var t := text.replace("\r\n", " ").replace("\n", " ").replace("\r", " ").strip_edges()
	if t.begins_with("- "):
		push_error("[csv_to_dialogic] 台词文本以 \"- \" 开头会被解析为选项，请改写：%s" % t)
	if ":" in t:
		push_warning("[csv_to_dialogic] 台词含半角冒号，已替换为全角：%s" % t)
		t = t.replace(":", "：")
	return t


## 选项文本转义：竖线是条件分隔符、方括号是 shortcode 定界符，均不允许
static func _sanitize_choice(text: String) -> String:
	var t := text.replace("\r\n", " ").replace("\n", " ").strip_edges()
	if "|" in t or "[" in t or "]" in t:
		push_error("[csv_to_dialogic] 选项文本含保留字符 | [ ]，请改写：%s" % t)
	return t


## 写文件（UTF-8 文本，\n 行尾）
static func _write_timeline(timeline_id: String, timeline_text: String) -> void:
	var out_path := OUT_DIR + "/" + timeline_id + ".dtl"
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		push_error("[csv_to_dialogic] 无法写入 " + out_path)
		return
	f.store_string(timeline_text)
	f.close()
