extends Control
## =============================================================
## T3.8 速度条 UI + 跑条动画（表现层；口径：战斗系统.md §2/§6 + 美术01 视觉口径）
## -------------------------------------------------------------
## 布局（§2.1/§6；T3.12 修订：高度=屏幕竖向高度×1/3、跑条方向自上而下）：
## 屏幕左侧竖向细长条（条宽 20 / 距左 16 / 上留白 32，条高=视口高×1/3），
## 我方与敌人圆形小头像（直径 = 条宽 × 2 = 40，§2.1 硬约束）置条上随位置实时移动。
## 跑条动画（§2.3）：按当前出战存活单位平均跑条速度换算——平均速度单位
## 完整跑完全条 = RUNBAR_FULL_TIME 秒；各头像按自身 spd 呈现相对快慢；
## 表现层到达 100（=出手瞬间）跑条暂停并金环脉冲，收到演出播毕通知后
## 该头像归 0、其余继续前推；暂停期间全部头像降饱和标记（§2.6）。
## 后台/表现解耦（硬底线）：出手先后判定仍走 SpeedBarSimulator.simulate_round
## （本脚本不修改其口径与返回值）；本层只读 bm.round_orders / units / state
## 做同步表现，不改变战斗节奏与胜负。
## 演出接线：make_cutscene_proxy(real) 返回转发代理（保持 bm.cutscene 既有
## play_active/play_skill/play_ult/play_combo 四方法契约），每个演出方法
## 播毕通知本层放行跑条（§2.2/§7 演出暂停 → 播毕恢复推进）。
## 已知近似（登记交接班表）：后台节奏快于表现重放时，演出与暂停存在
## ≤1 个行动的视觉错位；合击/拉条演出期间暂停依赖其后一次播毕通知放行。
## 冒烟入口：_advance(delta) 公开（_process 直通）；avatar_bar_pos(i) 断言条位。
## =============================================================

## §2.3 表现基准：平均速度单位跑完全条秒数（暴露可调，禁止就地硬编码）。
## static var：默认 1.0；运行时可改值验证（MCP execute_code / 冒烟），日志可证。
static var RUNBAR_FULL_TIME := 1.0

# ---- 视觉口径常量（美术01 T3.8 ○核对行，制作人04 预裁定①）----
const BAR_W := 20.0
const BAR_LEFT := 16.0
const BAR_TOP := 32.0
const COL_BG := Color(0.12549, 0.14118, 0.18039, 0.85)    # #20242E @85%
const COL_FILL := Color(0.90980, 0.92549, 0.94902)        # #E8ECF2 中性冷白
const COL_TICK := Color(1.0, 1.0, 1.0, 0.30)              # 0/50/100 刻度 1px 白 30%
const COL_GOLD := Color(0.94118, 0.70588, 0.16078)        # #F0B429 出手脉冲/终点线
const COL_ENEMY_RING := Color(0.70196, 0.29020, 0.23529)  # #B34A3C 敌方暗红环
const AVATAR_D := 40.0        # 圆形头像直径 = 条宽 × 2（§2.1 硬约束）
const AVATAR_RING_W := 3.0    # 体系色环 3px / 敌方暗红 3px + 1px 白描边
const PULSE_TIME := 0.3       # 出手瞬间金环脉冲 0.3s
const PAUSE_DIM := 0.45       # 暂停跑条标记：降饱和 60%（占位=压暗调制）
const DEAD_DIM := 0.30        # 阵亡置灰

## §2.1/§6（T3.12 修订①）：条高 = 屏幕竖向高度 × 1/3（实时读视口，非固定常量）
func bar_len() -> float:
	return maxf(1.0, get_viewport_rect().size.y / 3.0)

var bm = null                 # 只读引用：BattleManager 或同构鸭子（冒烟注入）
var acting_uid := ""          # 当前激活回合单位 id（PartyRow 高亮消费）
var _units: Array = []
var _avatars: Array = []      # Array[Dictionary]：root/ring_sb/ring_base/d
var _order: Array = []        # 当轮出手序（只读快照 bm.round_orders[r-1]）
var _rate: Array = []         # spd/avg（平均速度单位 = 1.0）
var _tau: Array = []          # 各单位到达 100 的表现时刻（秒）
var _clock := 0.0             # 表现层跑条时钟（秒）
var _replay_round := -1
var _next_idx := 0
var _paused := false          # 到达 100 待出手（跑条暂停）
var _last_arrived := -1
var last_arrival_clock := -1.0  # 最近一次到达的表现时刻=其 τ（冒烟断言用）
var _parked := {}             # 已出手归 0 / 阵亡跳过
var _ended := false           # WIN/LOSE 终局冻结

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## 绑定战斗状态机（每场战斗/每次重试各调一次；只读，不改 bm 任何字段）
func attach_battle(b) -> void:
	bm = b
	_reset_replay()
	_build_avatars()
	print("[SPEEDBAR] attach：units=%d RUNBAR_FULL_TIME=%.2f" % [_units.size(), RUNBAR_FULL_TIME])

## 演出转发代理：保持 bm.cutscene 既有四方法契约（T3.6 注入约定不变）；
## skill/ult/combo 播毕通知本层放行跑条（§2.2 演出暂停 → 播毕恢复推进）
class CutsceneProxy:
	extends RefCounted
	var real = null
	var bar = null

	func _notify_closed() -> void:
		if bar != null:
			bar._on_window_closed()

	func play_active(id: String) -> void:
		if real != null and real.has_method("play_active"):
			await real.play_active(id)

	func play_skill(id: String, skill_id: String) -> void:
		if real != null and real.has_method("play_skill"):
			await real.play_skill(id, skill_id)
		_notify_closed()

	func play_ult(id: String, skill_id: String) -> void:
		if real != null and real.has_method("play_ult"):
			await real.play_ult(id, skill_id)
		_notify_closed()

	func play_combo(combo_name: String = "三人合击") -> void:
		if real != null and real.has_method("play_combo"):
			await real.play_combo(combo_name)
		_notify_closed()

func make_cutscene_proxy(real_cutscene) -> RefCounted:
	var p := CutsceneProxy.new()
	p.real = real_cutscene
	p.bar = self
	return p

## ------------------------------------------------------------
## 表现层主循环（_process 直通 _advance，冒烟可手动驱动）
## ------------------------------------------------------------
func _process(delta: float) -> void:
	_advance(delta)

func _advance(delta: float) -> void:
	if bm == null:
		return
	# 终局冻结（BM.State.WIN=3/LOSE=4；鸭子注入同构 int，§6 参战行常显另由 PartyRow 负责）
	if not _ended and int(bm.state) >= 3:
		_ended = true
		_paused = false
		acting_uid = ""
	if _ended:
		_apply_positions()
		return
	var rn := int(bm.round_num)
	var orders: Array = bm.round_orders
	if rn >= 1 and rn != _replay_round and rn <= orders.size():
		_sync_round(rn)
	if _order.is_empty():
		return
	if not _paused:
		_clock += delta
		_process_arrivals()
	_apply_positions()

## 出手瞬间处理：到达 100 → 暂停 + 金环脉冲 + 记激活单位（§2.3/§2.6）
func _process_arrivals() -> void:
	while _next_idx < _order.size():
		var idx := int(_order[_next_idx])
		if not _alive(idx):
			_parked[idx] = true  # 阵亡跳过（与后台「死亡不出手」同口径）
			_next_idx += 1
			continue
		if float(_tau[idx]) > _clock + 0.0001:
			return               # 尚未到达：继续前推
		last_arrival_clock = float(_tau[idx])  # 到达时刻=τ（时钟保持单调，过冲≤1帧）
		_last_arrived = idx
		_paused = true          # 出手回合：跑条动画暂停
		_next_idx += 1
		acting_uid = str(_units[idx].id)
		_pulse_avatar(idx)
		print("[SPEEDBAR] R%d %s 到达100（跑条暂停，降饱和）" % [int(bm.round_num), str(_units[idx].name)])
		return
	# 本轮全部到达处理完：全员归 0 待命，等后台进入下一回合（_sync_round 归零）

## 演出播毕通知（CutsceneProxy 回调）：出手单位归 0，恢复跑条循环
func _on_window_closed() -> void:
	if _paused:
		if _last_arrived >= 0:
			_parked[_last_arrived] = true  # 出手后归 0（§2.2）
			_last_arrived = -1
		_paused = false

## 回合同步：全员置 0（§2.1），按当前出战存活单位均速重算相对速率
func _sync_round(rn: int) -> void:
	_replay_round = rn
	_order = (orders_at(rn - 1) as Array).duplicate()
	_clock = 0.0
	_next_idx = 0
	_paused = false
	_last_arrived = -1
	_parked.clear()
	acting_uid = ""
	var spd_alive: Array = []
	for i in _units.size():
		if _alive(i):
			spd_alive.append(maxf(1.0, float(_units[i].spd)))
	var avg := 1.0
	if not spd_alive.is_empty():
		var s := 0.0
		for v in spd_alive:
			s += v
		avg = s / float(spd_alive.size())
	_rate.clear()
	_tau.clear()
	for i in _units.size():
		var r := maxf(1.0, float(_units[i].spd)) / avg  # 平均速度单位 = 1.0
		_rate.append(r)
		_tau.append(RUNBAR_FULL_TIME / r)
	var first_tau := RUNBAR_FULL_TIME
	for i in _order.size():
		var idx := int(_order[i])
		if _alive(idx):
			first_tau = float(_tau[idx])
			break
	print("[SPEEDBAR] R%d 跑条开始 avg_spd=%.2f 首达=%.3fs（RUNBAR_FULL_TIME=%.2f）" % [
		rn, avg, first_tau, RUNBAR_FULL_TIME])

func orders_at(i: int) -> Variant:
	return bm.round_orders[i]

## 条位模型：0~100（parked=0 / 已到达=100 / 其余=100×rate×clock/RUNBAR_FULL_TIME）
func _bar_pos(i: int) -> float:
	if _parked.has(i):
		return 0.0
	if i == _last_arrived:
		return 100.0
	if i >= _rate.size():
		return 0.0
	return minf(100.0, 100.0 * float(_rate[i]) * _clock / RUNBAR_FULL_TIME)

## 冒烟/断言入口：第 i 个头像的条位（0~100）
func avatar_bar_pos(i: int) -> float:
	return _bar_pos(i)

## 运行时调参入口（T3.8 真机验证：MCP execute_code 调用，改值日志可证生效）
func set_runbar_full_time(v: float) -> void:
	RUNBAR_FULL_TIME = v

func _alive(i: int) -> bool:
	if i < 0 or i >= _units.size():
		return false
	var u = _units[i]
	if u == null:
		return false
	if u.has_method("is_alive"):
		return bool(u.is_alive())
	return float(u.hp) > 0.0

## ------------------------------------------------------------
## 视觉构建与逐帧应用
## ------------------------------------------------------------
func _reset_replay() -> void:
	_order = []
	_rate = []
	_tau = []
	_clock = 0.0
	_replay_round = -1
	_next_idx = 0
	_paused = false
	_last_arrived = -1
	last_arrival_clock = -1.0
	_parked = {}
	_ended = false
	acting_uid = ""

func _build_avatars() -> void:
	for av in _avatars:
		var ctrl: Control = av["root"]
		if is_instance_valid(ctrl):
			ctrl.queue_free()
	_avatars.clear()
	_units = bm.units if bm != null else []
	var art := get_node_or_null("/root/ArtProvider")
	for i in _units.size():
		var u = _units[i]
		var ally := bool(u.is_ally)
		var d := AVATAR_D + (2.0 if not ally else 0.0)  # 敌方含 1px 白描边
		var root := Control.new()
		root.size = Vector2(d, d)
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var inset := 1.0 if not ally else 0.0
		# 底板（圆裁切容器）
		var clip := Panel.new()
		clip.set_anchors_preset(Control.PRESET_FULL_RECT)
		clip.offset_left = inset
		clip.offset_top = inset
		clip.offset_right = -inset
		clip.offset_bottom = -inset
		var cb := StyleBoxFlat.new()
		cb.bg_color = Color(1, 1, 1)
		cb.set_corner_radius_all(int(AVATAR_D * 0.5))
		clip.add_theme_stylebox_override("panel", cb)
		clip.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tr := TextureRect.new()
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.texture = _avatar_texture(str(u.id), art)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.add_child(tr)
		root.add_child(clip)
		# 体系色/敌方环
		var ring := Panel.new()
		ring.set_anchors_preset(Control.PRESET_FULL_RECT)
		ring.offset_left = inset
		ring.offset_top = inset
		ring.offset_right = -inset
		ring.offset_bottom = -inset
		var rb := StyleBoxFlat.new()
		rb.draw_center = false
		rb.set_border_width_all(int(AVATAR_RING_W))
		rb.set_corner_radius_all(int(AVATAR_D * 0.5))
		var base := _ring_color(str(u.id), ally, art)
		rb.border_color = base
		ring.add_theme_stylebox_override("panel", rb)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(ring)
		# 敌方外圈 1px 白描边
		if not ally:
			var outline := Panel.new()
			outline.set_anchors_preset(Control.PRESET_FULL_RECT)
			var ob := StyleBoxFlat.new()
			ob.draw_center = false
			ob.set_border_width_all(1)
			ob.border_color = Color(1, 1, 1)
			ob.set_corner_radius_all(int(d * 0.5))
			outline.add_theme_stylebox_override("panel", ob)
			outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(outline)
		add_child(root)
		_avatars.append({"root": root, "ring_sb": rb, "ring_base": base, "d": d})
	queue_redraw()

## 立绘唯一入口 ArtProvider.get_portrait（T2.6 契约）：取上部正方形裁圆
func _avatar_texture(id: String, art) -> Texture2D:
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

func _ring_color(id: String, ally: bool, art) -> Color:
	if not ally:
		return COL_ENEMY_RING
	if art != null and art.has_method("get_system_color"):
		return art.get_system_color(id)
	return Color(0.6, 0.6, 0.6)

## 出手瞬间金环脉冲 0.3s（§2.6）：金→基色渐隐
func _pulse_avatar(idx: int) -> void:
	if idx < 0 or idx >= _avatars.size():
		return
	var sb: StyleBoxFlat = _avatars[idx]["ring_sb"]
	var base: Color = _avatars[idx]["ring_base"]
	var tw := create_tween()
	tw.tween_method(func(c: Color): sb.border_color = c, COL_GOLD, base, PULSE_TIME)

func _apply_positions() -> void:
	var bl := bar_len()
	for i in _avatars.size():
		var pos := _bar_pos(i)
		var av: Dictionary = _avatars[i]
		var ctrl: Control = av["root"]
		var d: float = av["d"]
		# T3.12 修订②：顶端=0、底端=100，头像 y 随条位自上而下
		ctrl.position = Vector2(
			BAR_LEFT + BAR_W * 0.5 - d * 0.5,
			BAR_TOP + pos / 100.0 * bl - d * 0.5)
		var dim := 1.0
		if not _alive(i):
			dim = DEAD_DIM
		elif _paused:
			dim = PAUSE_DIM
		ctrl.modulate = Color(dim, dim, dim)
	queue_redraw()

## 条体绘制：深底 + 冷白进度（取最高条位）+ 0/50/100 刻度 + 100 金色终点线
## T3.12 修订②：进度自顶端（0）向下（100）填充，终点线=底端
func _draw() -> void:
	var bl := bar_len()
	var bottom := BAR_TOP + bl
	draw_rect(Rect2(BAR_LEFT, BAR_TOP, BAR_W, bl), COL_BG)
	var max_pos := 0.0
	for i in _avatars.size():
		max_pos = maxf(max_pos, _bar_pos(i))
	var fh := bl * max_pos / 100.0
	if fh > 0.5:
		draw_rect(Rect2(BAR_LEFT, BAR_TOP, BAR_W, fh), COL_FILL)
	for p in [0.0, 50.0, 100.0]:
		var y: float = BAR_TOP + float(p) / 100.0 * bl
		draw_rect(Rect2(BAR_LEFT - 2.0, y - 0.5, BAR_W + 4.0, 1.0), COL_TICK)
	draw_rect(Rect2(BAR_LEFT - 2.0, bottom - 1.0, BAR_W + 4.0, 2.0), COL_GOLD)
