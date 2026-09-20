extends Control
## =============================================================
## T3.12 左下角角色信息板块 ×3（§6 必显项；T3.8 右下角头像行迁移重排）
## -------------------------------------------------------------
## 布局（§6）：屏幕左下角横排 3 个板块、互不重叠（间距 12 / 距左 16 /
## 距底 16，不与左侧速度条重叠——条底 y=248 < 板块顶 y=560@648p）。
## 单板块结构：左端角色头像（48×48 圆角 8）；头像右侧自上而下 =
## 角色名（血条上方）→ 血条（含「当前HP/最大HP」数字）→ buff 状态
## 图标行（当前有几个显示几个、总宽不超过血条；T3.11 buff 数据就绪
## 前显示空行占位）；头像下方 = 等级 Lv.xx。
## 口径沿用 T3.8：血条 <30% 转 #B34A3C + 1Hz 闪烁、死亡置灰 0.35、
## 激活回合 = 金 #F0B429 2px 描边 + 上浮 2px（来源 speed_bar.acting_uid）；
## 战斗全程常显（含结算/重试态，本层从不隐藏）。
## 数据只读：bm.units（name/hp/max_hp/id）；等级 duck-read
## CharacterData.level（§5.1 存档扩展未落位时兜底 Lv.1，字段就绪自动生效）。
## =============================================================

const AV_SIZE := 48.0
const PANEL_W := 204.0
const PANEL_H := 72.0
const GAP := 12.0
const MARGIN_L := 16.0
const MARGIN_B := 16.0
const COL_W := 132.0         # 头像右侧列宽（名字/血条/buff 行）
const HP_H := 12.0
const BUFF_H := 14.0
const BUFF_ICON := 14.0
const BUFF_GAP := 2.0
const COL_PANEL := Color(0.12549, 0.14118, 0.18039, 0.85)  # #20242E @85%
const COL_HP_BG := Color(0.06, 0.07, 0.10, 0.90)           # 血条底（深于板块底）
const COL_HP := Color(0.88627, 0.35686, 0.29020)           # #E25B4A
const COL_HP_LOW := Color(0.70196, 0.29020, 0.23529)       # #B34A3C <30%
const COL_GOLD := Color(0.94118, 0.70588, 0.16078)         # #F0B429 激活描边
const COL_TEXT := Color(0.91, 0.925, 0.949)                # #E8ECF2
const CORNER := 8
const LOW_HP := 0.30
const DEAD_DIM := 0.35

var bm = null
var _bar = null                # battle_speed_bar（acting_uid 来源）
var _slots: Array = []         # {root, bg_sb, name_lb, hp_bg, hp_fg, num_lb, buff_row, lv_lb, u, id}
var _blink_t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## 绑定战斗状态机与速度条（每场战斗/每次重试各调一次）
func setup(b, speed_bar) -> void:
	bm = b
	_bar = speed_bar
	_blink_t = 0.0
	_build_slots()

func _build_slots() -> void:
	for s in _slots:
		var root: Control = s["root"]
		if is_instance_valid(root):
			root.queue_free()
	_slots.clear()
	var art := get_node_or_null("/root/ArtProvider")
	var allies: Array = []
	for u in (bm.units if bm != null else []):
		if bool(u.is_ally):
			allies.append(u)
	for i in allies.size():
		var u = allies[i]
		# ---- 板块容器（#20242E@85% 圆角 8；激活=金 2px 描边）----
		var root := Panel.new()
		root.size = Vector2(PANEL_W, PANEL_H)
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = COL_PANEL
		sb.set_corner_radius_all(CORNER)
		root.add_theme_stylebox_override("panel", sb)
		# ---- 左端头像（圆角 8 裁切）----
		var clip := Panel.new()
		clip.position = Vector2(8, 4)
		clip.size = Vector2(AV_SIZE, AV_SIZE)
		var cb := StyleBoxFlat.new()
		cb.bg_color = Color(1, 1, 1)
		cb.set_corner_radius_all(CORNER)
		clip.add_theme_stylebox_override("panel", cb)
		clip.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tr := TextureRect.new()
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.texture = _square_tex(str(u.id), art)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.add_child(tr)
		root.add_child(clip)
		# ---- 头像下方：等级 Lv.xx ----
		var lv := Label.new()
		lv.position = Vector2(0, 54)
		lv.size = Vector2(64, 16)
		lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lv.add_theme_font_size_override("font_size", 12)
		lv.add_theme_color_override("font_color", COL_TEXT)
		lv.text = _level_text(str(u.id))
		lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(lv)
		# ---- 右列：角色名（血条上方）----
		var name_lb := Label.new()
		name_lb.position = Vector2(64, 4)
		name_lb.size = Vector2(COL_W, 16)
		name_lb.add_theme_font_size_override("font_size", 13)
		name_lb.add_theme_color_override("font_color", COL_TEXT)
		name_lb.text = str(u.name)
		name_lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(name_lb)
		# ---- 右列：血条（含 当前HP/最大HP 数字）----
		var hp_bg := ColorRect.new()
		hp_bg.position = Vector2(64, 22)
		hp_bg.size = Vector2(COL_W, HP_H)
		hp_bg.color = COL_HP_BG
		hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(hp_bg)
		var hp_fg := ColorRect.new()
		hp_fg.position = Vector2(64, 22)
		hp_fg.size = Vector2(COL_W, HP_H)
		hp_fg.color = COL_HP
		hp_fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(hp_fg)
		var num_lb := Label.new()
		num_lb.position = Vector2(64, 22)
		num_lb.size = Vector2(COL_W, HP_H)
		num_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_lb.add_theme_font_size_override("font_size", 9)
		num_lb.add_theme_color_override("font_color", Color(1, 1, 1))
		num_lb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		num_lb.add_theme_constant_override("outline_size", 2)
		num_lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(num_lb)
		# ---- 右列：buff 状态图标行（空行占位，T3.11 接入数据）----
		var buff_row := Control.new()
		buff_row.position = Vector2(64, 40)
		buff_row.size = Vector2(COL_W, BUFF_H)
		buff_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(buff_row)
		add_child(root)
		_slots.append({"root": root, "bg_sb": sb, "name_lb": name_lb,
			"hp_bg": hp_bg, "hp_fg": hp_fg, "num_lb": num_lb,
			"buff_row": buff_row, "lv_lb": lv, "u": u, "id": str(u.id)})

## 等级：duck-read CharacterData.level（§5.1 存档扩展字段未落位时兜底 Lv.1）
func _level_text(id: String) -> String:
	var dm := get_node_or_null("/root/DataManager")
	if dm != null and dm.has_method("get_character"):
		var ch = dm.get_character(id)
		if ch != null:
			var lv = ch.get("level")
			if lv != null and int(lv) > 0:
				return "Lv.%d" % int(lv)
	return "Lv.1"

## 立绘唯一入口 ArtProvider.get_portrait（T2.6 契约）：取上部正方形
func _square_tex(id: String, art) -> Texture2D:
	var tex: Texture2D = null
	if art != null and art.has_method("get_portrait"):
		tex = art.get_portrait(id, "normal")
	if tex == null:
		var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.5, 0.5, 0.5))
		tex = ImageTexture.create_from_image(img)
	var square := minf(tex.get_width(), tex.get_height())
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(0, 0, square, square)
	return at

func _process(delta: float) -> void:
	_tick(delta)

func _tick(delta: float) -> void:
	if bm == null or _slots.is_empty():
		return
	_blink_t += delta
	var acting := ""
	if _bar != null:
		acting = str(_bar.acting_uid)
	for i in _slots.size():
		var s: Dictionary = _slots[i]
		var u = s["u"]
		var x := MARGIN_L + float(i) * (PANEL_W + GAP)
		var y := size.y - MARGIN_B - PANEL_H
		var alive := _alive(u)
		var active := alive and acting != "" and acting == str(s["id"])
		var root: Panel = s["root"]
		root.position = Vector2(x, y - (2.0 if active else 0.0))  # 激活上浮 2px
		# 激活金描边 2px（T3.8 口径沿用）
		var sb: StyleBoxFlat = s["bg_sb"]
		sb.set_border_width_all(2 if active else 0)
		sb.border_color = COL_GOLD
		root.modulate = Color(1, 1, 1, DEAD_DIM if not alive else 1.0)
		# 血条比例 + <30% 低位色闪烁 + 数字
		var ratio := clampf(float(u.hp) / maxf(1.0, float(u.max_hp)), 0.0, 1.0)
		var fg: ColorRect = s["hp_fg"]
		fg.size = Vector2(COL_W * ratio, HP_H)
		if ratio <= 0.0:
			fg.size = Vector2(0, HP_H)
		elif ratio < LOW_HP:
			fg.color = Color(COL_HP_LOW.r, COL_HP_LOW.g, COL_HP_LOW.b,
				0.45 + 0.55 * (0.5 + 0.5 * sin(_blink_t * TAU)))  # 1Hz 闪烁
		else:
			fg.color = COL_HP
		(s["num_lb"] as Label).text = "%d/%d" % [int(u.hp), int(u.max_hp)]
		# buff 图标行：有几个显示几个、总宽不超过血条（T3.11 前恒空=占位）
		_refresh_buffs(s)

func _refresh_buffs(s: Dictionary) -> void:
	var row: Control = s["buff_row"]
	var buffs = s["u"].get("buffs") if s["u"] != null else null
	var n := 0
	if buffs is Array:
		n = mini(buffs.size(), int(COL_W / (BUFF_ICON + BUFF_GAP)))
	if row.get_child_count() != n:
		for c in row.get_children():
			c.queue_free()
		for j in n:
			var icon := ColorRect.new()
			icon.position = Vector2(float(j) * (BUFF_ICON + BUFF_GAP), 0)
			icon.size = Vector2(BUFF_ICON, BUFF_H)
			icon.color = Color(0.5, 0.7, 0.95)  # 占位色（正式图标归 T3.11/美术）
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(icon)

func _alive(u) -> bool:
	if u == null:
		return false
	if u.has_method("is_alive"):
		return bool(u.is_alive())
	return float(u.hp) > 0.0
