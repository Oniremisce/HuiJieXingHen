## =============================================================
## 《汇界星痕》T2.5 任务面板（J 键，架构 §3.3 三色分组）
## -------------------------------------------------------------
## 全屏列表按 主线/支线/心契 三组（组头三色：主线 #FFA640 橘黄 /
## 支线 #6FC9FF 淡蓝 / 心契 #FF8FC8 粉红）；条目 = 任务名 + 当前步骤 +
## 目标进度。QuestRunner 未就绪（T5.4 接进度系统）→ 直接读 quests.csv
## 列骨架：每任务显示 step 1 的步骤名与目标，进度 0/1 占位。
## 分组规则：quest_id 前缀 heartbond → 心契，side → 支线，其余 → 主线。
## =============================================================
extends UIPanelScript

const UIPanelScript := preload("res://scripts/ui/UIPanel.gd")

const PANEL_RECT := Rect2(196.0, 54.0, 760.0, 540.0)
const GROUP_COLORS := {
	"主线": Color("FFA640"),
	"支线": Color("6FC9FF"),
	"心契": Color("FF8FC8"),
}
const GROUP_ORDER: Array[String] = ["主线", "支线", "心契"]


func _init() -> void:
	panel_name = "quest"
	layer = 92


func _build_ui() -> void:
	var dim := _make_dim()
	var panel := _make_panel(dim, PANEL_RECT)
	_make_title(panel, "任务")
	_make_hint(panel, "J 关闭  |  Esc 回上一层")

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.position = Vector2(16.0, 44.0)
	scroll.size = Vector2(PANEL_RECT.size.x - 32.0, PANEL_RECT.size.y - 84.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var list := VBoxContainer.new()
	list.name = "QuestList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)


func _on_open() -> void:
	var list: VBoxContainer = get_node("Dim/Panel/Scroll/QuestList")
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	var dm := get_node("/root/DataManager")
	# 按分组归桶（quest_id 前缀判定；无进度系统，桶内 = CSV 全量骨架）
	var buckets := {"主线": [], "支线": [], "心契": []}
	for quest_id: String in dm.get_quest_ids():
		var group := "主线"
		if quest_id.begins_with("heartbond"):
			group = "心契"
		elif quest_id.begins_with("side"):
			group = "支线"
		buckets[group].append(quest_id)

	for group_name: String in GROUP_ORDER:
		var head := Label.new()
		head.text = "■ %s%s" % [group_name, "（%d）" % (buckets[group_name] as Array).size()]
		head.add_theme_font_size_override("font_size", 16)
		head.add_theme_color_override("font_color", GROUP_COLORS[group_name])
		list.add_child(head)
		if (buckets[group_name] as Array).is_empty():
			var none := Label.new()
			none.text = "    暂无任务"
			none.add_theme_font_size_override("font_size", 13)
			none.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
			list.add_child(none)
			continue
		for quest_id: String in buckets[group_name]:
			list.add_child(_make_entry(dm, quest_id))


## 条目 = 任务名 + 当前步骤 + 目标进度（无 QuestRunner → step 1 骨架 0/1）
func _make_entry(dm: Node, quest_id: String) -> Control:
	var steps: Array = dm.get_quest(quest_id)
	var cur = steps[0] if not steps.is_empty() else null
	var box := PanelContainer.new()
	var margin := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 8)
	box.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	margin.add_child(vb)

	var title := Label.new()
	title.text = "任务：%s" % quest_id
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	vb.add_child(title)

	var body := Label.new()
	if cur != null:
		body.text = "当前步骤 %d：%s\n目标：%s（%s）    进度：0/1    奖励：%s" % [
			cur.step, cur.step_name, cur.requirement, cur.target, cur.reward]
	else:
		body.text = "（无步骤数据）"
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	vb.add_child(body)
	return box
