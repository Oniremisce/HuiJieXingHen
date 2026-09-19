extends RefCounted
# ============================================================
# T3.2a 跑速条模拟器（口径：docs/系统规则/战斗系统.md §2 跑速条制）
# 纯数学模块：无场景依赖、无 autoload 依赖、无技能/充能/伤害逻辑。
# 只做一件事：给定一回合的参战单位，产出该回合的出手顺序。
#
# 规则口径（§2.2/§2.3 + 推进表 T3.2 卡）：
#   1. 速度条上限 BAR_CAP=100；回合开始全员置 0。
#   2. 每 tick 所有未出手单位按各自 spd 前推；同一 tick 内到达 >=100 者
#      出手（多个同时到达按 tie-break 排序依次出手）。
#   3. tie-break：spd 高者优先 → 我方优先 → 编队序（输入数组顺序）。
#   4. 出手后位置归 0 且本轮不再前推（每轮限出手一次，§2.3；§2.2
#      「继续参与前推」的宽松表述以 §2.3 明文为准）。
#   5. 全员出手过后本回合结束（本函数返回完整顺序即一回合）；
#      下一回合由调用方（T3.2b BattleManager）再次调用，全员重新置 0。
#   6. 演出期间后台跑条瞬间推进、出手时暂停（§2.2）：本模块为瞬时
#      纯函数，天然等价于"后台瞬间推进"；暂停钩子属 T3.2b 状态机。
#
# 对外接口（T3.2b BattleManager 消费，勿改名）：
#   const SIM := preload("res://scripts/battle/speed_bar_simulator.gd")
#   SIM.simulate_round(units) -> Array[int]
#     units: Array[Dictionary]，每项至少 {"spd": int, "is_ally": bool}，
#            可附带 "id"（仅供调用方自用，模拟器按输入下标返回）；
#            数组顺序 = 编队序（tie-break 第 3 级）。
#     返回：出手顺序 = units 的下标序列（先出手在前）。
#   防御：spd <= 0 按 1 处理并 push_warning（防死锁；MVP 数据 spd>=8）。
#
# 手算示例（整除友好，冒烟用例1）：我方A spd=10 / 我方B spd=20 / 敌方C
# spd=25，到达 tick = ceil(100/spd) = 10/5/4 → 一回合顺序 C→B→A，
# 即返回 [2, 1, 0]；第二轮全员重置后顺序相同。
# ============================================================

const BAR_CAP := 100

# 模拟一回合，返回出手顺序（units 下标数组，先出手在前）。
static func simulate_round(units: Array) -> Array:
	var n := units.size()
	if n == 0:
		return []
	var pos: Array = []    # 当前条位置（int）
	var acted: Array = []  # 本轮是否已出手（bool）
	var spd: Array = []    # 有效速度（int，>=1）
	var ally: Array = []   # 是否我方（bool）
	for i in range(n):
		var s := int(units[i].get("spd", 0))
		if s <= 0:
			push_warning("[SPEEDBAR] 单位 idx=%d spd<=0，按 1 处理（防死锁）" % i)
			s = 1
		spd.append(s)
		ally.append(bool(units[i].get("is_ally", false)))
		pos.append(0)
		acted.append(false)
	var order: Array = []
	var remaining := n
	while remaining > 0:
		# 1) 本 tick：所有未出手单位按各自 spd 前推一格
		var arrived: Array = []
		for i in range(n):
			if acted[i]:
				continue
			pos[i] += spd[i]
			if pos[i] >= BAR_CAP:
				arrived.append(i)
		# 2) 同 tick 到达者按 tie-break 依次出手
		_arrive_sort(arrived, spd, ally)
		for i in arrived:
			order.append(i)
			acted[i] = true
			pos[i] = 0  # 出手归 0，本轮冻结不再前推（§2.3）
			remaining -= 1
	return order

# 到达者排序（就地插入排序）：键 = (spd 降序, 我方优先, 下标升序)。
# 不用 sort_custom/lambda，保持纯静态、规避 Callable 静态上下文兼容坑。
static func _arrive_sort(arrived: Array, spd: Array, ally: Array) -> void:
	for a in range(1, arrived.size()):
		var key: int = arrived[a]
		var b: int = a - 1
		while b >= 0 and _arrive_before(key, arrived[b], spd, ally):
			arrived[b + 1] = arrived[b]
			b -= 1
		arrived[b + 1] = key

# a 是否应排在 b 之前。
static func _arrive_before(a: int, b: int, spd: Array, ally: Array) -> bool:
	if int(spd[a]) != int(spd[b]):
		return int(spd[a]) > int(spd[b])  # spd 高者优先
	if bool(ally[a]) != bool(ally[b]):
		return bool(ally[a])              # 我方优先
	return a < b                          # 编队序（输入下标）
