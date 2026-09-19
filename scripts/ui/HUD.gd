## =============================================================
## 《汇界星痕》T2.3 常驻 HUD（架构 §2.6 四区）
## -------------------------------------------------------------
## 左上：主角名「异乡人」占位 + 编队头像（EventBus.party_changed
##   驱动重建，ArtProvider.get_portrait 占位色块）+ 任务追踪占位；
## 右上：小地图（Minimap，箱庭线框缩小版）；
## 底部：交互提示挂点（Label，T4.x 消费）+ 按键提示条（首进 8s 淡出）。
## 挂载：MapSystem._ensure_ui 守卫加载，常驻跨场景。
## =============================================================
extends CanvasLayer

const _Minimap := preload("res://scripts/ui/Minimap.gd")

const PLAYER_NAME := "异乡人"   # 主角名占位（剧情文案定名后替换）
const KEYS_HINT_TEXT := "B 背包   C 角色   G 技能   J 任务   M 地图   Esc 关闭/菜单"
const QUEST_PLACEHOLDER := "任务：暂无追踪目标"
const KEYS_TIP_DURATION := 8.0  # 按键提示条停留时长（秒）

var _party_box: HBoxContainer
var _hint_label: Label
var _keys_bar: Label
var _minimap: Node2D
var _tip_elapsed := 0.0
var _tip_fading := false


func _ready() -> void:
	_build_ui()
	var bus := get_node("/root/EventBus")
	bus.party_changed.connect(_on_party_changed)
	# 初始编队（存档读档后 party_changed 亦会驱动）
	_on_party_changed(get_node("/root/Party").get_members())


func _process(delta: float) -> void:
	# 按键提示条：首进停留 8s 后淡出（HUD 常驻 → 仅本进程一次）
	if _keys_bar != null and not _tip_fading:
		_tip_elapsed += delta
		if _tip_elapsed >= KEYS_TIP_DURATION:
			_tip_fading = true
			var tw := create_tween()
			tw.tween_property(_keys_bar, "modulate:a", 0.0, 1.2)


# ---------------------------------------------------------------
# UI 构建（代码构建）
# ---------------------------------------------------------------

func _build_ui() -> void:
	# 左上：名字 + 编队头像 + 任务追踪占位
	var top_left := VBoxContainer.new()
	top_left.name = "TopLeft"
	top_left.position = Vector2(16.0, 12.0)
	top_left.add_theme_constant_override("separation", 6)
	add_child(top_left)

	var name_label := Label.new()
	name_label.name = "PlayerName"
	name_label.text = PLAYER_NAME
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	name_label.add_theme_color_override("font_outline_color", Color(0.08, 0.1, 0.14))
	name_label.add_theme_constant_override("outline_size", 4)
	top_left.add_child(name_label)

	_party_box = HBoxContainer.new()
	_party_box.name = "PartyPortraits"
	_party_box.add_theme_constant_override("separation", 6)
	top_left.add_child(_party_box)

	var quest_label := Label.new()
	quest_label.name = "QuestTrack"
	quest_label.text = QUEST_PLACEHOLDER
	quest_label.add_theme_font_size_override("font_size", 13)
	quest_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7, 0.9))
	quest_label.add_theme_color_override("font_outline_color", Color(0.08, 0.1, 0.14))
	quest_label.add_theme_constant_override("outline_size", 3)
	top_left.add_child(quest_label)

	# 右上：小地图
	_minimap = _Minimap.new()
	_minimap.name = "Minimap"
	_minimap.position = Vector2(1152.0 - 176.0, 16.0)
	add_child(_minimap)

	# 底部：交互提示挂点（T4.x 交互提示消费位）
	_hint_label = Label.new()
	_hint_label.name = "InteractHint"
	_hint_label.text = ""
	_hint_label.position = Vector2(376.0, 648.0 - 96.0)
	_hint_label.size = Vector2(400.0, 26.0)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 14)
	_hint_label.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	_hint_label.add_theme_color_override("font_outline_color", Color(0.08, 0.1, 0.14))
	_hint_label.add_theme_constant_override("outline_size", 4)
	add_child(_hint_label)

	# 底部：按键提示条（首进 8s 淡出）
	_keys_bar = Label.new()
	_keys_bar.name = "KeysHint"
	_keys_bar.text = KEYS_HINT_TEXT
	_keys_bar.position = Vector2(276.0, 648.0 - 46.0)
	_keys_bar.size = Vector2(600.0, 24.0)
	_keys_bar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_keys_bar.add_theme_font_size_override("font_size", 13)
	_keys_bar.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.75))
	_keys_bar.add_theme_color_override("font_outline_color", Color(0.08, 0.1, 0.14))
	_keys_bar.add_theme_constant_override("outline_size", 3)
	add_child(_keys_bar)


# ---------------------------------------------------------------
# 编队头像（party_changed 驱动全量重建）
# ---------------------------------------------------------------

func _on_party_changed(party_list: Array) -> void:
	if _party_box == null:
		return
	for c in _party_box.get_children():
		_party_box.remove_child(c)
		c.queue_free()
	var art := get_node("/root/ArtProvider")
	var dm := get_node("/root/DataManager")
	for id: String in party_list:
		var portrait_id := id
		var data = dm.get_character(id)
		if data != null:
			portrait_id = data.portrait_id
		var tex: Texture2D = art.get_portrait(portrait_id)
		var tr := TextureRect.new()
		tr.name = "Portrait_%s" % id
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.custom_minimum_size = Vector2(44.0, 44.0)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.tooltip_text = id
		_party_box.add_child(tr)
	if party_list.is_empty():
		var empty := Label.new()
		empty.text = "（空编队）"
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
		_party_box.add_child(empty)
