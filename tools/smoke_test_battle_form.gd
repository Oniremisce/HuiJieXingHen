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
	_test_anchors(arena)
	await _test_battle_flow(dm)
	arena.queue_free()
	if _failed:
		print("=== T3.9 阵型冒烟结束：存在失败项 ===")
		quit(1)
	else:
		print("=== T3.9 阵型冒烟结束：全部通过 ===")
		quit(0)

## A. 阵型纯数学断言（无场景依赖；返工几何：参考图观感 + UI 避让硬约束）
func _test_form_math() -> void:
	var vs := Vector2(1152, 648)
	var form: Dictionary = FORM.take_param(vs, 3, 4)
	var ally: Array = form["ally"]
	var front: Array = form["enemy_front"]
	var back: Array = form["enemy_back"]
	_check(ally.size() == 3 and front.size() == 3 and back.size() == 3)
	# ① 行方向（列内相邻行）：向右下缓斜 10°（Δx>0、Δy>0、斜率≈tan10°）
	var tan10 := 0.17633  # tan(10°)
	for arr in [ally, front, back]:
		for i in 2:
			var d: Vector2 = arr[i + 1] - arr[i]
			_check(d.x > 0.0 and d.y > 0.0)
			_check(absf(d.y / d.x - tan10) < 0.02)
			_check(absf(d.x - vs.x * 0.095 * cos(deg_to_rad(10.0))) < 0.5)  # 行距=0.095W
	# ② 敌方前列比我方更右更上（front-ally 同行向量 Δx>0、Δy<0）
	for i in 3:
		var d: Vector2 = front[i] - ally[i]
		_check(d.x > 0.0 and d.y < 0.0)
	# ③ 敌方后列比前列更高（back-front Δy<0）且略偏右
	for i in 3:
		var d: Vector2 = back[i] - front[i]
		_check(d.y < 0.0 and d.x > 0.0)
	# ④ 观感带：我方横排左中（y≈0.475H）、敌前右中（y≈0.420H）、敌后右上（y≈0.280H）
	var ay: float = (ally[0].y + ally[1].y + ally[2].y) / 3.0
	var fy: float = (front[0].y + front[1].y + front[2].y) / 3.0
	var by: float = (back[0].y + back[1].y + back[2].y) / 3.0
	_check(absf(ay - vs.y * 0.475 - vs.x * 0.095 * sin(deg_to_rad(10.0))) < 1.0)
	_check(absf(fy - vs.y * 0.420 - vs.x * 0.095 * sin(deg_to_rad(10.0))) < 1.0)
	_check(absf(by - vs.y * 0.280 - vs.x * 0.095 * sin(deg_to_rad(10.0))) < 1.0)
	_check(ally[0].x < vs.x * 0.25 and front[0].x > vs.x * 0.5)  # 我方左、敌右
	# ⑤ UI 避让硬断言（模型 64×96 中心锚点 + 头顶血条/名字组件安全盒）：
	#    左下角角色信息板块区（x 16~652, y 560~632）、左侧速度条区（x≤60）、
	#    屏幕四缘——全部锚点的安全盒不得进入
	var all_pts: Array = ally + front + back
	for p in all_pts:
		var pt: Vector2 = p
		_check(pt.y + 48.0 + 16.0 < 560.0)        # 名字标签底 < 板块顶（余量 16）
		_check(pt.y - 60.0 > 0.0)                  # 头顶血条不出屏顶
		_check(pt.x - 32.0 > 60.0)                 # 不压左侧速度条区
		_check(pt.x + 32.0 < vs.x - 16.0)          # 不出右缘
	# ⑥ 第二列空白：前列-我方水平间距远大于后列-前列间距（分界缓冲带）
	_check((front[0].x - ally[0].x) > (back[0].x - front[0].x) * 4.0)
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

## B2. 站位锚点（Battle.tscn FormationAnchors/*，编辑器 2D 视口可拖拽）断言：
##     9 个 Marker2D 存在 + 阵型几何整齐性（我方三点共线等距；敌方六点
##     排内/列向相邻间距统一=规整斜网格）+ 拖拽生效
func _test_anchors(arena) -> void:
	var names: Array = ["Ally0", "Ally1", "Ally2",
		"EnemyFront0", "EnemyFront1", "EnemyFront2",
		"EnemyBack0", "EnemyBack1", "EnemyBack2"]
	var pts: Array = []
	for i in names.size():
		var n: Node = arena.get_node_or_null("FormationAnchors/" + str(names[i]))
		_check(n is Node2D)
		var p := Vector2.ZERO
		if n is Node2D:
			p = (n as Node2D).position
		pts.append(p)
	# 我方三点：共线且等距（操作者手调后微调口径）
	var a0: Vector2 = pts[0]
	var a1: Vector2 = pts[1]
	var a2: Vector2 = pts[2]
	_check(absf(a0.distance_to(a1) - a1.distance_to(a2)) < 0.05)
	var dir0 := (a1 - a0).normalized()
	var dir1 := (a2 - a1).normalized()
	_check(absf(dir0.cross(dir1)) < 0.0001)  # 共线（单位向量叉积=0）
	# 敌方六点：相邻间距统一（排内 2 步 ×2 排 + 列向 3 步；即规整斜网格）
	var gaps: Array = [
		pts[3].distance_to(pts[4]), pts[4].distance_to(pts[5]),  # 前列内
		pts[6].distance_to(pts[7]), pts[7].distance_to(pts[8]),  # 后列内
		pts[3].distance_to(pts[6]), pts[4].distance_to(pts[7]), pts[5].distance_to(pts[8])]  # 列向
	var dmin: float = gaps[0]
	var dmax: float = gaps[0]
	for v in gaps:
		dmin = minf(dmin, float(v))
		dmax = maxf(dmax, float(v))
	_check(dmax - dmin < 0.05)
	# 拖拽生效：移动 Ally0 → setup_stances 后我方第 0 个单位跟随（按缩放换算）
	var m0: Node2D = arena.get_node("FormationAnchors/Ally0")
	var orig := m0.position
	m0.position = Vector2(300.0, 400.0)
	arena.setup_stances(PARTY, ["corrosion_beast"])
	var unit0: Node2D = arena._allies.get_children()[0]
	var vp: Vector2 = arena.get_viewport_rect().size
	var sc := vp.x / 1152.0  # 设计基准等比缩放（锚点=1152 基准坐标）
	_check(unit0.position.distance_to(Vector2(300.0, 400.0) * sc) < 0.01)  # headless 无相机=逆映射恒等
	m0.position = orig
	print("[SMOKE] B2 锚点: 9 个 Marker2D；我方三点共线等距=%.2f；敌方相邻间距统一=%.2f~%.2f" % [
		a0.distance_to(a1), dmin, dmax])

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
