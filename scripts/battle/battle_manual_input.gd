extends Control
## =============================================================
## T3.10 自动/手动模式与目标选择（口径：战斗系统.md §6/§8/§8.2 + 制作人04 预裁定）
## -------------------------------------------------------------
## ① 右上角开关（§6）：默认「自动」；战斗中随时切换立即生效；
##    切换不重置跑条与充能（本组件无任何重置动作）。
## ② 手动状态机：IDLE → WAITING_INPUT（我方轮到出手，右下立绘下方并排
##    小技能/大招按钮；E=小技能 Q=大招）→ TARGETING（目标选择，§8.2 箭头）
##    → E/空格确认 / Esc 取消回 WAITING_INPUT。
##    大招充能未满按 Q 无效（控制台提示，§8.1）；满则按钮亮色闪光。
## ③ 指令提供协程 provide_command：BM._resolve_command await 调用——
##    自动模式立即返回 AI 占位指令（small 优先/满则 ult，目标随机选一个）；
##    敌方单位恒走 AI 分支（玩家不给敌人选技能）；手动模式等待玩家操作。
##    等待期间跑条动画暂停：后台阻塞在 provider（无新指令→无新结算）+
##    表现层该单位到达 100 的既有 _paused 机制（battle_speed_bar）天然覆盖，
##    SpeedBarSimulator / battle_speed_bar 零改动（任务卡"simulator 加 flag"
##    经核实无需——公式口径硬底线保持）。
## ④ 目标三字段驱动：BC.get_targets 五类映射（enemy single/column/all +
##    ally single/all）；column 前列/后列按移动键切换（§8.2）；all 免选
##    确认即释放。箭头调度经 battle_arena.show_arrows/hide_arrows。
## ⑥ 战斗内按键拦截：WAITING_INPUT/TARGETING 状态下 E/Q/方向/Esc/空格
##    set_input_as_handled（不落到跑图 interact——战斗 UI 优先消费）。
## 纪律：EventBus / project.godot / SpeedBarSimulator 零改动（InputMap 为
## 运行时兜底注册，非 project.godot 文件改动）。
## =============================================================

const BC := preload("res://scripts/battle/battle_command.gd")

enum Mode { AUTO, MANUAL }
enum St { IDLE, WAITING_INPUT, TARGETING }

## 手动指令就绪（provider 协程 await 此信号）：[Kind, target] 或 [Kind, target, col]
signal command_ready(cmd: Array)

## provider 完成回传（冒烟/调试轮询； provide_command 每次完成各发一次）
signal command_done(cmd: Array)

var mode := Mode.AUTO           # §8.1 默认自动
var st := St.IDLE
var last_cmd: Array = []        # 最近一次完成的指令（command_done 同内容，冒烟/调试用）
var _bm = null                  # BattleManager（读 units/组装指令）
var _arena = null               # BattleArena（箭头调度）
var _actor = null               # 当前等待指令的我方单位
var _kind := -1                 # TARGETING：已选技能
var _candidates: Array = []     # TARGETING：可选目标集合
var _sel := 0                   # TARGETING：当前选中下标（single 类）
var _col := "front"             # TARGETING：整列当前列（column 类）
var _btn_toggle: Button = null
var _btn_small: Button = null
var _btn_ult: Button = null
var _flash_t := 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)  # 铺满 BattleUI：子按钮锚点相对全屏（零尺寸 Control 会让锚点失效）
	_ensure_actions()
	_build_ui()
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## 每场战斗绑定（battle_controller 在 attach_battle 后调用；重试场次重绑新 bm）
func setup(bm, arena) -> void:
	_bm = bm
	_arena = arena
	bm.command_provider = provide_command
	st = St.IDLE
	_actor = null
	_candidates = []

## ------------------------------------------------------------
## 指令提供协程（BM._resolve_command await 调用；T3.3 同步 lambda 兼容不受影响）
## ------------------------------------------------------------
func provide_command(unit) -> Array:
	if not unit.is_ally or mode == Mode.AUTO:
		return _ai_command(unit)  # 敌方恒 AI；自动模式我方也 AI（无选择 UI §8.1）
	_actor = unit
	st = St.WAITING_INPUT
	_show_buttons(true)
	print("[MANUAL] WAITING_INPUT：%s 轮到出手（E=小技能 / Q=大招 / 右下按钮）" % str(unit.name))
	var cmd: Array = await command_ready
	_show_buttons(false)
	_arena.hide_arrows()
	st = St.IDLE
	_actor = null
	last_cmd = cmd
	command_done.emit(cmd)
	return cmd

## AI 占位（§8.1 自动：small 优先、ult 充能满才用；enemy 技能目标随机选一个；
## ally 技能（heal/shield/amp）结算归 T3.11——占位期不选目标走 execute 缺省路径
## （与 T3.9 前行为一致），避免"随机选队友+现状伤害管线"=AI 自伤）
func _ai_command(unit) -> Array:
	var kind := BC.Kind.ULT if unit.can_use_ult() else BC.Kind.SKILL
	var skill: Variant = unit.skill_ult if kind == BC.Kind.ULT else unit.skill_small
	if str(skill.target_side) == "ally":
		return [kind, null]
	var pool: Array = BC.get_targets(_bm.units, unit, skill)
	var target = pool.pick_random() if not pool.is_empty() else null
	return [kind, target]

## ------------------------------------------------------------
## 输入（战斗 UI 优先消费；仅手动等待/选择态拦截）
## ------------------------------------------------------------
func _input(e: InputEvent) -> void:
	if mode != Mode.MANUAL or st == St.IDLE:
		return
	var key := e as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if st == St.WAITING_INPUT:
		if key.physical_keycode == KEY_E:
			get_viewport().set_input_as_handled()
			_pick_skill(BC.Kind.SKILL)
		elif key.physical_keycode == KEY_Q:
			get_viewport().set_input_as_handled()
			_pick_skill(BC.Kind.ULT)
		elif key.physical_keycode == KEY_ESCAPE:
			# 等待态 Esc=维持等待（无取消语义，忽略即可）
			pass
	elif st == St.TARGETING:
		if key.physical_keycode == KEY_E or key.physical_keycode == KEY_SPACE:
			get_viewport().set_input_as_handled()
			_confirm()          # E 在选择状态=确认语义（§8.2）
		elif key.physical_keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_cancel()
		elif key.physical_keycode == KEY_LEFT or key.physical_keycode == KEY_A:
			get_viewport().set_input_as_handled()
			_move_selection(-1)
		elif key.physical_keycode == KEY_RIGHT or key.physical_keycode == KEY_D:
			get_viewport().set_input_as_handled()
			_move_selection(1)
		elif key.physical_keycode == KEY_UP or key.physical_keycode == KEY_W:
			get_viewport().set_input_as_handled()
			_move_selection(-1)
		elif key.physical_keycode == KEY_DOWN or key.physical_keycode == KEY_S:
			get_viewport().set_input_as_handled()
			_move_selection(1)

## 选定技能 → 进目标选择（§8.2）；大招未满按 Q 无效（§8.1 提示）
func _pick_skill(kind: int) -> void:
	if st != St.WAITING_INPUT or _actor == null:
		return
	if kind == BC.Kind.ULT and not _actor.can_use_ult():
		print("[MANUAL] %s 大招充能未满(%d/%d)，按 Q 无效" % [
			str(_actor.name), int(_actor.charge), int(_actor.charge_max)])
		return
	_kind = kind
	var skill: Variant = _actor.skill_ult if kind == BC.Kind.ULT else _actor.skill_small
	var scope := str(skill.target_scope)
	if scope == "all":
		_finish([_kind, null])  # 免选，确认即释放（§8.2）
		return
	if scope == "column":
		_col = "front"
		_candidates = BC.get_targets(_bm.units, _actor, skill, _col)
		_enter_targeting(true)   # 敌方整列=向下箭头 ×整列人数
	else:
		_candidates = BC.get_targets(_bm.units, _actor, skill)
		_sel = 0
		_enter_targeting(str(skill.target_side) == "enemy")

func _enter_targeting(down: bool) -> void:
	st = St.TARGETING
	var skill: Variant = _actor.skill_ult if _kind == BC.Kind.ULT else _actor.skill_small
	if str(skill.target_scope) == "column":
		_arena.show_arrows(_uidxs(_candidates), down)   # 整列=3 个箭头同显（§8.2）
	else:
		_arena.show_arrows([_bm.units.find(_candidates[_sel])], down)  # single=当前选中 1 个箭头
	print("[MANUAL] TARGETING：%s（%s/%s）可选目标 %d 个（方向键切换 / E=确认 / Esc=取消）" % [
		str(skill.id), str(skill.target_side), str(skill.target_scope), _candidates.size()])

## 移动键切换目标（§8.2）：single=目标间循环；column=前列/后列切换
func _move_selection(dir: int) -> void:
	if st != St.TARGETING or _actor == null or _candidates.is_empty():
		return
	var skill: Variant = _actor.skill_ult if _kind == BC.Kind.ULT else _actor.skill_small
	if str(skill.target_scope) == "column":
		var next_col := "back" if _col == "front" else "front"
		var pool: Array = BC.get_targets(_bm.units, _actor, skill, next_col)
		if pool.is_empty():
			print("[MANUAL] %s 列无存活敌人，保持 %s 列" % [next_col, _col])
			return
		_col = next_col
		_candidates = pool
		_arena.show_arrows(_uidxs(_candidates), true)
		print("[MANUAL] 整列切换 → %s 列（%d 个目标）" % [_col, _candidates.size()])
	else:
		_sel = wrapi(_sel + dir, 0, _candidates.size())
		var side_enemy := str(skill.target_side) == "enemy"
		_arena.show_arrows([_bm.units.find(_candidates[_sel])], side_enemy)
		print("[MANUAL] 目标切换 → %s（%s）" % [
			str(_candidates[_sel].name), "向下箭头" if side_enemy else "向上箭头"])

## 确认释放（E/空格）：single=选定目标；column=整列列名；all 已在 _pick_skill 直通
func _confirm() -> void:
	if st != St.TARGETING:
		return
	var skill: Variant = _actor.skill_ult if _kind == BC.Kind.ULT else _actor.skill_small
	if str(skill.target_scope) == "column":
		print("[MANUAL] 确认释放 %s → %s 列整列" % [str(skill.id), _col])
		_finish([_kind, null, _col])
	else:
		var t = _candidates[_sel] if not _candidates.is_empty() else null
		print("[MANUAL] 确认释放 %s → %s" % [str(skill.id), str(t.name) if t != null else "缺省"])
		_finish([_kind, t])

## Esc 取消（§8.2）：回 WAITING_INPUT 指令按钮（箭头清除）
func _cancel() -> void:
	if st != St.TARGETING:
		return
	_arena.hide_arrows()
	_candidates = []
	st = St.WAITING_INPUT
	print("[MANUAL] 取消选择，回指令按钮（E=小技能 / Q=大招）")

func _finish(cmd: Array) -> void:
	_candidates = []
	command_ready.emit(cmd)

## 右上角开关（§8.1）：立即生效；切换不重置跑条与充能；
## 手动→自动时若正在等待/选择，AI 立即代打本次（无感接管）
func _on_toggle() -> void:
	if mode == Mode.AUTO:
		mode = Mode.MANUAL
		_btn_toggle.text = "手动"
	else:
		mode = Mode.AUTO
		_btn_toggle.text = "自动"
		if st == St.TARGETING:
			_arena.hide_arrows()
			_finish(_ai_command(_actor))
		elif st == St.WAITING_INPUT:
			_finish(_ai_command(_actor))
	print("[MANUAL] 模式切换 → %s（立即生效，跑条/充能不重置）" % [
		"手动" if mode == Mode.MANUAL else "自动"])

## ------------------------------------------------------------
## UI（代码构建；Battle.tscn 零改动）
## ------------------------------------------------------------
func _build_ui() -> void:
	# 布局用固定坐标（MVP 设计视口 1152×648；本节点 PRESET_FULL_RECT 铺满
	# BattleUI 且位于 (0,0)，position 即屏幕坐标。实测 anchor_* 在
	# CanvasLayer 下树外赋值不可靠——global_position 落 (-268,-52) 屏外）
	_btn_toggle = Button.new()
	_btn_toggle.text = "自动"
	_btn_toggle.position = Vector2(1048, 12)
	_btn_toggle.size = Vector2(88, 32)
	_btn_toggle.pressed.connect(_on_toggle)
	add_child(_btn_toggle)
	# 右下角立绘下方并排两按钮（§6 指令按钮区）
	_btn_small = Button.new()
	_btn_small.text = "小技能 (E)"
	_btn_small.position = Vector2(884, 596)
	_btn_small.size = Vector2(120, 36)
	_btn_small.visible = false
	_btn_small.pressed.connect(func() -> void: _pick_skill(BC.Kind.SKILL))
	add_child(_btn_small)
	_btn_ult = Button.new()
	_btn_ult.text = "大招 (Q)"
	_btn_ult.position = Vector2(1012, 596)
	_btn_ult.size = Vector2(124, 36)
	_btn_ult.visible = false
	_btn_ult.pressed.connect(func() -> void: _pick_skill(BC.Kind.ULT))
	add_child(_btn_ult)

func _show_buttons(show: bool) -> void:
	_btn_small.visible = show
	_btn_ult.visible = show
	if show and _actor != null:
		_btn_ult.disabled = not _actor.can_use_ult()

## 大招按钮灰显/亮色闪光（§6：未满灰显、满则亮色闪光）
func _process(delta: float) -> void:
	if _btn_ult == null or not _btn_ult.visible:
		return
	if _actor != null and _actor.can_use_ult():
		_btn_ult.disabled = false
		_flash_t += delta
		_btn_ult.modulate = Color(1, 1, 1).lerp(Color(1.6, 1.45, 0.9), 0.5 + 0.5 * sin(_flash_t * 6.0))
	else:
		_btn_ult.disabled = true
		_btn_ult.modulate = Color(1, 1, 1)

## InputMap 运行时兜底注册（防编辑器覆写 project.godot 回滚丢失 E/Q action；
## 本组件按键判定直读 physical_keycode，双保险）
func _ensure_actions() -> void:
	_add_key_action("battle_skill_small", KEY_E)
	_add_key_action("battle_skill_ult", KEY_Q)

func _add_key_action(action: String, key: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)

func _uidxs(arr: Array) -> Array:
	var out: Array = []
	for t in arr:
		out.append(_bm.units.find(t))
	return out
