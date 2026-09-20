extends Node2D
## =============================================================
## T3.7 Battle 战场表现层（Battle.tscn 根；由 BattleController 实例化）
## T3.12：旧占位渲染（我方横向色块排 / 敌方色块+名字）已移除（§6 禁止项），
## 战场单位表现由 §9 对阵阵型承载（T3.9 交付，收工后战场短暂无单位属预期）。
## 战斗 UI 层：速度条 / 左下角角色信息板块 / 结果大字（胜利/星砂入账、
## 失败重试提示）。
## 地板=宿主地图 Ground 层（§1 原地变身态，本层不含地板）。
## =============================================================

@onready var _result: Label = $BattleUI/ResultLabel
@onready var _retry: Label = $BattleUI/RetryHint
@onready var _speed_bar: Control = $BattleUI/SpeedBar
@onready var _party_row: Control = $BattleUI/PartyRow

## T3.8：绑定战斗状态机（只读表现：速度条跑条动画 + 左下角角色信息板块）
func attach_battle(bm) -> void:
	_speed_bar.attach_battle(bm)
	_party_row.setup(bm, _speed_bar)

## T3.8：演出转发代理（保持 bm.cutscene 既有四方法契约；播毕通知跑条放行）
func make_cutscene_proxy(real_cutscene) -> RefCounted:
	return _speed_bar.make_cutscene_proxy(real_cutscene)

## T3.12：占位站位已移除（§6 禁止项；签名保留，battle_controller 调用点不动），
## 战场单位布置归 T3.9 §9 对阵阵型。
func setup_stances(party_ids: Array, enemy_ids: Array) -> void:
	pass

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
