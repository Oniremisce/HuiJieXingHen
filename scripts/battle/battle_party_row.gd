extends Control
## =============================================================
## T3.8 右下角参战角色行（§6 必显项；美术01 视觉口径，制作人04 预裁定①）
## -------------------------------------------------------------
## 我方头像横排 48×48 圆角 8px、间距 12px、距右 16px，位于立绘区
## （PortraitRect top=-330）上方 12px（行总高 58=48+4+6，不侵入立绘）；
## 血条 48×6px 置头像正下方 4px（底 #20242E@85%、前景 #E25B4A、
## <30% 转 #B34A3C + 1Hz 闪烁；「血条在下方」已经制作人04 备案）；
## 激活回合 = 金 #F0B429 2px 描边 + 上浮 2px（来源 speed_bar.acting_uid）；
## 战斗全程常显（含结算/重试态，本层从不隐藏）。
## 数据只读：bm.units（hp/max_hp/is_ally）；激活高亮只读 speed_bar.acting_uid。
## =============================================================

const SB := preload("res://scripts/battle/battle_speed_bar.gd")

const AV_SIZE := 48.0
const GAP := 12.0
const MARGIN_R := 16.0
const ROW_H := 58.0            # 48 头像 + 4 间隙 + 6 血条
const ROW_BOTTOM := 342.0      # 行底边距视口底（血条底 y=306 = 立绘区顶 318 上方 12px，
                               # 真机验证修正：318 时血条被演出层 PortraitRect 遮挡）
const HP_W := 48.0
const HP_H := 6.0
const HP_GAP := 4.0
const COL_BG := Color(0.12549, 0.14118, 0.18039, 0.85)    # #20242E @85%
const COL_HP := Color(0.88627, 0.35686, 0.29020)          # #E25B4A
const COL_HP_LOW := Color(0.70196, 0.29020, 0.23529)      # #B34A3C <30%
const COL_GOLD := Color(0.94118, 0.70588, 0.16078)        # #F0B429 激活描边
const CORNER := 8
const LOW_HP := 0.30
const DEAD_DIM := 0.35

var bm = null
var _bar = null                # battle_speed_bar（acting_uid 来源）
var _slots: Array = []         # {root, ring, hp_bg, hp_fg, u, id}
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
		var bg: ColorRect = s["hp_bg"]
		var fg: ColorRect = s["hp_fg"]
		if is_instance_valid(root):
			root.queue_free()
		if is_instance_valid(bg):
			bg.queue_free()
		if is_instance_valid(fg):
			fg.queue_free()
	_slots.clear()
	var art := get_node_or_null("/root/ArtProvider")
	var allies: Array = []
	for u in (bm.units if bm != null else []):
		if bool(u.is_ally):
			allies.append(u)
	for i in allies.size():
		var u = allies[i]
		# 头像（圆角 8 裁切）
		var root := Control.new()
		root.size = Vector2(AV_SIZE, AV_SIZE)
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var clip := Panel.new()
		clip.set_anchors_preset(Control.PRESET_FULL_RECT)
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
		# 激活金环（默认隐藏）
		var ring := Panel.new()
		ring.set_anchors_preset(Control.PRESET_FULL_RECT)
		var rb := StyleBoxFlat.new()
		rb.draw_center = false
		rb.set_border_width_all(2)
		rb.set_corner_radius_all(CORNER)
		rb.border_color = COL_GOLD
		ring.add_theme_stylebox_override("panel", rb)
		ring.visible = false
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(ring)
		add_child(root)
		# 血条（头像正下方 4px）
		var hp_bg := ColorRect.new()
		hp_bg.color = COL_BG
		hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(hp_bg)
		var hp_fg := ColorRect.new()
		hp_fg.color = COL_HP
		hp_fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(hp_fg)
		_slots.append({"root": root, "ring": ring, "hp_bg": hp_bg,
			"hp_fg": hp_fg, "u": u, "id": str(u.id)})

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
	var n := _slots.size()
	var row_w := float(n) * AV_SIZE + float(n - 1) * GAP
	var acting := ""
	if _bar != null:
		acting = str(_bar.acting_uid)
	var avatar_y := size.y - ROW_BOTTOM - ROW_H
	for i in n:
		var s: Dictionary = _slots[i]
		var u = s["u"]
		var x := size.x - MARGIN_R - row_w + float(i) * (AV_SIZE + GAP)
		var alive := _alive(u)
		var active := alive and acting != "" and acting == str(s["id"])
		var root: Control = s["root"]
		root.position = Vector2(x, avatar_y - (2.0 if active else 0.0))  # 激活上浮 2px
		(s["ring"] as Panel).visible = active
		root.modulate = Color(1, 1, 1, DEAD_DIM if not alive else 1.0)
		var ratio := clampf(float(u.hp) / maxf(1.0, float(u.max_hp)), 0.0, 1.0)
		var bg: ColorRect = s["hp_bg"]
		bg.position = Vector2(x, avatar_y + AV_SIZE + HP_GAP)
		bg.size = Vector2(HP_W, HP_H)
		var fg: ColorRect = s["hp_fg"]
		fg.position = bg.position
		fg.size = Vector2(HP_W * ratio, HP_H)
		if ratio <= 0.0:
			fg.size = Vector2(0, HP_H)
		elif ratio < LOW_HP:
			fg.color = Color(COL_HP_LOW.r, COL_HP_LOW.g, COL_HP_LOW.b,
				0.45 + 0.55 * (0.5 + 0.5 * sin(_blink_t * TAU)))  # 1Hz 闪烁
		else:
			fg.color = COL_HP

func _alive(u) -> bool:
	if u == null:
		return false
	if u.has_method("is_alive"):
		return bool(u.is_alive())
	return float(u.hp) > 0.0
