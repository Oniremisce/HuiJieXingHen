## =============================================================
## 《汇界星痕》T2.5 角色列表（C 键，架构 §3.1：左详情右列表）
## -------------------------------------------------------------
## 右列：已获角色纵向头像列（头像色块+名+等级+体系色角标；未获不显示，
##   MVP 招募系统未建 → characters.csv 全部即已获）；点头像 → 左侧详情。
## 左详情分页：页1 = 立绘占位 + 四维（读 CharacterData）+ 星缘占位 +
##   技能列表（读 SkillData：名/倍率 power，充能制无 energy_cost）+
##   编队按钮（Party.add_member/remove_member，满员 3/3 拒绝 → 提示
##   「先移出后加入」，不自动顶替，T2.2 约定）；页2 = 星髓面板三区骨架
##   （装备区 6 槽 2×3 / 持有列表筛选等级+套装 / 养成区强化占位+属性预览），
##   假数据 1 条（set1_slot1）验证布局，装备逻辑 T6.5。
## =============================================================
extends UIPanelScript

const UIPanelScript := preload("res://scripts/ui/UIPanel.gd")

const PANEL_RECT := Rect2(76.0, 44.0, 1000.0, 560.0)
const FAKE_STELLIUM_ID := "set1_slot1"  # 假数据 1 条（T6.5 接 Inventory 后移除）
const STAT_NAMES := {"hp": "生命", "atk": "攻击", "def": "防御", "spd": "速度"}

## 体系色（复用 ArtProvider.SYSTEM_COLORS 同值，角标用）
var _list_box: VBoxContainer
var _pages: Array[Control] = []
var _page_index := 0
var _char_id := ""
var _warning: Label

# 页 1 控件
var _portrait: TextureRect
var _info_label: Label
var _skill_label: Label
var _party_btn: Button

# 页 2（星髓三区）
var _equip_grid: GridContainer
var _hold_list: VBoxContainer
var _set_filter: OptionButton
var _preview_label: Label
var _selected_hold_id := ""


func _init() -> void:
	panel_name = "char_list"
	layer = 92


func _ready() -> void:
	super._ready()
	get_node("/root/UISystem").register_panel("char_list", self)
	get_node("/root/EventBus").party_changed.connect(_on_party_changed)


func _build_ui() -> void:
	var dim := _make_dim()
	var panel := _make_panel(dim, PANEL_RECT)
	_make_title(panel, "角色列表")
	_make_hint(panel, "C 关闭  |  Esc 回上一层  |  点右侧头像查看详情")

	# 页切换（详情 / 星髓）
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(16.0, 40.0)
	tabs.add_theme_constant_override("separation", 8)
	panel.add_child(tabs)
	var tab_names := ["角色详情", "星髓面板"]
	for i in tab_names.size():
		var tb := Button.new()
		tb.name = "Tab_%s" % tab_names[i]
		tb.text = tab_names[i]
		tb.custom_minimum_size = Vector2(110.0, 30.0)
		var idx := i
		tb.pressed.connect(func() -> void: _switch_page(idx))
		tabs.add_child(tb)

	_warning = Label.new()
	_warning.name = "Warning"
	_warning.position = Vector2(280.0, 46.0)
	_warning.size = Vector2(420.0, 24.0)
	_warning.add_theme_font_size_override("font_size", 13)
	_warning.add_theme_color_override("font_color", Color(1.0, 0.6, 0.45))
	panel.add_child(_warning)

	var inner := Rect2(Vector2(16.0, 84.0), Vector2(PANEL_RECT.size.x - 32.0, PANEL_RECT.size.y - 124.0))

	# ---- 左：详情区 ----
	var detail := Control.new()
	detail.name = "Detail"
	detail.position = inner.position
	detail.size = Vector2(inner.size.x - 280.0 - 16.0, inner.size.y)
	panel.add_child(detail)
	_pages.append(_build_char_page(detail))
	_pages.append(_build_stellium_page(detail))

	# ---- 右：头像列表 ----
	var right := VBoxContainer.new()
	right.name = "CharList"
	right.position = Vector2(inner.position.x + inner.size.x - 264.0, inner.position.y)
	right.size = Vector2(264.0, inner.size.y)
	right.add_theme_constant_override("separation", 10)
	panel.add_child(right)
	_list_box = right

	_switch_page(0)
	_refresh_list()


## ---------------------------------------------------------------
## 页 1：角色详情
## ---------------------------------------------------------------

func _build_char_page(parent: Control) -> Control:
	var page := Control.new()
	page.name = "CharPage"
	page.position = Vector2.ZERO
	page.size = parent.size
	parent.add_child(page)

	_portrait = TextureRect.new()
	_portrait.name = "Portrait"
	_portrait.position = Vector2(0.0, 0.0)
	_portrait.size = Vector2(176.0, 242.0)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	page.add_child(_portrait)

	_info_label = Label.new()
	_info_label.name = "Info"
	_info_label.position = Vector2(196.0, 0.0)
	_info_label.size = Vector2(page.size.x - 196.0, 220.0)
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.add_theme_font_size_override("font_size", 15)
	page.add_child(_info_label)

	var star_label := Label.new()
	star_label.name = "StarBond"
	star_label.text = "星缘：占位（T5.x 心契系统接入）"
	star_label.position = Vector2(0.0, 252.0)
	star_label.add_theme_font_size_override("font_size", 14)
	star_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.78))
	page.add_child(star_label)

	_skill_label = Label.new()
	_skill_label.name = "Skills"
	_skill_label.position = Vector2(0.0, 284.0)
	_skill_label.size = Vector2(page.size.x, 96.0)
	_skill_label.add_theme_font_size_override("font_size", 14)
	page.add_child(_skill_label)

	_party_btn = Button.new()
	_party_btn.name = "PartyBtn"
	_party_btn.custom_minimum_size = Vector2(150.0, 36.0)
	_party_btn.position = Vector2(0.0, page.size.y - 44.0)
	_party_btn.pressed.connect(_on_party_btn)
	page.add_child(_party_btn)
	return page


func _refresh_char_page() -> void:
	var dm := get_node("/root/DataManager")
	var art := get_node("/root/ArtProvider")
	var ch = dm.get_character(_char_id)
	if ch == null:
		return
	_portrait.texture = art.get_portrait(_char_id)
	var col: Color = art.get_system_color(_char_id)
	var stats := "%s：生命 %d   攻击 %d   防御 %d   速度 %d" % [ch.name, ch.hp, ch.atk, ch.def, ch.spd]
	_info_label.text = "%s\n阵营：%s    体系：%s    等级：Lv.1（占位）\n\n%s\n\n背景：%s" % [
		ch.name, ch.faction_name(), ch.system_name(), stats, ch.background]
	var lines: Array[String] = []
	for sid: String in [ch.skill_small, ch.skill_ult]:
		var sk = dm.get_skill(sid)
		if sk == null:
			continue
		var type_name := "小技能" if sk.type == "small" else "大招"
		lines.append("%s｜%s（%.1f｜%s→%s %s）" % [type_name, sk.name, sk.power, sk.target_side, sk.target_scope, sk.effect])
	_skill_label.text = "技能：\n  " + "\n  ".join(lines)
	_refresh_party_btn()


## ---------------------------------------------------------------
## 页 2：星髓面板三区骨架（T6.5 接装备逻辑）
## ---------------------------------------------------------------

func _build_stellium_page(parent: Control) -> Control:
	var page := Control.new()
	page.name = "StelliumPage"
	page.position = Vector2.ZERO
	page.size = parent.size
	page.visible = false
	parent.add_child(page)

	# —— 区 1：装备区（6 槽 2 行 × 3 列）——
	var equip_title := Label.new()
	equip_title.text = "装备区（当前角色 6 槽）"
	equip_title.position = Vector2(0.0, 0.0)
	equip_title.add_theme_font_size_override("font_size", 15)
	equip_title.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	page.add_child(equip_title)
	_equip_grid = GridContainer.new()
	_equip_grid.name = "EquipGrid"
	_equip_grid.columns = 3
	_equip_grid.add_theme_constant_override("h_separation", 8)
	_equip_grid.add_theme_constant_override("v_separation", 8)
	_equip_grid.position = Vector2(0.0, 28.0)
	page.add_child(_equip_grid)
	for slot in range(1, 7):
		var cell := Panel.new()
		cell.name = "Slot_%d" % slot
		cell.custom_minimum_size = Vector2(112.0, 72.0)
		var lb := Label.new()
		lb.name = "SlotLabel_%d" % slot
		lb.position = Vector2(6.0, 4.0)
		lb.size = Vector2(100.0, 64.0)
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lb.add_theme_font_size_override("font_size", 12)
		cell.add_child(lb)
		_equip_grid.add_child(cell)

	# —— 区 2：持有列表（筛选：等级占位 + 套装）——
	var hold_title := Label.new()
	hold_title.text = "持有列表"
	hold_title.position = Vector2(0.0, 190.0)
	hold_title.add_theme_font_size_override("font_size", 15)
	hold_title.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	page.add_child(hold_title)

	var filters := HBoxContainer.new()
	filters.position = Vector2(0.0, 216.0)
	filters.add_theme_constant_override("separation", 8)
	page.add_child(filters)
	var lv_btn := OptionButton.new()
	lv_btn.name = "LvFilter"
	for opt in ["等级:全部", "等级:Lv.0"]:
		lv_btn.add_item(opt)
	lv_btn.selected = 0
	lv_btn.tooltip_text = "等级筛选占位（MVP 无养成数值）"
	filters.add_child(lv_btn)
	_set_filter = OptionButton.new()
	_set_filter.name = "SetFilter"
	for opt in ["套装:全部", "套装1", "套装2"]:
		_set_filter.add_item(opt)
	_set_filter.selected = 0
	_set_filter.item_selected.connect(func(_i: int) -> void: _refresh_hold_list())
	filters.add_child(_set_filter)

	_hold_list = VBoxContainer.new()
	_hold_list.name = "HoldList"
	_hold_list.position = Vector2(0.0, 250.0)
	_hold_list.size = Vector2(360.0, 160.0)
	_hold_list.add_theme_constant_override("separation", 6)
	page.add_child(_hold_list)

	# —— 区 3：养成区（强化占位 + 属性预览）——
	var grow_title := Label.new()
	grow_title.text = "养成区"
	grow_title.position = Vector2(390.0, 190.0)
	grow_title.add_theme_font_size_override("font_size", 15)
	grow_title.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	page.add_child(grow_title)

	var up_btn := Button.new()
	up_btn.name = "UpgradeBtn"
	up_btn.text = "强化（T6.5 开放）"
	up_btn.disabled = true
	up_btn.position = Vector2(390.0, 216.0)
	up_btn.size = Vector2(160.0, 36.0)
	page.add_child(up_btn)

	_preview_label = Label.new()
	_preview_label.name = "Preview"
	_preview_label.position = Vector2(390.0, 264.0)
	_preview_label.size = Vector2(page.size.x - 390.0, 140.0)
	_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_label.add_theme_font_size_override("font_size", 13)
	_preview_label.text = "属性预览：选中持有星髓后显示（空态）"
	page.add_child(_preview_label)
	return page


## 装备区 6 槽：槽 1 挂假数据，其余空态（T6.5 接 Inventory 后换真数据）
func _refresh_equip_grid() -> void:
	var dm := get_node("/root/DataManager")
	for slot in range(1, 7):
		var lb: Label = _equip_grid.get_node("Slot_%d/SlotLabel_%d" % [slot, slot])
		if slot == 1:
			var st = dm.get_stellium(FAKE_STELLIUM_ID)
			if st != null:
				lb.text = "%d号槽\n%s\n%s +%s\nLv.0" % [slot, st.name, st.main_stat.split("|")[0], st.main_base.split("|")[0]]
				continue
		lb.text = "%d号槽\n（空槽位）" % slot


## 持有列表：MVP 假数据 1 条 + 套装筛选；点击 → 属性预览
func _refresh_hold_list() -> void:
	for c in _hold_list.get_children():
		_hold_list.remove_child(c)
		c.queue_free()
	var dm := get_node("/root/DataManager")
	var st = dm.get_stellium(FAKE_STELLIUM_ID)
	if st == null:
		var empty := Label.new()
		empty.text = "（暂无持有星髓）"
		empty.add_theme_font_size_override("font_size", 13)
		empty.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
		_hold_list.add_child(empty)
		return
	var fidx := _set_filter.selected
	if fidx == 0 or (fidx == 1 and st.set_id == "set1") or (fidx == 2 and st.set_id == "set2"):
		var b := Button.new()
		b.text = "%s ｜ %s 槽%d ｜ Lv.0 ｜ 主词条 %s" % [st.name, st.set_name, st.slot, st.main_stat.split("|")[0]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(360.0, 34.0)
		b.pressed.connect(func() -> void: _on_hold_selected(FAKE_STELLIUM_ID))
		_hold_list.add_child(b)
	_refresh_equip_grid()


func _on_hold_selected(id: String) -> void:
	var st = get_node("/root/DataManager").get_stellium(id)
	if st == null:
		return
	_selected_hold_id = id
	_preview_label.text = "属性预览｜%s（%s 槽%d）\n主词条：%s %s→%s\n2件套：%s\n3件套：%s\n强化：Lv.0（+2 解锁副词条，T6.5）" % [
		st.name, st.set_name, st.slot, st.main_stat.split("|")[0],
		st.main_base.split("|")[0], st.main_max.split("|")[0],
		st.set_2_bonus, st.set_3_bonus]
	_refresh_equip_grid()
	print("[CharListPanel] 持有星髓选中：%s（布局验证假数据，T6.5 接装备）" % id)


## ---------------------------------------------------------------
## 列表与编队
## ---------------------------------------------------------------

func _refresh_list() -> void:
	for c in _list_box.get_children():
		_list_box.remove_child(c)
		c.queue_free()
	var dm := get_node("/root/DataManager")
	var art := get_node("/root/ArtProvider")
	for id: String in dm.get_character_ids():
		var ch = dm.get_character(id)
		if ch == null:
			continue
		var b := Button.new()
		b.name = "Entry_%s" % id
		# ArtProvider 契约：get_portrait 入参=角色 id（预热缓存键/体系色查询均按角色 id）
		b.icon = art.get_portrait(id)
		b.add_theme_constant_override("icon_max_width", 40)
		b.text = "%s   Lv.1" % str(ch.name)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(264.0, 52.0)
		var cid := id
		b.pressed.connect(func() -> void: _select_character(cid))
		# 体系色角标（右缘 6px 色条）
		var badge := ColorRect.new()
		badge.color = art.get_system_color(id)
		badge.position = Vector2(264.0 - 8.0, 8.0)
		badge.size = Vector2(6.0, 36.0)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(badge)
		_list_box.add_child(b)
	if _char_id == "" and not _list_box.get_children().is_empty():
		_select_character(str(dm.get_character_ids()[0]))


func _select_character(id: String) -> void:
	_char_id = id
	_selected_hold_id = FAKE_STELLIUM_ID
	_refresh_char_page()
	_refresh_hold_list()
	_on_hold_selected(FAKE_STELLIUM_ID)
	print("[CharListPanel] 选中角色：%s" % id)


func _switch_page(idx: int) -> void:
	_page_index = idx
	for i in _pages.size():
		_pages[i].visible = i == idx


## 编队按钮：加入/移出（T2.2：API 返回 bool=是否变更；满员拒绝不替换）
func _on_party_btn() -> void:
	var party := get_node("/root/Party")
	var ok := false
	if party.has_member(_char_id):
		ok = party.remove_member(_char_id)
	else:
		ok = party.add_member(_char_id)
	if not ok:
		if party.is_full() and not party.has_member(_char_id):
			_warning.text = "编队已满（3/3）——请先移出一名角色，再加入。"
		else:
			_warning.text = "编队无变更。"
		print("[CharListPanel] 编队操作被拒绝：id=%s（满员引导）" % _char_id)
		return
	_warning.text = ""
	_refresh_party_btn()


func _refresh_party_btn() -> void:
	if _char_id == "":
		return
	var in_party: bool = get_node("/root/Party").has_member(_char_id)
	_party_btn.text = "移出编队" if in_party else "加入编队"


func _on_party_changed(_party_list: Array) -> void:
	_refresh_party_btn()


func _on_open() -> void:
	_warning.text = ""
	_refresh_list()
	if _char_id != "":
		_refresh_char_page()
		_refresh_hold_list()
