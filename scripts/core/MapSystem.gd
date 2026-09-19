## =============================================================
## 《汇界星痕》T2.3 MapSystem（地图系统，Autoload 单例）
## -------------------------------------------------------------
## 架构 §2.3 地图系统 + §4.4 接口：
##   unlock_region / is_region_unlocked / get_region_by_shrine
## 数据归属：区块/神像/传送点注册表（MVP 假神像验证，正式神像 T2.4 接入）、
##   场景箱庭线框缓存（TileMapLayer used cells 边界实时生成）。
## UI 挂载：常驻 HUD（T2.3 步骤4）与 MapUI（箱庭图/世界大地图）作为本单例子节点，
##   跨场景持久；面板开关统一经 EventBus.ui_open/ui_closed + PauseManager。
## 解锁规则：点亮区块内任意神像（T2.4）/ 剧情事件直调 unlock_region；
##   起始区块（营地）默认解锁不发信号。
## 存档序列化项：unlocked_regions（T2.4 接入，坏档回退到 ["region_camp"]）。
## =============================================================
extends Node

## 区块注册表：scene 为空 = 尚未开放的剧情区块（仅大地图剪影展示）
const REGIONS := {
	"region_camp": {
		"name": "汇界营地", "scene": "res://scenes/map/CampMap.tscn",
		"color": Color(0.0, 0.75, 1.0), "label_pos": Vector2(300, 300),
		"world_poly": [
			Vector2(120, 180), Vector2(300, 120), Vector2(470, 170), Vector2(520, 300),
			Vector2(420, 440), Vector2(200, 450), Vector2(90, 330),
		],
	},
	"region_test": {
		"name": "试炼遗迹", "scene": "res://scenes/map/TestMap.tscn",
		"color": Color(0.58, 0.44, 0.86), "label_pos": Vector2(790, 255),
		"world_poly": [
			Vector2(560, 120), Vector2(820, 90), Vector2(1010, 160), Vector2(1040, 320),
			Vector2(880, 440), Vector2(640, 420), Vector2(540, 280),
		],
	},
	"region_frontier": {
		"name": "远境", "scene": "",
		"color": Color(0.24, 0.71, 0.44), "label_pos": Vector2(965, 520),
		"world_poly": [
			Vector2(880, 470), Vector2(1060, 430), Vector2(1120, 520), Vector2(1000, 610),
			Vector2(840, 580), Vector2(800, 510),
		],
	},
}

## 神像注册表（MVP 假神像：lit 状态暂以所属区块解锁态代替，T2.4 神像点亮接管）；
## cell = 箱庭图标点位（所在场景 TileMapLayer 坐标）；world_pos = 大地图设计坐标
const SHRINES := {
	"shrine_camp": {
		"name": "营地星痕神像", "region": "region_camp", "scene": "res://scenes/map/CampMap.tscn",
		"cell": Vector2i(14, 7), "world_pos": Vector2(250, 262),
	},
	"shrine_test": {
		"name": "遗迹星痕神像", "region": "region_test", "scene": "res://scenes/map/TestMap.tscn",
		"cell": Vector2i(12, 3), "world_pos": Vector2(790, 200),
	},
}

## 泛用传送点（非神像，任务跳转预留）
const PORTALS := {
	"test_map": {"scene": "res://scenes/map/TestMap.tscn", "spawn": null},
	"camp_main": {"scene": "res://scenes/map/CampMap.tscn", "spawn": null},
}

## 已解锁区块（存档序列化项，T2.4）
var unlocked_regions: Array[String] = []

var _outline_cache: Dictionary = {}  # scene_path -> Array[PackedVector2Array]（地图局部坐标）
var _blocked_cache: Dictionary = {}  # scene_path -> Array[Vector2i]（阻挡格）
var _hud: CanvasLayer = null
var _map_ui: CanvasLayer = null


func _ready() -> void:
	unlocked_regions = ["region_camp"]  # 起始区块默认解锁，不发信号
	_ensure_ui()
	print("[MapSystem] ready: regions=%d shrines=%d unlocked=%s" % [REGIONS.size(), SHRINES.size(), str(unlocked_regions)])


# ---------------------------------------------------------------
# 对外接口（架构 §4.4 地图系统）
# ---------------------------------------------------------------

## 解锁区块（神像点亮 / 剧情事件触发）；已解锁幂等不发信号
func unlock_region(region_id: String) -> void:
	if region_id in unlocked_regions:
		return
	unlocked_regions.append(region_id)
	print("[MapSystem] region_unlocked -> %s" % region_id)
	get_node("/root/EventBus").map_region_unlocked.emit(region_id)


func is_region_unlocked(region_id: String) -> bool:
	return region_id in unlocked_regions


func get_region_by_shrine(shrine_id: String) -> String:
	if SHRINES.has(shrine_id):
		return SHRINES[shrine_id].region
	push_warning("[MapSystem] get_region_by_shrine 未知神像：%s" % shrine_id)
	return ""


## 已解锁区块副本（T2.4 存档读取）
func get_unlocked_regions() -> Array[String]:
	return unlocked_regions.duplicate()


## 当前所在区块（按当前场景路径反查；场景不属于任何区块返回 ""）
func get_current_region_id() -> String:
	var cs := get_tree().current_scene
	if cs == null:
		return ""
	var p: String = cs.scene_file_path
	for id: String in REGIONS:
		if REGIONS[id].scene == p:
			return id
	return ""


func get_region_info(region_id: String) -> Dictionary:
	return REGIONS.get(region_id, {})


func get_shrine_info(shrine_id: String) -> Dictionary:
	return SHRINES.get(shrine_id, {})


## Transition 反查传送目标：神像 id 或泛用传送点 id → {scene, spawn}
func get_portal_target(target_id: String) -> Dictionary:
	if SHRINES.has(target_id):
		return {"scene": SHRINES[target_id].scene, "spawn": null}
	if PORTALS.has(target_id):
		return PORTALS[target_id].duplicate()
	return {}


# ---------------------------------------------------------------
# 场景箱庭数据（箱庭图 / 小地图共用，按场景缓存）
# ---------------------------------------------------------------

func get_ground_layer() -> TileMapLayer:
	var cs := get_tree().current_scene
	if cs == null:
		return null
	var found := cs.find_children("*", "TileMapLayer", true, false)
	return found[0] if found.size() > 0 else null


## 当前场景可行走区域轮廓（TileMapLayer used cells 边界，地图局部坐标闭环数组）
func get_outline_loops() -> Array:
	var tml := get_ground_layer()
	if tml == null:
		return []
	var cs := get_tree().current_scene
	if cs == null:
		return []
	var key: String = cs.scene_file_path
	if not _outline_cache.has(key):
		_outline_cache[key] = extract_outline_loops(tml)
		print("[MapSystem] 箱庭线框已生成：%s loops=%d" % [key, _outline_cache[key].size()])
	return _outline_cache[key]


## 当前场景阻挡格（TileData 带碰撞多边形的格子，地图格坐标；
## 墙壁/障碍 = 人物不可通行处，箱庭图行动边界可视化数据源）
func get_blocked_cells() -> Array[Vector2i]:
	var tml := get_ground_layer()
	if tml == null or get_tree().current_scene == null:
		return []
	var key: String = get_tree().current_scene.scene_file_path
	if not _blocked_cache.has(key):
		var cells: Array[Vector2i] = []
		for c: Vector2i in tml.get_used_cells():
			var td: TileData = tml.get_cell_tile_data(c)
			if td != null and td.get_collision_polygons_count(0) > 0:
				cells.append(c)
		_blocked_cache[key] = cells
		print("[MapSystem] 阻挡格已生成：%s count=%d" % [key, cells.size()])
	return _blocked_cache[key]


## 当前场景的神像点位列表：[{id, name, lit, pos}]（pos 为全局坐标）
func get_current_scene_shrines() -> Array:
	var out: Array = []
	var cs := get_tree().current_scene
	if cs == null:
		return out
	var path: String = cs.scene_file_path
	var tml := get_ground_layer()
	for id: String in SHRINES:
		var s: Dictionary = SHRINES[id]
		if s.scene != path:
			continue
		var pos: Vector2 = Vector2.ZERO
		if tml != null and s.has("cell"):
			pos = tml.to_global(tml.map_to_local(s.cell))
		out.append({"id": id, "name": s.name, "lit": is_region_unlocked(s.region), "pos": pos})
	return out


## 场景出口标注（MVP 空，箱庭图预留画法）
func get_current_scene_exits() -> Array:
	return []


# ---------------------------------------------------------------
# UI 挂载（HUD / MapUI 为本单例子节点 → 常驻跨场景）
# ---------------------------------------------------------------

func _ensure_ui() -> void:
	if ResourceLoader.exists("res://scenes/ui/MapUI.tscn"):
		_map_ui = load("res://scenes/ui/MapUI.tscn").instantiate()
		_map_ui.name = "MapUI"
		add_child(_map_ui)
	if ResourceLoader.exists("res://scenes/ui/HUD.tscn"):
		_hud = load("res://scenes/ui/HUD.tscn").instantiate()
		_hud.name = "HUD"
		add_child(_hud)


# ---------------------------------------------------------------
# 几何工具（静态，供视图层复用）
# ---------------------------------------------------------------

## 把 used cells 边界转为闭环折线数组（等距菱形格，tile 64×32）。
## 四边与跨格邻居：W→N 边↔(0,-1)、N→E↔(1,0)、E→S↔(0,1)、S→W↔(-1,0)；
## 邻格已用则该边不是边界；有向边首尾链接成环。
static func extract_outline_loops(tml: TileMapLayer) -> Array:
	var used := tml.get_used_cells()
	if used.is_empty():
		return []
	var cell_set: Dictionary = {}
	for c in used:
		cell_set[c] = true
	var corners := [Vector2(-32, 0), Vector2(0, -16), Vector2(32, 0), Vector2(0, 16)]
	var edge_neighbor := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var next_map: Dictionary = {}
	for c: Vector2i in used:
		var center: Vector2 = tml.map_to_local(c)
		for i in 4:
			if cell_set.has(c + edge_neighbor[i]):
				continue
			next_map[center + corners[i]] = center + corners[(i + 1) % 4]
	var loops: Array = []
	var visited: Dictionary = {}
	for start: Vector2 in next_map:
		if visited.has(start):
			continue
		var loop := PackedVector2Array()
		var cur: Vector2 = start
		while next_map.has(cur) and not visited.has(cur):
			visited[cur] = true
			loop.append(cur)
			cur = next_map[cur]
		if loop.size() >= 3:
			loops.append(loop)
	return loops


## 求包围盒（点集）
static func bounds_of(points: Array) -> Rect2:
	var r := Rect2()
	var first := true
	for loop in points:
		for p: Vector2 in loop:
			if first:
				r = Rect2(p, Vector2.ZERO)
				first = false
			else:
				r = r.expand(p)
	return r


## 等比缩放平移：src 包围盒适配进 dst（居中）
static func fit_transform(src: Rect2, dst: Rect2) -> Transform2D:
	if src.size.x <= 0.0 or src.size.y <= 0.0:
		return Transform2D.IDENTITY
	var s: float = minf(dst.size.x / src.size.x, dst.size.y / src.size.y)
	var origin: Vector2 = dst.get_center() - src.get_center() * s
	return Transform2D(Vector2(s, 0), Vector2(0, s), origin)
