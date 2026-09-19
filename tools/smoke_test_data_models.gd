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

	# [3] SkillData（T2.8：大招充能制，无 energy_cost 字段；power=倍率）
	var s := DM.SkillData.from_csv_row({
		"id": "skill_mech_s1", "name": "脉冲斩", "type": "small",
		"power": "1.2", "cutscene_id": "",
	})
	print("[3] 技能: ", s)
	_check(s.id == "skill_mech_s1" and s.name == "脉冲斩" and s.type == "small")
	_check(s.power == 1.2 and s.cutscene_id == "")
	_check(not ("energy_cost" in s))

	# [4] EnemyData（T2.8：扩 skill_small/skill_ult 双技能字段，关联 skills.csv enemy_ 前缀行）
	var e := DM.EnemyData.from_csv_row({
		"id": "corrosion_beast", "name": "灾蚀兽", "hp": "150", "atk": "10",
		"def": "6", "spd": "8", "ai_pattern": "simple", "drop_sand": "30",
		"skill_small": "enemy_beast_small", "skill_ult": "enemy_beast_ult",
	})
	print("[4] 敌人: ", e)
	_check(e.hp == 150 and e.atk == 10 and e.def == 6 and e.spd == 8)
	_check(e.ai_pattern == "simple" and e.drop_sand == 30)
	_check(e.skill_small == "enemy_beast_small" and e.skill_ult == "enemy_beast_ult")

	# [4b] EnemyData：缺键容错 → 双技能缺省空串
	var e2 := DM.EnemyData.from_csv_row({"id": "e_x", "hp": "abc"})
	print("[4b] 敌人容错行: ", e2)
	_check(e2.hp == 0 and e2.skill_small == "" and e2.skill_ult == "")

	# [5] StelliumData（T2.8：套装×槽位制，slot 1-3 固定 / 4-6 随机池，无稀有度）
	var st_fixed := DM.StelliumData.from_csv_row({
		"id": "set1_slot1", "name": "攻击星髓", "set_id": "set1", "set_name": "套装1",
		"slot": "1", "main_stat": "atk", "main_base": "30", "main_max": "75",
		"set_2_bonus": "crit:15", "set_3_bonus": "cond_dmg:hp>70%,50",
	})
	print("[5] 星髓固定主词条行: ", st_fixed)
	_check(st_fixed.set_id == "set1" and st_fixed.set_name == "套装1" and st_fixed.slot == 1)
	_check(st_fixed.main_stat == "atk" and st_fixed.main_base == "30" and st_fixed.main_max == "75")
	_check(st_fixed.set_2_bonus == "crit:15" and st_fixed.set_3_bonus == "cond_dmg:hp>70%,50")

	# [5b] slot 1-6 逐槽断言：1-3 固定词条 / 4-6 池串一一对应
	var slot_specs := [
		{"slot": "2", "stat": "def", "base": "25", "max": "60"},
		{"slot": "3", "stat": "hp", "base": "180", "max": "450"},
		{"slot": "4", "stat": "pct_atk|pct_def|pct_hp", "base": "6|6|6", "max": "15|15|15"},
		{"slot": "5", "stat": "crit|crit_dmg|pct_atk", "base": "5|8|6", "max": "12|20|15"},
		{"slot": "6", "stat": "charge|spd", "base": "6|8", "max": "15|20"},
	]
	for spec in slot_specs:
		var st := DM.StelliumData.from_csv_row({
			"id": "set2_slot" + spec["slot"], "name": "星髓" + spec["slot"],
			"set_id": "set2", "set_name": "套装2", "slot": spec["slot"],
			"main_stat": spec["stat"], "main_base": spec["base"], "main_max": spec["max"],
			"set_2_bonus": "crit_dmg:15", "set_3_bonus": "cond_dmg:hp<50%,50",
		})
		print("[5b] 星髓 slot", spec["slot"], ": ", st)
		_check(st.slot == int(spec["slot"]) and st.main_stat == spec["stat"])
		_check(st.main_base == spec["base"] and st.main_max == spec["max"])

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
