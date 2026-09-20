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
const FT := preload("res://scripts/battle/battle_floating_text.gd")  # T3.10 飘字组件

# 头顶血条小组件口径（§6）：血条为头顶小组件、不遮挡模型
const BAR_W := 40.0
const BAR_H := 4.0
const ICON_S := 12.0                 # 我方体系图标（体系色方块）
const COL_HP_ENEMY := Color(0.70196, 0.29020, 0.23529)  # #B34A3C 敌方红血条
## 站位锚点编辑基准分辨率（FormationAnchors 下标量坐标系；运行时按视口宽等比缩放）
const DESIGN_SIZE := Vector2(1152, 648)
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
## T3.10：连接 BM.damage_dealt → 飘字（§8.3 自动/手动均生效）
func attach_battle(b) -> void:
	bm = b
	if bm.has_signal("damage_dealt") and not bm.damage_dealt.is_connected(_on_damage_dealt):
		bm.damage_dealt.connect(_on_damage_dealt)
	_speed_bar.attach_battle(b)
	_party_row.setup(b, _speed_bar)

## T3.10 飘字（§8.3）：伤害=白（暴击金）；治疗绿/护盾蓝/amp 黄的触发归 T3.11
func _on_damage_dealt(uidx: int, amount: int, crit: bool) -> void:
	var col := Color(1.0, 0.84, 0.3) if crit else Color(1, 1, 1)
	spawn_floating_text(uidx, str(amount), col)

## 飘字统一入口（T3.11 heal/shield/amp 也走此接口）：挂单位头顶，向上飘动渐隐。
## uidx=单位编队序下标（同 id 多单位按 id 匹配会全撞第一个，必须下标定位）
func spawn_floating_text(uidx: int, text: String, color: Color) -> void:
	for s in _stand_units:
		if int(s["uidx"]) == uidx:
			var ft = FT.new()
			ft.setup(text, color)
			var half: float = s["half_h"]
			ft.position = (s["root"] as Node2D).position + Vector2(0, -half - 24.0)
			add_child(ft)
			return

## T3.10 目标选择箭头（§8.2）：TARGETING 状态对候选目标显示；down=true=敌方
## 向下箭头（血条中间上方、不与血条重叠），false=友方向上箭头；确认/Esc 后 hide。
## uidxs=候选单位的编队序下标（同 id 多单位按 id 匹配会全命中，必须下标定位）
func show_arrows(uidxs: Array, down: bool) -> void:
	hide_arrows()
	for s in _stand_units:
		if uidxs.has(int(s["uidx"])):
			var a: Polygon2D = s["arrow"]
			if a != null:
				a.visible = true
				a.polygon = PackedVector2Array([Vector2(-7, -12), Vector2(7, -12), Vector2(0, 0)]) \
					if down else PackedVector2Array([Vector2(-7, 12), Vector2(7, 12), Vector2(0, 0)])

func hide_arrows() -> void:
	for s in _stand_units:
		var a: Polygon2D = s["arrow"]
		if a != null:
			a.visible = false

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
	# 锚点=视口空间（屏幕坐标）；本层挂在地图场景下受地图相机 canvas 变换，
	# 须逆映射到世界坐标落位，否则站位被相机拖偏、压左下角 UI（T3.9 返工修正）
	var inv: Transform2D = get_viewport().get_canvas_transform().affine_inverse()
	# 站位锚点（T3.10 后）：Battle.tscn 的 FormationAnchors/* Marker2D 可在编辑器
	# 2D 视口直接拖拽微调；节点缺失则回退 battle_form_layout 数学生成（默认一致）
	var ally_pts: Array = _anchors(["Ally0", "Ally1", "Ally2"], form["ally"])
	var front: Array = _anchors(["EnemyFront0", "EnemyFront1", "EnemyFront2"], form["enemy_front"])
	var back: Array = _anchors(["EnemyBack0", "EnemyBack1", "EnemyBack2"], form["enemy_back"])
	var n_ally := mini(party_ids.size(), ally_pts.size())
	for i in n_ally:
		_spawn_unit(_allies, String(party_ids[i]), true, inv * (ally_pts[i] as Vector2), i)
	var n_front := mini(enemy_ids.size(), front.size())  # 前 3 个放前列（靠我方）
	for i in n_front:
		_spawn_unit(_enemies, String(enemy_ids[i]), false, inv * (front[i] as Vector2), party_ids.size() + i)
	var n_back := mini(enemy_ids.size() - n_front, back.size())  # 后列≤3；超编敌（§9 上限 6 外）只结算不渲染
	for i in n_back:
		_spawn_unit(_enemies, String(enemy_ids[n_front + i]), false, inv * (back[i] as Vector2),
			party_ids.size() + n_front + i)

## 读站位锚点（FormationAnchors/<name> Marker2D）。锚点坐标语义=**1152×648 设计
## 基准视口坐标**（与 battle_form_layout 输出同域，与项目设计分辨率一致），
## 运行时按 `视口宽/1152` 等比映射到实际窗口——真机 1920×1080 下缩放 1.667 后
## 与"按视口比例自适应"的原数学结果逐值相同（视觉零变化）。
## 锚点可在 Godot 编辑器 2D 视口直接拖拽微调；节点缺失/类型不符则用 fallback
## （数学生成值，与锚点默认值一致）。落位仍走相机逆映射（站位与相机解耦）。
## 返回 Array[Vector2]，顺序与 names 一致（下标即编队序）。
func _anchors(names: Array, fallback: Array) -> Array:
	var out: Array = []
	var base := global_position  # 锚点相对本层的坐标（含 FormationAnchors 容器偏移）
	var sc := get_viewport_rect().size.x / DESIGN_SIZE.x  # 设计基准等比缩放
	for i in names.size():
		var p: Vector2 = fallback[i]
		var n := get_node_or_null("FormationAnchors/" + str(names[i]))
		if n is Node2D:
			p = ((n as Node2D).global_position - base) * sc
		out.append(p)
	return out

## 生成单个战场单位：Q 版小人（ArtProvider.get_character_sprite，与地图同规格）
## + 名字 Label（模型下方）+ 头顶血条小组件（我方体系图标+体系色血条 / 敌方红血条）
## 纹理两态：真实帧条（横向多帧 48×48/帧，ArtProvider 帧条口径）切首帧；
## 占位色块 64×96 直接贴。头顶组件偏移按模型半高自适应。
## uidx=单位在 bm.units 编队序中的下标（血条/飘字按此定位，同 id 多单位必需）
func _spawn_unit(container: Node2D, uid: String, is_ally: bool, pos: Vector2, uidx: int) -> void:
	var root := Node2D.new()
	root.position = pos
	root.z_index = 10
	container.add_child(root)
	var art := get_node_or_null("/root/ArtProvider")
	var tex: Texture2D = art.get_character_sprite(uid) if art != null else null
	var half_h := 48.0  # 模型半高（占位 64×96）
	var sp := Sprite2D.new()
	sp.name = "Sprite"
	if tex != null:
		if tex.get_width() > tex.get_height():
			# 横向帧条（48×48/帧）：切首帧，与地图角色观感同规格
			half_h = tex.get_height() * 0.5
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(0, 0, tex.get_height(), tex.get_height())
			sp.texture = atlas
		else:
			sp.texture = tex
	sp.z_index = 1
	root.add_child(sp)
	var bar_top := -(half_h + 8.0)   # 头顶血条 y（模型顶再上 8px）
	var name_y := half_h + 4.0       # 名字 Label y（模型底下方）
	# 名字 Label（模型底部下方，敌我通用；非 §6 禁止的「屏幕下方居中怪物名」占位）
	var nm := Label.new()
	nm.name = "NameLabel"
	nm.text = _display_name(uid, is_ally)
	nm.position = Vector2(-40, name_y)
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
	hp_bg.position = Vector2(-BAR_W * 0.5, bar_top)
	hp_bg.size = Vector2(BAR_W, BAR_H)
	hp_bg.color = COL_HP_BG
	hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bg.z_index = 3
	root.add_child(hp_bg)
	var hp_fg := ColorRect.new()
	hp_fg.name = "HpFg"
	hp_fg.position = Vector2(-BAR_W * 0.5, bar_top)
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
		icon.position = Vector2(-BAR_W * 0.5 - ICON_S - 2.0, bar_top)
		icon.size = Vector2(ICON_S, ICON_S)
		icon.color = _system_color(uid)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.z_index = 4
		root.add_child(icon)
	# T3.10 目标选择箭头（§8.2）：默认隐藏，TARGETING 时 show_arrows 点亮；
	# 位置=血条上方 12px（不与血条重叠）；向下（敌）/向上（友）由 show_arrows 定形
	var arrow := Polygon2D.new()
	arrow.name = "Arrow"
	arrow.visible = false
	arrow.color = Color(0.94, 0.71, 0.16)  # 金色占位（正式样式归 T7.3）
	arrow.position = Vector2(0, bar_top - 14.0)
	arrow.z_index = 5
	root.add_child(arrow)
	_stand_units.append({"root": root, "id": uid, "is_ally": is_ally, "uidx": uidx,
		"hp_bg": hp_bg, "hp_fg": hp_fg, "icon": icon, "sprite": sp,
		"arrow": arrow, "half_h": half_h})

## 每帧刷新头顶血条比例（按 uidx 读 bm.units——同 id 多单位按 id 匹配会
## 全部命中第一个，必须下标定位；未绑定/越界=满血）
func _process(_delta: float) -> void:
	if bm == null:
		return
	for s in _stand_units:
		var unit: Variant = null
		var idx := int(s["uidx"])
		if idx >= 0 and idx < bm.units.size():
			unit = bm.units[idx]
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
