extends CanvasLayer
## =============================================================
## T3.6 战斗演出占位层（口径：docs/系统规则/战斗系统.md §7 + 推进表 T3.6 卡）
## -------------------------------------------------------------
## 布局（§7）：右下 PortraitRect 常驻立绘（激活回合更新/小技能播毕切回常态）
## + UltCGRect 全屏大招 CG（技能名大字，2s）+ ComboCGRect 全屏合击 CG（2s）
## + SkipHint。色块占位动画走 AnimationPlayer（cg_fade_ult/cg_fade_combo）。
## 立绘唯一入口 ArtProvider.get_portrait(id, emotion)（T2.6 契约，占位色块/
## T4.3 已落真实立绘）。空格（ui_accept）跳过当前演出；每次播毕发 finished。
## 挂载：由调用方实例化后 add_child（T3.7 Battle 场景持有多 instance 或复用）。
## BM 注入约定：bm.cutscene = 实例（null=直通无演出）；方法集即本脚本公开方法，
## 测试可用同签名假演出注入（见 tools/smoke_test_cutscene.gd）。
## =============================================================

signal finished  # skill/ult/combo 每次播毕（含跳过）时发

@onready var _portrait_tex: TextureRect = $Root/PortraitRect/PortraitTexture
@onready var _portrait_name: Label = $Root/PortraitRect/PortraitName
@onready var _ult_box: Control = $Root/UltCGRect
@onready var _ult_name: Label = $Root/UltCGRect/UltSkillName
@onready var _combo_box: Control = $Root/ComboCGRect
@onready var _combo_name: Label = $Root/ComboCGRect/ComboName
@onready var _anim: AnimationPlayer = $AnimationPlayer

var _skip := false

## 回合激活：更新右下角常驻立绘（无时长，立即完成）
func play_active(id: String) -> void:
	_show_portrait(id)

## 小技能：动态立绘占位（占位阶段同图）0.8s 播毕切回常态
func play_skill(id: String, skill_id: String) -> void:
	_show_portrait(id)
	await _wait(0.8)
	_show_portrait(id)

## 大招：全屏 CG 占位（技能名大字）2s
func play_ult(id: String, skill_id: String) -> void:
	_show_portrait(id)
	_ult_name.text = _skill_label(skill_id)
	_ult_box.visible = true
	_anim.play("cg_fade_ult")
	await _wait(2.0)
	_ult_box.visible = false

## 合击：全屏 CG 占位（合击技名大字）2s；正式合击技名待定稿前用占位文案
func play_combo(combo_name: String = "三人合击") -> void:
	_combo_name.text = combo_name
	_combo_box.visible = true
	_anim.play("cg_fade_combo")
	await _wait(2.0)
	_combo_box.visible = false

## 空格跳过：置位后 _wait 提前退出（演出时长归零语义）
func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_accept"):
		_skip = true

## 内部：右下角立绘更新（ArtProvider 唯一入口；名字取 CSV 正式名）
func _show_portrait(id: String) -> void:
	var art := get_node_or_null("/root/ArtProvider")
	if art != null:
		_portrait_tex.texture = art.get_portrait(id, "normal")
	var dm := get_node_or_null("/root/DataManager")
	var ch: Variant = dm.get_character(id) if dm != null else null
	_portrait_name.text = str(ch.name) if ch != null else id

## 内部：技能名大字文案（正式名优先，查不到回退 id）
func _skill_label(skill_id: String) -> String:
	var dm := get_node_or_null("/root/DataManager")
	var sk: Variant = dm.get_skill(skill_id) if dm != null else null
	return "%s\n（%s）" % [str(sk.name), skill_id] if sk != null else skill_id

## 内部：演出等待（每帧查跳过；结束时发 finished）
func _wait(seconds: float) -> void:
	_skip = false
	var elapsed := 0.0
	while elapsed < seconds and not _skip:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	finished.emit()
