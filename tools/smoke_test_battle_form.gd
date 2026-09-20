extends SceneTree
## =============================================================
## T3.9 阵型冒烟（headless：先设 GODOT_MCP_RUNTIME_PORT='abc' 再
## godot --headless --path . --script res://tools/smoke_test_battle_form.gd
## 输出重定向 tools/.smoke_battle_arena.log 与 T2.11 共享日志隔离）
## -------------------------------------------------------------
## A. 阵型数学断言（battle_form_layout.take_param，纯函数）：
##    ally 右下排列 / 45° 斜向（front-ally 列向量 Δx=+、Δy=- 等幅）/
##    后列更右更上 / 我方左下·敌右上 / 第二列空白（间距 2 列）
## B. 战场站位断言（Battle.tscn + setup_stances）：
##    1/3/6 敌编组节点数与位置（6 敌=front3+back3，back 全在 front 右侧）、
##    头顶血条组件（敌我均有 HpFg）、我方有体系图标 SystemIcon 敌方无、
##    无棋盘格渲染（单位 root 下无格线节点）
## C. 多敌战斗流程（3v6 混元编组 BM 直跑 → win）
## =============================================================

const FORM := preload("res://scripts/battle/battle_form_layout.gd")
const BATTLE_SCENE := preload("res://scenes/Battle.tscn")
const DMS := preload("res://scripts/core/DataManager.gd")
const BM := preload("res://scripts/battle/battle_manager.gd")

const PARTY := ["awakened_mech_01", "awakened_arcane_01", "awakened_xian_01"]

var _failed := false
var _n := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var dm = DMS.new()
	dm._load_all()  # headless --script 不触发 autoload _ready，需手动同步加载
	print("=== T3.9 阵型冒烟开始 ===")
	_test_form_math()
	var arena = BATTLE_SCENE.instantiate()
	root.add_child(arena)
	_test_stances(arena, 1)
	_test_stances(arena, 3)
	_test_stances(arena, 6)
	await _test_battle_flow(dm)
	arena.queue_free()
	if _failed:
		print("=== T3.9 阵型冒烟结束：存在失败项 ===")
		quit(1)
	else:
		print("=== T3.9 阵型冒烟结束：全部通过 ===")
		quit(0)

## A. 阵型纯数学断言（无场景依赖）
func _test_form_math() -> void:
	var form: Dictionary = FORM.take_param(Vector2(1152, 648), 3, 4)
	var ally: Array = form["ally"]
	var front: Array = form["enemy_front"]
	var back: Array = form["enemy_back"]
	_check(ally.size() == 3 and front.size() == 3 and back.size() == 3)
	# ① 我方第一列沿右下斜向排列（行 r 增大 → x 增、y 增）
	_check(ally[1].x > ally[0].x and ally[1].y > ally[0].y)
	_check(ally[2].x > ally[1].x and ally[2].y > ally[1].y)
	# ② 45° 斜向：front-ally 列向量 Δx>0、Δy<0 且等幅（右边缘上斜 45°）
	for i in 3:
		var d: Vector2 = front[i] - ally[i]
		_check(d.x > 0.0 and d.y < 0.0)
		_check(absf(absf(d.x) - absf(d.y)) < 0.01)
	# ③ 后列（第四列）比前列（第三列）更右更上（back-front 列向量同向 45°）
	for i in 3:
		var d: Vector2 = back[i] - front[i]
		_check(d.x > 0.0 and d.y < 0.0)
		_check(absf(absf(d.x) - absf(d.y)) < 0.01)
	# ④ 我方左下 / 敌右上：ally 平均 x < front 平均 x、ally 平均 y > front 平均 y
	var ax: float = (ally[0].x + ally[1].x + ally[2].x) / 3.0
	var ay: float = (ally[0].y + ally[1].y + ally[2].y) / 3.0
	var fx: float = (front[0].x + front[1].x + front[2].x) / 3.0
	var fy: float = (front[0].y + front[1].y + front[2].y) / 3.0
	var bx: float = (back[0].x + back[1].x + back[2].x) / 3.0
	var by: float = (back[0].y + back[1].y + back[2].y) / 3.0
	_check(ax < fx and ax < bx and ay > fy and ay > by)  # 我方整体更左下
	_check(bx > fx and by < fy)                          # 敌方后列更右上
	# ⑤ 第二列空白：前列-我方间距 = 2 列 > 后列-前列间距 = 1 列（中间隔一空列）
	_check((front[0].x - ally[0].x) > (back[0].x - front[0].x))
	print("[SMOKE] A 阵型数学: ally=%s front=%s back=%s" % [str(ally), str(front), str(back)])

## B. 战场站位断言：Battle.tscn 实例调 setup_stances，检查节点数/位置/头顶组件
func _test_stances(arena, enemy_n: int) -> void:
	var enemy_ids: Array = []
	for i in enemy_n:
		enemy_ids.append("corrosion_beast")
	arena.setup_stances(PARTY, enemy_ids)
	var allies: Array = arena._allies.get_children()
	var enemies: Array = arena._enemies.get_children()
	_check(allies.size() == 3)
	_check(enemies.size() == enemy_n)
	# 头顶血条组件：敌我均有 HpFg；我方有体系图标 SystemIcon、敌方无
	var ally0: Node = allies[0]
	var en0: Node = enemies[0]
	_check(ally0.get_node_or_null("HpFg") != null and ally0.get_node_or_null("HpBg") != null)
	_check(ally0.get_node_or_null("SystemIcon") != null)
	_check(en0.get_node_or_null("HpFg") != null and en0.get_node_or_null("HpBg") != null)
	_check(en0.get_node_or_null("SystemIcon") == null)
	_check(ally0.get_node_or_null("Sprite") != null and ally0.get_node_or_null("NameLabel") != null)
	# 无棋盘格渲染：单位 root 下无格线/格底节点（本层只建单位+头顶组件）
	_check(_no_grid_nodes(ally0) and _no_grid_nodes(en0))
	# 6 敌：前列（前 3 个=第三列）与后列（后 3 个=第四列）逐行配对——同行后列更右
	if enemy_n == 6:
		for i in 3:
			_check(enemies[i].position.x < enemies[3 + i].position.x)
	print("[SMOKE] B 站位 n=%d: allies=%d enemies=%d" % [enemy_n, allies.size(), enemies.size()])

func _no_grid_nodes(unit_root: Node) -> bool:
	for c in unit_root.get_children():
		var cn := str(c.name).to_lower()
		if cn.contains("grid") or cn.contains("cell"):
			return false
	return true

## C. 3v6 多敌战斗流程通（进战斗→出手→结算）
func _test_battle_flow(dm) -> void:
	var enemy_ids: Array = []
	for i in 6:
		enemy_ids.append("corrosion_beast")
	var bm = BM.new(dm, PARTY, enemy_ids)
	bm.force_crit = 0
	for i in 6:
		bm.units[3 + i].max_hp = 20  # 占位削弱兽血，保证 6 轮内分胜负（不改 CSV）
		bm.units[3 + i].hp = 20
	var result: String = await bm.run_to_end(6)
	print("[SMOKE] C 3v6: result=%s rounds=%d orders=%s" % [
		result, bm.round_num, str(bm.round_orders)])
	_check(result == "win")
	_check(bm.round_num <= 6)

func _check(cond: bool) -> void:
	_n += 1
	if not cond:
		_failed = true
		print("[SmokeTest] 第 %d 个断言失败" % _n)
		push_error("[SmokeTest] 断言失败")
