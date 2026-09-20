## =============================================================
## 《汇界星痕》T2.11 升级系统常量与逻辑（静态工具，不注册 autoload）
## -------------------------------------------------------------
## 数值口径（数值策划01 可改，无需动代码逻辑）：
##   LEVEL_CAP             等级上限 Lv.10
##   EXP_PER_ENEMY         战斗胜利每敌经验 50（本轮仅定义常量；T3.12 后接入 battle_finished）
##   exp_needed(level)     经验曲线 = 100 × level（线性，当前等级升级到下一级所需）
## 成长值不由本文件定义：按体系英文代号 mech/arcane/xian 读 data/csv/level_growth.csv
##   （数值策划01 已交付），DataManager 加载后注入 CharacterData.growth。
## 战斗属性公式（角色系统.md §2.1）：战斗属性 = CSV 基础四维 + (level-1) × growth
## 升级逻辑：经验达标即升级、溢出结转、多级连升、封顶 LEVEL_CAP。
## =============================================================
extends RefCounted

const LEVEL_CAP := 10
const EXP_PER_ENEMY := 50

## 经验曲线：升到下一级所需经验 = 100 × 当前等级（线性）
static func exp_needed(level: int) -> int:
	return 100 * level


## 累计经验并结算升级：溢出结转、多级连升、封顶 LEVEL_CAP。
## ch 为 CharacterData 对象（就地改 level/exp），返回本次最终等级。
static func add_exp(ch, amount: int) -> int:
	if ch == null:
		return 1
	if amount <= 0:
		return ch.level
	ch.exp += amount
	return _settle_levels(ch)


## 手动 +1 级（封顶 LEVEL_CAP，不消耗经验；供 UI/调试使用）。
static func level_up(ch) -> int:
	if ch == null:
		return 1
	ch.level = mini(ch.level + 1, LEVEL_CAP)
	print("[LevelSystem] 角色 %s 升级到 Lv.%d" % [ch.id, ch.level])
	return ch.level


## 内部：按当前 exp 结算所有可达升级（溢出结转；到顶后 exp 归零）
static func _settle_levels(ch) -> int:
	while ch.level < LEVEL_CAP:
		var need := exp_needed(ch.level)
		if ch.exp < need:
			break
		ch.exp -= need
		ch.level += 1
		print("[LevelSystem] 角色 %s 升级到 Lv.%d" % [ch.id, ch.level])
	if ch.level >= LEVEL_CAP:
		ch.exp = 0
	return ch.level