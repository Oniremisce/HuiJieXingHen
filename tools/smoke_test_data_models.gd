## =============================================================
## T0.2 冒烟测试（推进表 §4/T0.2 步骤 4）
## 手工构造 CSV 行字典 → 数据模型实例 → 打印全部字段确认正确；
## 同时覆盖 6 个类的容错默认值（空值/缺键/非法值）与便捷方法。
## 运行（headless，与编辑器同运行时）：
##   godot --headless --path . --script res://tools/smoke_test_data_models.gd
## =============================================================
extends SceneTree

## preload 引用数据模型（不依赖编辑器全局类缓存扫描时机）
const DM := preload("res://scripts/core/data_models.gd")

var _failed := false

func _init() -> void:
	print("=== T0.2 数据模型冒烟测试开始 ===")

	# [1] CharacterData：正常行
	var c := DM.CharacterData.from_csv_row({
		"id": "awakened_mech_01",
		"name": "待定",
		"faction": "机律联邦",
		"system": "机律",
		"hp": "120",
		"atk": "18",
		"def": "10",
		"spd": "9",
		"skill_small": "skill_mech_s1",
		"skill_ult": "skill_mech_ult",
		"portrait_id": "portrait_mech_01",
		"sprite_id": "sprite_mech_01",
	})
	print("[1] 角色正常行: ", c)
	_check(c.id == "awakened_mech_01")
	_check(c.name == "待定")
	_check(c.faction == "机律联邦" and c.system == "机律")
	_check(c.hp == 120 and c.atk == 18 and c.def == 10 and c.spd == 9)
	_check(c.skill_small == "skill_mech_s1" and c.skill_ult == "skill_mech_ult")
	_check(c.portrait_id == "portrait_mech_01" and c.sprite_id == "sprite_mech_01")
	_check(c.system_name() == "机律")
	_check(c.faction_name() == "机律联邦")

	# [2] CharacterData：空值/缺键/非法值 → 默认（数值 0、字符串 ""），警告但不中断
	var c2 := DM.CharacterData.from_csv_row({
		"id": "awakened_x_02",
		"name": "",       # 空字符串 → ""
		"hp": "abc",      # 非法整数 → 0 + 警告
		"atk": "",        # 空整数 → 0
		"spd": "7.9",     # 浮点 → 截断 7 + 警告
		# def / faction / system / skill_small / skill_ult / portrait_id / sprite_id 缺键 → 默认
	})
	print("[2] 角色容错行: ", c2)
	_check(c2.name == "" and c2.faction == "" and c2.system == "")
	_check(c2.hp == 0 and c2.atk == 0 and c2.def == 0)
	_check(c2.spd == 7)
	_check(c2.skill_small == "" and c2.skill_ult == "" and c2.portrait_id == "" and c2.sprite_id == "")

	# [3] SkillData
	var s := DM.SkillData.from_csv_row({
		"id": "skill_mech_s1", "name": "脉冲斩", "type": "small",
		"power": "35", "energy_cost": "0", "cutscene_id": "cut_mech_s1",
	})
	print("[3] 技能: ", s)
	_check(s.id == "skill_mech_s1" and s.name == "脉冲斩" and s.type == "small")
	_check(s.power == 35 and s.energy_cost == 0 and s.cutscene_id == "cut_mech_s1")

	# [4] EnemyData
	var e := DM.EnemyData.from_csv_row({
		"id": "corrosion_beast", "name": "灾蚀兽", "hp": "300", "atk": "22",
		"def": "8", "spd": "6", "ai_pattern": "basic", "drop_sand": "50",
	})
	print("[4] 敌人: ", e)
	_check(e.hp == 300 and e.atk == 22 and e.def == 8 and e.spd == 6)
	_check(e.ai_pattern == "basic" and e.drop_sand == 50)

	# [5] StelliumData
	var st := DM.StelliumData.from_csv_row({
		"id": "stellium_01", "name": "占位套装·机律", "main_stat": "atk",
		"sub_stats": "spd+2;hp+20", "set_id": "set_mech_01",
	})
	print("[5] 星髓: ", st)
	_check(st.main_stat == "atk" and st.sub_stats == "spd+2;hp+20" and st.set_id == "set_mech_01")

	# [6] SummonEntryData（gold=金卡布尔，weight=浮点权重）
	var se := DM.SummonEntryData.from_csv_row({
		"entry_id": "entry_starlink_01", "name": "星缘令", "kind": "starlink_token",
		"gold": "true", "weight": "0.5",
	})
	print("[6] 抽卡池: ", se)
	_check(se.gold == true and absf(se.weight - 0.5) < 0.0001)

	# [7] QuestData
	var q := DM.QuestData.from_csv_row({
		"quest_id": "heartbond_01", "step": "1", "step_name": "开启对话",
		"requirement": "meet_awakened_mech_01", "target": "npc_mech_01",
		"reward": "sand_100", "next_step": "2",
	})
	print("[7] 任务: ", q)
	_check(q.step == 1 and q.step_name == "开启对话")
	_check(q.requirement == "meet_awakened_mech_01" and q.target == "npc_mech_01")
	_check(q.reward == "sand_100" and q.next_step == "2")

	if _failed:
		push_error("[SmokeTest] 存在失败断言！")
		print("=== T0.2 冒烟测试结束：存在失败项 ===")
		quit(1)
	else:
		print("=== T0.2 冒烟测试结束：全部通过 ===")
		quit(0)

func _check(cond: bool) -> void:
	if not cond:
		_failed = true
		push_error("[SmokeTest] 断言失败")
