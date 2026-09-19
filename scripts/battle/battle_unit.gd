extends RefCounted
## =============================================================
## T3.3 BattleUnit（口径：docs/系统规则/战斗系统.md §3 充能制 + 推进表 T3.3 卡）
## -------------------------------------------------------------
## 由 T3.2 内部占位类抽出为正式单位结构（BattleManager 消费，勿改名）。
## HP/充能条 + 技能数据 + 充能三途径积累，全部在此结算；伤害公式不在此
## （BattleCommand 管线，T3.4 替换正式 DamageCalc）。
## 构造方式：BU.new() 后 .setup(dm, uid, is_ally) 两步——刻意不用全局
## class_name（headless --script 模式不重扫全局类缓存，常驻冒烟必须在
## 无缓存环境可直接跑，见交接班表 T3.3 行）。
##
## 对外接口（T3.3 BattleCommand / T3.4 伤害结算 / T3.6 演出消费，勿改名）：
##   const BU := preload("res://scripts/battle/battle_unit.gd")
##   var u = BU.new(); u.setup(dm, uid, is_ally)   # dm=DataManager 实例
##   字段：id/name/is_ally/hp/max_hp/atk/def/spd/charge/charge_max(默认100)/
##         charge_free(默认false，机制预留 §3，三觉醒者恒 false)/
##         skill_small/skill_ult(DM.SkillData，无 energy_cost 勿读)/alive
##   充能三途径（§3 数值）：charge_on_turn_start() 激活+10 /
##     charge_on_small_hit() 小技能命中+20 / take_damage() 受到伤害+15；
##     均 clamp 到 charge_max；consume_ult() 释放大招后 charge=0
##   is_alive() -> bool / can_use_ult() -> bool
## =============================================================

const CHARGE_ACTIVE := 10     # 自身回合激活开始（§3）
const CHARGE_SMALL_HIT := 20  # 小技能命中（§3）
const CHARGE_DAMAGED := 15    # 受到伤害（§3）

var id := ""
var name := ""
var is_ally := true
var hp := 0
var max_hp := 0
var atk := 0
var def := 0
var spd := 0
var charge := 0
var charge_max := 100
var charge_free := false
var ult_charge_retain := 0.0  # 大招后 charge 保留比例（0=归零 §3；汇流编组 BM 设 0.3 §4.2）
var skill_small: Variant = null  # DM.SkillData
var skill_ult: Variant = null    # DM.SkillData
var alive := true

## 从 DataManager 填充单位数据（角色走 characters.csv，敌人走 enemies.csv）；
## 配合 BU.new() 两步构造
func setup(dm, uid: String, is_ally: bool) -> void:
	var d: Variant = dm.get_character(uid) if is_ally else dm.get_enemy(uid)
	id = uid
	name = str(d.name)
	self.is_ally = is_ally
	max_hp = int(d.hp)
	hp = max_hp
	atk = int(d.atk)
	def = int(d.def)
	spd = int(d.spd)
	charge_free = false  # MVP 三觉醒者恒 false；机制字段按 §3 预留
	skill_small = dm.get_skill(str(d.skill_small))
	skill_ult = dm.get_skill(str(d.skill_ult))

func _to_string() -> String:
	return "%s(hp=%d/%d atk=%d def=%d spd=%d charge=%d/%d%s)" % [
		name, hp, max_hp, atk, def, spd, charge, charge_max,
		" charge_free" if charge_free else ""]

func is_alive() -> bool:
	return alive

## 受到伤害：扣血 + 充能 +15（§3），死亡在此判定
func take_damage(dmg: int) -> void:
	hp = maxi(hp - dmg, 0)
	alive = hp > 0
	charge_on_damaged()

## 充能途径①：自身回合激活开始 +10
func charge_on_turn_start() -> void:
	charge = mini(charge + CHARGE_ACTIVE, charge_max)

## 充能途径②：小技能命中 +20
func charge_on_small_hit() -> void:
	charge = mini(charge + CHARGE_SMALL_HIT, charge_max)

## 充能途径③：受到伤害 +15
func charge_on_damaged() -> void:
	charge = mini(charge + CHARGE_DAMAGED, charge_max)

## 释放大招后充能：默认归零（§3）；汇流编组保留上限×30%（§4.2，BM 按体系设 retain）
func consume_ult() -> void:
	charge = int(charge_max * ult_charge_retain)

## 大招是否可释放（§3：充能满或 charge_free）；数据层图标三态查询用
func can_use_ult() -> bool:
	return charge_free or charge >= charge_max
