extends Node2D
## =============================================================
## T3.7 Battle 战场表现层（Battle.tscn 根；由 BattleController 实例化）
## 站位：我方左侧横排 / 敌方右侧横排（Q 版色块+名字，§7 战场常态）；
## 战斗 UI 层：结果大字（胜利/星砂入账、失败重试提示）。
## 地板=宿主地图 Ground 层（§1 原地变身态，本层不含地板）。
## =============================================================

@onready var _allies: Node2D = $Allies
@onready var _enemies: Node2D = $Enemies
@onready var _result: Label = $BattleUI/ResultLabel
@onready var _retry: Label = $BattleUI/RetryHint

## 布置敌我站位（battle_started 参数直传）
func setup_stances(party_ids: Array, enemy_ids: Array) -> void:
	_fill(_allies, party_ids, 300.0)
	_fill(_enemies, enemy_ids, 900.0)

## 结算大字：胜利=星砂入账提示 / 失败=重试引导前置
func show_result(win: bool, sand: int) -> void:
	_result.visible = true
	if win:
		_result.text = "胜 利 ！\n获得星砂 ×%d" % sand
		_result.add_theme_color_override("font_color", Color(1, 0.92, 0.6))
	else:
		_result.text = "战 败 ……"
		_result.add_theme_color_override("font_color", Color(1, 0.45, 0.4))

## 失败重试引导
func show_retry() -> void:
	_retry.visible = true
	_retry.text = "空格：重试本场    Esc：撤离"

## 清除结算/重试提示（重试开新一场前）
func show_battle() -> void:
	_result.visible = false
	_retry.visible = false

## 内部：按 id 生成 Q 版色块站位+名字（ArtProvider 唯一入口）
func _fill(parent: Node2D, ids: Array, x0: float) -> void:
	var art := get_node_or_null("/root/ArtProvider")
	var dm := get_node_or_null("/root/DataManager")
	for i in ids.size():
		var uid := str(ids[i])
		var s := Sprite2D.new()
		if art != null:
			s.texture = art.get_character_sprite(uid)
		s.position = Vector2(x0 + i * 130.0, 300.0)
		parent.add_child(s)
		var lb := Label.new()
		var ch: Variant = dm.get_character(uid) if dm != null else null
		var en: Variant = dm.get_enemy(uid) if dm != null else null
		lb.text = str(ch.name) if ch != null else (str(en.name) if en != null else uid)
		lb.position = Vector2(-44, 54)
		lb.size = Vector2(88, 24)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.add_child(lb)
