extends Node
## =============================================================
## T3.6 演出演示验证场景（MCP 截图/跳过验证用；不修改 main_scene，
## game_start 带 scene_path=res://scenes/BattleCutsceneDemo.tscn 运行）
## 编组：三觉醒者（共振注入["科技","科技","科技"]）vs 蚀兽 hp=300；
## 三人 charge 覆写 100 → R1 三大招（全屏 ult CG×3）→ 计数满合击（combo CG）；
## 空格跳过当前演出；演出结束战斗继续（跑条/充能冻结后恢复）。
## =============================================================

const BM := preload("res://scripts/battle/battle_manager.gd")
const CS := preload("res://scenes/BattleCutscene.tscn")

func _ready() -> void:
	_run()

func _run() -> void:
	var dm := get_node("/root/DataManager")
	var bm = BM.new(dm, ["awakened_mech_01", "awakened_arcane_01", "awakened_xian_01"], ["corrosion_beast"], ["科技", "科技", "科技"])
	bm.force_crit = 0
	var cs: Node = CS.instantiate()
	add_child(cs)
	bm.cutscene = cs
	bm.units[3].max_hp = 300
	bm.units[3].hp = 300
	for u in bm.units:
		if u.is_ally:
			u.charge = 100
	var r: String = await bm.run_to_end(6)
	print("[DEMO] 战斗结束 result=", r, " rounds=", bm.round_num)
