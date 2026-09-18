## =============================================================
## 《汇界星痕》T0.3 CSV 解析器
## -------------------------------------------------------------
## parse(path) -> Array[Dictionary]：
##   - 首行为列头，后续每行映射为 {列名: 字符串值}
##   - 支持 UTF-8 BOM、CRLF/LF、双引号包裹字段（内含逗号/换行/"" 转义）
##   - 空行（全字段为空）跳过
##   - 坏行（列数不符/引号未闭合）：push_error 报告文件+行号并跳过，不崩溃
##   - 文件不存在/为空：push_error 并返回空数组
## =============================================================
class_name CSVParser
extends RefCounted

static func parse(path: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var text := _read_text(path)
	if text.is_empty():
		return rows

	var header: Array[String] = []   # 注意：用 Array（引用类型），PackedStringArray 在函数间按值拷贝
	var fields: Array[String] = []   # 当前记录累积字段
	var field := ""                  # 当前字段累积内容
	var in_quotes := false
	var record_line := 1             # 当前记录首行行号（报错定位用）
	var line := 1
	var skip_record := false         # 当前记录是否为坏行（报错后跳过）
	var i := 0
	var n := text.length()

	while i < n:
		var ch := text[i]
		if in_quotes:
			if ch == "\"":
				if i + 1 < n and text[i + 1] == "\"":
					field += "\""          # "" 转义为单个引号
					i += 1
				else:
					in_quotes = false
			elif ch == "\r":
				field += "\n"              # 引号内换行规范为 \n（\r\n 一并处理）
				if i + 1 < n and text[i + 1] == "\n":
					i += 1
				line += 1
			elif ch == "\n":
				field += "\n"
				line += 1
			else:
				field += ch
		else:
			match ch:
				"\"":
					in_quotes = true
				",":
					fields.append(field)
					field = ""
				"\r":
					if i + 1 < n and text[i + 1] == "\n":
						i += 1
					line += 1
					_flush_record(path, fields, field, header, rows, record_line, skip_record)
					field = ""
					record_line = line
					skip_record = false
				"\n":
					line += 1
					_flush_record(path, fields, field, header, rows, record_line, skip_record)
					field = ""
					record_line = line
					skip_record = false
				_:
					field += ch
		i += 1

	# EOF：收尾最后一条记录
	if not field.is_empty() or not fields.is_empty():
		if in_quotes:
			push_error("[CSVParser] %s 第 %d 行：双引号未闭合，已跳过该记录" % [path, record_line])
		else:
			_flush_record(path, fields, field, header, rows, record_line, skip_record)
	return rows


## 读取文本并剥离 UTF-8 BOM；文件不存在/为空时报错并返回空串
static func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		push_error("[CSVParser] 文件不存在：%s" % path)
		return ""
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("[CSVParser] 文件为空：%s" % path)
		return ""
	if text.begins_with("﻿"):
		text = text.substr(1)
	return text


## 提交一条记录：首条 → 表头；空行 → 跳过；坏行 → 报错跳过；正常 → 映射为 Dictionary
static func _flush_record(
	path: String, fields: Array[String], field: String,
	header: Array[String], rows: Array[Dictionary],
	record_line: int, skip_record: bool
) -> void:
	fields.append(field)
	# 空行（含仅一个空字段的行）跳过
	if fields.size() == 1 and fields[0].strip_edges().is_empty():
		fields.clear()
		return
	if header.is_empty():
		header.append_array(fields)
		fields.clear()
		return
	if skip_record:
		fields.clear()
		return
	if fields.size() != header.size():
		push_error("[CSVParser] %s 第 %d 行：列数 %d 与表头 %d 不符，已跳过该记录" % [
			path, record_line, fields.size(), header.size(),
		])
		fields.clear()
		return
	var row := {}
	for ci in header.size():
		row[header[ci]] = fields[ci]
	rows.append(row)
	fields.clear()
