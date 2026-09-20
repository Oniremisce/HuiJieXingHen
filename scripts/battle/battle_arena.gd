extends Node2D
## =============================================================
## T3.7 Battle 战场表现层（Battle.tscn 根；由 BattleController 实例化）
## T3.12：旧占位渲染（我方横向色块排 / 敌方色块+名字）已移除（§6 禁止项）。
## T3.9：战场单位表现由 §9 对阵阵型承载重建——
##   4×3 斜向格子站位（battle_form_layout.gd 纯数学）、多敌编组（1~6）、
##   单位头顶血条小组件（我方=体系图标+血条常显、敌方=红色血条常显，
##   平时无箭头——目标选择箭头归 T3.10 §8.2）；棋盘格不渲染（§6）。
## 战斗 UI 层：速度条 / 左下角角色信息板块 / 结果大字（胜利/星砂入账、
## 失败重试提示）。
## 地板=宿主地图 Ground 层（§1 原地变身态，本层不含地板）。
## =============================================================

const FORM := preload("res://scripts/battle/battle_form_layout.gd")

# 头顶血条小组件口径（§6）：血条为头顶小组件、不遮挡模型
const BAR_W := 40.0
const BAR_H := 4.0
const ICON_S := 12.0                 # 我方体系图标（体系色方块）
const BAR_TOP := -56.0               # 头顶血条 y（模型 64×96 顶 -48，再上 8px）
const NAME_Y := 52.0                 # 名字 Label（模型底部下方）
const COL_HP_ENEMY := Color(0.70196, 0.29020, 0.23529)  # #B34A3C 敌方红血条
const COL_HP_BG := Color(0.0, 0.0, 0.0, 0.55)
const DEAD_DIM := 0.35
const NAME_SIZE := 11

@onready var _result: Label = $BattleUI/ResultLabel
@onready var _retry: Label = $BattleUI/RetryHint
@onready var _speed_bar: Control = $BattleUI/SpeedBar
@onready var _party_row: Control = $BattleUI/PartyRow
@onready var _allies: Node2D = $Allies
@onready var _enemies: Node2D = $Enemies

var bm = null
var _stand_units: Array = []  # {root, id, is_ally, hp_bg, hp_fg, icon, sprite}

## T3.8：绑定战斗状态机（只读表现：速度条跑条动画 + 左下角角色信息板块）
func attach_battle(b) -> void:
	bm = b
	_speed_bar.attach_battle(b)
	_party_row.setup(b, _speed_bar)

## T3.8：演出转发代理（保持 bm.cutscene 既有四方法契约；播毕通知跑条放行）
func make_cutscene_proxy(real_cutscene) -> RefCounted:
	return _speed_bar.make_cutscene_proxy(real_cutscene)

## T3.9：§9 对阵阵型布置（T3.12 置空后重建）
## 我方=party_ids 取 ally 前 N（最多 3）；敌方=enemy_ids 取 front 前 3 + back 剩余（最多 6）；
## 空位允许（我方不足 3 / 敌不足 6 只摆实际数量）；棋盘格不渲染（纯逻辑位置）。
func setup_stances(party_ids: Array, enemy_ids: Array) -> void:
	for c in _allies.get_children():
		c.free()  # 立即释放（queue_free 延迟到帧末，同帧多次 setup 会累积旧节点）
	for c in _enemies.get_children():
		c.free()
	_stand_units.clear()
	var vp := get_viewport_rect().size
	var form: Dictionary = FORM.take_param(vp, 3, 4)
	var ally_pts: Array = form["ally"]
	var front: Array = form["enemy_front"]
	var back: Array = form["enemy_back"]
	var n_ally := mini(party_ids.size(), ally_pts.size())
	for i in n_ally:
		_spawn_unit(_allies, String(party_ids[i]), true, ally_pts[i])
	var n_front := mini(enemy_ids.size(), front.size())  # 前 3 个放前列（靠我方）
	for i in n_front:
		_spawn_unit(_enemies, String(enemy_ids[i]), false, front[i])
	var n_back := enemy_ids.size() - n_front             # 剩余放后列
	for i in n_back:
		_spawn_unit(_enemies, String(enemy_ids[n_front + i]), false, back[i])

## 生成单个战场单位：Q 版小人（ArtProvider.get_character_sprite，与地图同规格）
## + 名字 Label（模型下方）+ 头顶血条小组件（我方体系图标+体系色血条 / 敌方红血条）
func _spawn_unit(container: Node2D, uid: String, is_ally: bool, pos: Vector2) -> void:
	var root := Node2D.new()
	root.position = pos
	root.z_index = 10
	container.add_child(root)
	var art := get_node_or_null("/root/ArtProvider")
	var tex: Texture2D = art.get_character_sprite(uid) if art != null else null
	var sp := Sprite2D.new()
	sp.name = "Sprite"
	if tex != null:
		sp.texture = tex
	sp.z_index = 1
	root.add_child(sp)
	# 名字 Label（模型底部下方，敌我通用；非 §6 禁止的「屏幕下方居中怪物名」占位）
	var nm := Label.new()
	nm.name = "NameLabel"
	nm.text = _display_name(uid, is_ally)
	nm.position = Vector2(-40, NAME_Y)
	nm.size = Vector2(80, 14)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.add_theme_font_size_override("font_size", NAME_SIZE)
	nm.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98, 0.9))
	nm.add_theme_constant_override("outline_size", 3)
	nm.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nm.z_index = 2
	root.add_child(nm)
	# 头顶血条小组件（不遮挡模型，悬于模型顶部上方）
	var hp_bg := ColorRect.new()
	hp_bg.name = "HpBg"
	hp_bg.position = Vector2(-BAR_W * 0.5, BAR_TOP)
	hp_bg.size = Vector2(BAR_W, BAR_H)
	hp_bg.color = COL_HP_BG
	hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bg.z_index = 3
	root.add_child(hp_bg)
	var hp_fg := ColorRect.new()
	hp_fg.name = "HpFg"
	hp_fg.position = Vector2(-BAR_W * 0.5, BAR_TOP)
	hp_fg.size = Vector2(BAR_W, BAR_H)
	hp_fg.color = _hp_color(uid, is_ally)
	hp_fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_fg.z_index = 4
	root.add_child(hp_fg)
	var icon: ColorRect = null
	if is_ally:
		# 我方体系图标：体系色方块并排血条左侧（体系色查 ArtProvider.get_system_color）
		icon = ColorRect.new()
		icon.name = "SystemIcon"
		icon.position = Vector2(-BAR_W * 0.5 - ICON_S - 2.0, BAR_TOP)
		icon.size = Vector2(ICON_S, ICON_S)
		icon.color = _system_color(uid)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.z_index = 4
		root.add_child(icon)
	_stand_units.append({"root": root, "id": uid, "is_ally": is_ally,
		"hp_bg": hp_bg, "hp_fg": hp_fg, "icon": icon, "sprite": sp})

## 每帧刷新头顶血条比例（只读 bm.units；未绑定/未找到单位=满血）
func _process(_delta: float) -> void:
	if bm == null:
		return
	for s in _stand_units:
		var unit: Variant = _find_unit(String(s["id"]))
		var ratio := 1.0
		var alive := true
		if unit != null:
			ratio = clampf(float(unit.hp) / maxf(1.0, float(unit.max_hp)), 0.0, 1.0)
			alive = unit.has_method("is_alive") and bool(unit.is_alive())
		var fg: ColorRect = s["hp_fg"]
		fg.size = Vector2(BAR_W * ratio, BAR_H)
		fg.color = _hp_color(String(s["id"]), bool(s["is_ally"])) if alive else Color(0.5, 0.5, 0.5)
		var sp: Sprite2D = s["sprite"]
		if sp != null:
			sp.modulate = Color(1, 1, 1, DEAD_DIM) if not alive else Color.WHITE

func _find_unit(uid: String) -> Variant:
	for u in (bm.units if bm != null else []):
		if str(u.id) == uid:
			return u
	return null

func _hp_color(uid: String, is_ally: bool) -> Color:
	if not is_ally:
		return COL_HP_ENEMY
	return _system_color(uid)

## 体系色（我方头像/血条/头顶图标）：ArtProvider.get_system_color 唯一出口
func _system_color(uid: String) -> Color:
	var art := get_node_or_null("/root/ArtProvider")
	if art != null and art.has_method("get_system_color"):
		return Color(art.get_system_color(uid))
	return Color(0.6, 0.6, 0.6)

func _display_name(uid: String, is_ally: bool) -> String:
	var dm := get_node_or_null("/root/DataManager")
	if dm != null:
		var d: Variant = dm.get_character(uid) if is_ally else dm.get_enemy(uid)
		if d != null:
			return str(d.name)
	return uid

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
