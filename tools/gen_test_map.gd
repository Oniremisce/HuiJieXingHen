## =============================================================
## 《汇界星痕》T1.1 生成工具：占位菱形纹理 + 等距 TileSet + TestMap 场景
## -------------------------------------------------------------
## 用法（headless，与编辑器同运行时）：
##   1) 生成占位 PNG：godot --headless --path . --script res://tools/gen_test_map.gd -- gen
##   2) 导入资源：    godot --headless --path . --import
##   3) 构建 tileset 与场景：
##                    godot --headless --path . --script res://tools/gen_test_map.gd -- build
## 产出：
##   assets/maps/tilesets/{ground,obstacle}.png   占位菱形色块（后期 AI 资源替换）
##   assets/maps/tilesets/test_tileset.tres       等距 TileSet（obstacle 带 PhysicsLayer0 碰撞）
##   scenes/map/TestMap.tscn                      24×24 地图（围墙 + 约 10% 内部障碍，seed 固定可复现）
## =============================================================
extends SceneTree

const TILE_W := 64
const TILE_H := 32
const MAP_SIZE := 24
const OBSTACLE_RATIO := 0.10
const SEED := 42
const DIR := "res://assets/maps/tilesets"
const SRC_GROUND := 0
const SRC_OBSTACLE := 1


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("[gen_test_map] 缺少阶段参数：-- gen 或 -- build")
		quit(1)
		return
	match args[0]:
		"gen":
			_gen_pngs()
			quit(0)
		"build":
			_build()
			quit(0)
		_:
			push_error("[gen_test_map] 未知阶段参数：%s（可选 gen / build）" % args[0])
			quit(1)


## 阶段 1：生成两张 64×32 菱形色块 PNG（透明底，菱形精确铺满 tile 网格，内缩描边便于肉眼检查接缝）
func _gen_pngs() -> void:
	_write_diamond(DIR + "/ground.png", Color(0.55, 0.63, 0.55), Color(0.44, 0.52, 0.44))
	_write_diamond(DIR + "/obstacle.png", Color(0.25, 0.28, 0.36), Color(0.17, 0.19, 0.25))
	print("[gen_test_map] PNG 已生成：%s/ground.png、%s/obstacle.png" % [DIR, DIR])


func _write_diamond(path: String, fill: Color, border: Color) -> void:
	var img := Image.create(TILE_W, TILE_H, false, Image.FORMAT_RGBA8)
	for y in TILE_H:
		for x in TILE_W:
			var fx := absf(x + 0.5 - TILE_W * 0.5) / (TILE_W * 0.5)
			var fy := absf(y + 0.5 - TILE_H * 0.5) / (TILE_H * 0.5)
			var d := fx + fy  # 菱形方程：d <= 1 在菱形内
			if d <= 1.0:
				img.set_pixel(x, y, border if d > 0.86 else fill)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	var err := img.save_png(path)
	if err != OK:
		push_error("[gen_test_map] save_png 失败 %s：%s" % [path, error_string(err)])
	else:
		print("[gen_test_map] 已写入 ", path)


## 阶段 2：构建 TileSet（等距 + 物理层）与 TestMap 场景
func _build() -> void:
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	# 布局选 DIAMOND_RIGHT(4)：基向量 ex=(32,-16) ey=(32,16)，地图轮廓为经典菱形；
	# 默认 STACKED(0) 是砖行堆叠（轮廓为横向条带），不符合常规等距地图观感
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_RIGHT
	ts.tile_size = Vector2i(TILE_W, TILE_H)
	ts.add_physics_layer()  # PhysicsLayer0，默认 collision_layer=1

	# ground（浅色，可通行）
	var ground_src := TileSetAtlasSource.new()
	ground_src.texture = load(DIR + "/ground.png")
	ground_src.texture_region_size = Vector2i(TILE_W, TILE_H)
	ground_src.create_tile(Vector2i.ZERO)
	ts.add_source(ground_src, SRC_GROUND)

	# obstacle（深色，带菱形碰撞多边形，坐标相对 tile 中心）
	# 注意：必须先 add_source 加入 TileSet，get_tile_data 返回的 TileData 才有物理层数据
	var obs_src := TileSetAtlasSource.new()
	obs_src.texture = load(DIR + "/obstacle.png")
	obs_src.texture_region_size = Vector2i(TILE_W, TILE_H)
	obs_src.create_tile(Vector2i.ZERO)
	ts.add_source(obs_src, SRC_OBSTACLE)
	var td := obs_src.get_tile_data(Vector2i.ZERO, 0)
	td.add_collision_polygon(0)
	td.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(0, -16), Vector2(32, 0), Vector2(0, 16), Vector2(-32, 0),
	]))

	var ts_err := ResourceSaver.save(ts, DIR + "/test_tileset.tres")
	if ts_err != OK:
		push_error("[gen_test_map] tileset 保存失败：%s" % error_string(ts_err))
		return
	print("[gen_test_map] tileset 已保存：%s/test_tileset.tres" % DIR)

	# 24×24 地面层：边缘一圈围墙，内部约 10% 障碍（固定 seed 可复现）
	# tile_set 用存盘后的 .tres 重新加载：pack 时才能序列化为 ExtResource 引用，
	# 否则 ResourceSaver 会把内存中的 TileSet 内联成 sub_resource（双份真相）。
	var root := Node2D.new()
	root.name = "TestMap"
	var layer := TileMapLayer.new()
	layer.name = "Ground"
	layer.tile_set = load(DIR + "/test_tileset.tres")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var obstacle_count := 0
	for x in MAP_SIZE:
		for y in MAP_SIZE:
			var is_border := x == 0 or y == 0 or x == MAP_SIZE - 1 or y == MAP_SIZE - 1
			var is_obstacle := is_border or rng.randf() < OBSTACLE_RATIO
			if is_obstacle:
				obstacle_count += 1
			layer.set_cell(Vector2i(x, y), SRC_OBSTACLE if is_obstacle else SRC_GROUND, Vector2i.ZERO)
	root.add_child(layer)
	layer.owner = root  # pack() 只序列化 owner 为根节点的子节点，漏设会把 Ground 静默丢掉

	var packed := PackedScene.new()
	var scene_err := packed.pack(root)
	if scene_err != OK:
		push_error("[gen_test_map] 场景打包失败：%s" % error_string(scene_err))
		return
	ResourceSaver.save(packed, "res://scenes/map/TestMap.tscn")
	print("[gen_test_map] 场景已保存：res://scenes/map/TestMap.tscn（%d×%d，obstacle=%d，占 %.1f%%）" % [
		MAP_SIZE, MAP_SIZE, obstacle_count, 100.0 * obstacle_count / (MAP_SIZE * MAP_SIZE),
	])
