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
const LS := preload("res://scripts/core/level_system.gd")

var _failed := false

func _initialize() -> void:
	# autoload（DataManager/SaveManager）在 --script 模式照常加载，deferred 后即可用
	_run.call_deferred()


func _run() -> void:
	print("=== T0.2 数据模型冒烟测试开始 ===")

	# [1] CharacterData：正常行（T2.7 A2：name 用正式名，断言防回退到空/「待定」）
	var c := DM.CharacterData.from_csv_row({
		"id": "awakened_mech_01",
		"name": "诺菈·星枢",
		"faction": "大秦帝国",
		"system": "科技",
		"hp": "120",
		"atk": "18",
		"def": "10",
		"spd": "9",
		"skill_small": "skill_mech_01_s1",
		"skill_ult": "skill_mech_01_ult",
		"portrait_id": "portrait_mech_01",
		"sprite_id": "sprite_mech_01",
		"background": "大秦帝国观测员，靠天心印记守护营地",  # T2.9 新增
	})
	print("[1] 角色正常行: ", c)
	_check(c.id == "awakened_mech_01")
	_check(c.name != "" and c.name != "待定")  # T2.7 A2 防回退
	_check(c.faction == "大秦帝国" and c.system == "科技")
	_check(c.hp == 120 and c.atk == 18 and c.def == 10 and c.spd == 9)
	_check(c.skill_small == "skill_mech_01_s1" and c.skill_ult == "skill_mech_01_ult")
	_check(c.portrait_id == "portrait_mech_01" and c.sprite_id == "sprite_mech_01")
	_check(c.system_name() == "科技")
	_check(c.faction_name() == "大秦帝国")
	_check(c.background != "")  # T2.9 background 非空断言

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
	_check(c2.background == "")  # T2.9 background 缺列→""

	# [3] SkillData（T2.9：大招充能制，无 energy_cost；T2.9 新增三字段 target_side/scope/effect）
	# 逐值对照角色系统.md §5 诺菈 s1（ally+single+heal，power=2.0）
	var s := DM.SkillData.from_csv_row({
		"id": "skill_mech_01_s1", "name": "应急修复协议", "type": "small",
		"power": "2.0", "cutscene_id": "",
		"target_side": "ally", "target_scope": "single", "effect": "heal",
	})
	print("[3] 技能诺菈s1: ", s)
	_check(s.id == "skill_mech_01_s1" and s.name == "应急修复协议" and s.type == "small")
	_check(s.power == 2.0 and s.cutscene_id == "")
	_check(s.target_side == "ally" and s.target_scope == "single" and s.effect == "heal")
	_check(not ("energy_cost" in s))

	# [3b] SkillData：缺省值容错——三字段空/缺列时自动回退规则缺省（enemy/single/damage）
	var s_default := DM.SkillData.from_csv_row({
		"id": "skill_default", "name": "默认技能", "type": "small",
		"power": "1.0",
		# target_side/scope/effect 全部缺列 → 自动回退
	})
	print("[3b] 技能缺省容错: ", s_default)
	_check(s_default.target_side == "enemy")   # 规则缺省
	_check(s_default.target_scope == "single")  # 规则缺省
	_check(s_default.effect == "damage")         # 规则缺省

	# [3c] 技能三字段逐值对照（§5 其他角色）
	# 艾蕾雅 ult：ally+all+amp，power=30
	var s_arc_ult := DM.SkillData.from_csv_row({
		"id": "skill_arcane_01_ult", "name": "银月辉映", "type": "ult",
		"power": "30", "cutscene_id": "cut_arcane_ult",
		"target_side": "ally", "target_scope": "all", "effect": "amp",
	})
	print("[3c] 艾蕾雅ult: ", s_arc_ult)
	_check(s_arc_ult.target_side == "ally" and s_arc_ult.target_scope == "all" and s_arc_ult.effect == "amp")
	_check(s_arc_ult.power == 30.0)

	# 洛清弦 s1：enemy+column+damage，power=1.2
	var s_xian_s1 := DM.SkillData.from_csv_row({
		"id": "skill_xian_01_s1", "name": "流云剑诀", "type": "small",
		"power": "1.2", "cutscene_id": "",
		"target_side": "enemy", "target_scope": "column", "effect": "damage",
	})
	print("[3c] 洛清弦s1: ", s_xian_s1)
	_check(s_xian_s1.target_side == "enemy" and s_xian_s1.target_scope == "column" and s_xian_s1.effect == "damage")

	# 敌人小技能：显式填 enemy/single/damage（制作人04 预裁定）
	var s_enemy := DM.SkillData.from_csv_row({
		"id": "enemy_beast_small", "name": "蚀骨撕咬", "type": "small",
		"power": "1.0", "cutscene_id": "",
		"target_side": "enemy", "target_scope": "single", "effect": "damage",
	})
	print("[3c] 敌人小技能: ", s_enemy)
	_check(s_enemy.target_side == "enemy" and s_enemy.target_scope == "single" and s_enemy.effect == "damage")

	# [4] EnemyData（T2.8：扩 skill_small/skill_ult 双技能字段，关联 skills.csv enemy_ 前缀行）
	var e := DM.EnemyData.from_csv_row({
		"id": "corrosion_beast", "name": "蚀兽", "hp": "150", "atk": "10",
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

	# ===== T2.11 等级/经验/升级 =====
	# [8] CharacterData level/exp 默认回读（1/0）+ 体系英文代号
	var c_prog := DM.CharacterData.from_csv_row({"id": "awakened_mech_01", "name": "诺菈·星枢", "system": "科技"})
	print("[8] 角色进度默认: ", c_prog.level, "/", c_prog.exp, " code=", c_prog.system_code())
	_check(c_prog.level == 1 and c_prog.exp == 0)
	_check(c_prog.system_code() == "mech")

	# [9] get_combat_stat：基础 + (level-1)×成长（mech hp_growth=5）
	var cc := DM.CharacterData.from_csv_row({"id": "awakened_mech_01", "name": "诺菈·星枢", "system": "科技", "hp": "100"})
	cc.growth = {"hp": 5, "atk": 1, "def": 2, "spd": 0}
	cc.level = 1
	_check(cc.get_combat_stat("hp", cc.hp) == 100)   # Lv1 不吃成长
	cc.level = 5
	_check(cc.get_combat_stat("hp", cc.hp) == 120)   # 100 + (5-1)*5
	print("[9] get_combat_stat Lv1=%d Lv5=%d" % [cc.get_combat_stat("hp", cc.hp) - 20, cc.get_combat_stat("hp", cc.hp)])

	# [10] add_exp 升级边界（满前/恰满/溢出结转连续/封顶归零）
	var lc := DM.CharacterData.from_csv_row({"id": "awakened_mech_01", "name": "诺菈·星枢", "system": "科技"})
	LS.add_exp(lc, 99)
	_check(lc.level == 1 and lc.exp == 99)          # 满前
	LS.add_exp(lc, 1)
	_check(lc.level == 2 and lc.exp == 0)           # 恰满升级
	LS.add_exp(lc, 599)                              # Lv2→3 需200、Lv3→4 需300，合计500，剩99
	_check(lc.level == 4 and lc.exp == 99)          # 溢出结转 + 多级连升
	LS.add_exp(lc, 100000)
	_check(lc.level == LS.LEVEL_CAP and lc.exp == 0)  # 封顶 Lv.10、exp 归零
	print("[10] add_exp 边界：最终 Lv.%d / exp %d（封顶 %d）" % [lc.level, lc.exp, int(LS.LEVEL_CAP)])

	# [11] DataManager 成长注入 + 进度序列化循环 + SaveManager version bump
	var dm_node: Node = root.get_node_or_null("DataManager")
	var sm_node: Node = root.get_node_or_null("SaveManager")
	_check(dm_node != null)
	_check(sm_node != null)
	if dm_node != null and sm_node != null:
		var ch_mech = dm_node.get_character("awakened_mech_01")
		_check(int(ch_mech.growth.get("hp", 0)) == 5)   # DataManager 已注入 mech hp_growth=5
		# 进度序列化→回填循环
		dm_node.apply_character_progress({})            # 复位
		dm_node.add_exp("awakened_mech_01", 199)        # Lv1→Lv2（耗100），剩99
		_check(ch_mech.level == 2 and ch_mech.exp == 99)
		var saved: Dictionary = dm_node.get_character_progress()
		dm_node.add_exp("awakened_mech_01", 1)          # 变成 100
		_check(ch_mech.level == 2 and ch_mech.exp == 100)
		dm_node.apply_character_progress(saved)         # 回填
		_check(ch_mech.level == 2 and ch_mech.exp == 99)
		# version=1 兜底：空 progress 复位 1/0 不崩溃
		dm_node.apply_character_progress({})
		_check(ch_mech.level == 1 and ch_mech.exp == 0)

		# 真实 SaveManager 存/读循环（version=2）
		dm_node.add_exp("awakened_mech_01", 199)        # Lv2 exp99
		var save_ok: bool = sm_node.save_game("smoke_t2_11", false)
		_check(save_ok)
		dm_node.add_exp("awakened_mech_01", 100000)     # 封顶 Lv10
		_check(ch_mech.level == LS.LEVEL_CAP)
		var loaded: Dictionary = sm_node.load_game("smoke_t2_11")
		_check(not loaded.is_empty())
		_check(int(loaded.get("version", -1)) == 2)     # SAVE_VERSION=2
		_check(ch_mech.level == 2 and ch_mech.exp == 99)  # 读回 hold 值
		var cp: Variant = loaded.get("character_progress", {})
		if cp is Dictionary:
			var entry: Variant = cp.get("awakened_mech_01", [])
			_check(entry is Array and int(entry[0]) == 2 and int(entry[1]) == 99)
		else:
			_check(false)

		# version=1 兼容读档：手工造 v1 档（无 character_progress）→ 不崩溃且兜底 1/0
		var vf := FileAccess.open("user://save_smoke_v1.json", FileAccess.WRITE)
		if vf != null:
			vf.store_string(JSON.stringify({
				"version": 1, "saved_at": "smoke", "game_state": {"star_sand": 0, "starlink_tokens": 0, "flags": {}},
				"party": {"members": [], "companion_id": ""}, "shrines": {"lit_shrines": []},
				"map": {"unlocked_regions": []}, "gacha": {"pity_counter": 0}, "protagonist": {"name": "异乡人"},
			}))
			vf.close()
			var v1_loaded: Dictionary = sm_node.load_game("smoke_v1")
			_check(not v1_loaded.is_empty())
			_check(ch_mech.level == 1 and ch_mech.exp == 0)  # 兜底 1/0

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
