## =============================================================
## 《汇界星痕》T2.4 SaveManager（存档系统，Autoload 单例）
## -------------------------------------------------------------
## 推进表 §2.5 签名：
##   save_game(slot_id, is_auto=false) -> bool
##   load_game(slot_id) -> Dictionary（坏档返回空字典+日志，不崩溃）
##   rollback_auto() -> bool（回退最近有效自动档）
##   has_save(slot_id) -> bool
## 文件：user://save_<slot>.json；手动档单覆盖（save_manual）；
##   自动档滚动 4 份（新档写 save_auto，旧档顺移 save_auto_1/2/3）。
## JSON 结构（version=1）：
##   { version, saved_at,
##     game_state: {star_sand, starlink_tokens, flags},
##     party: {members, companion_id},
##     heart_bond: []（预留）, inventory: []（预留）, quests: {}（预留）,
##     shrines: {lit_shrines}, map: {unlocked_regions},
##     gacha: {pity_counter}（预留）, protagonist: {name}（预留） }
## 自动档触发点：点亮神像（本卡）；进场景/任务关闭 → T4.3/T5.3/T7.1 补挂钩。
## 读档应用对象：GameState / Party / ShrineSystem / MapSystem；
##   预留项随对应系统落地扩清单（T5.x/T6.x 回归）。
## 单例引用统一 get_node（T2.2 约定，规避 script_check 离线误报）。
## 依赖顺序：GameState/Party/MapSystem/ShrineSystem 均先于本单例。
## =============================================================
extends Node

const SAVE_VERSION := 1
const PROTAGONIST_DEFAULT := "异乡人"
const AUTO_SLOTS: Array[String] = ["auto", "auto_1", "auto_2", "auto_3"]

## 主角命名（T5.x 命名 UI 接管；存档序列化项）
var protagonist_name: String = PROTAGONIST_DEFAULT
## 抽卡保底计数（T6.3 唤星系统接管；存档序列化项）
var pity_counter: int = 0

@onready var _game_state: Node = get_node("/root/GameState")
@onready var _party: Node = get_node("/root/Party")
@onready var _shrine_system: Node = get_node("/root/ShrineSystem")
@onready var _map_system: Node = get_node("/root/MapSystem")


# ---------------------------------------------------------------
# 对外接口（推进表 §2.5 签名）
# ---------------------------------------------------------------

## 存档：汇总各单例状态 → user://save_<slot>.json；成功 true
func save_game(slot_id: String, is_auto: bool = false) -> bool:
	var data := _collect()
	if is_auto:
		_rotate_auto()
	var path := "user://save_%s.json" % slot_id
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("[SaveManager] 写档失败：%s（err=%d）" % [path, FileAccess.get_open_error()])
		return false
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	print("[SaveManager] save_game(%s, is_auto=%s) -> %s（star_sand=%d flags=%d lit=%d）" % [
		slot_id, str(is_auto), path, _game_state.star_sand, _game_state.flags.size(),
		_shrine_system.lit_shrines.size()])
	return true


## 读档：解析 → 校验 → 应用到各单例，返回存档字典；坏档/缺失返回空字典
func load_game(slot_id: String) -> Dictionary:
	var path := "user://save_%s.json" % slot_id
	if not FileAccess.file_exists(path):
		push_warning("[SaveManager] load_game(%s)：档不存在 %s" % [slot_id, path])
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("[SaveManager] load_game(%s)：打开失败 err=%d" % [slot_id, FileAccess.get_open_error()])
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		push_warning("[SaveManager] load_game(%s)：JSON 解析失败（坏档），返回空字典" % slot_id)
		return {}
	var data: Dictionary = parsed
	if int(data.get("version", -1)) != SAVE_VERSION:
		push_warning("[SaveManager] load_game(%s)：version=%s 不兼容（期望 %d），返回空字典" % [
			slot_id, str(data.get("version")), SAVE_VERSION])
		return {}
	_apply(data)
	print("[SaveManager] load_game(%s) 应用完成：star_sand=%d flags=%d lit=%s regions=%s" % [
		slot_id, _game_state.star_sand, _game_state.flags.size(),
		str(_shrine_system.lit_shrines), str(_map_system.unlocked_regions)])
	return data


## 回退最近有效自动档（手动档损坏时由上层调用）；成功 true
func rollback_auto() -> bool:
	for slot: String in AUTO_SLOTS:
		if has_save(slot) and not load_game(slot).is_empty():
			print("[SaveManager] rollback_auto -> %s" % slot)
			return true
	push_warning("[SaveManager] rollback_auto：无可用自动档")
	return false


func has_save(slot_id: String) -> bool:
	return FileAccess.file_exists("user://save_%s.json" % slot_id)


# ---------------------------------------------------------------
# 序列化 / 应用（内部）
# ---------------------------------------------------------------

func _collect() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"game_state": {
			"star_sand": _game_state.star_sand,
			"starlink_tokens": _game_state.starlink_tokens,
			"flags": _json_safe(_game_state.flags),
		},
		"party": {
			"members": _json_safe(_party.get_members()),
			"companion_id": str(_party.companion_id),
		},
		"heart_bond": [],   # 预留（T5.x 心契系统）
		"inventory": [],    # 预留（T6.1 道具 / T6.5 星髓实例逐枚序列化）
		"quests": {},       # 预留（T4.3 任务进度）
		"shrines": {"lit_shrines": _shrine_system.get_lit_shrines()},
		"map": {"unlocked_regions": _map_system.get_unlocked_regions()},
		"gacha": {"pity_counter": pity_counter},
		"protagonist": {"name": protagonist_name},
	}


func _apply(data: Dictionary) -> void:
	# GameState：货币 + flag 全量
	var gs: Dictionary = data.get("game_state", {})
	_game_state.star_sand = int(gs.get("star_sand", 0))
	_game_state.starlink_tokens = int(gs.get("starlink_tokens", 0))
	_game_state.flags = {}
	var flags: Variant = gs.get("flags", {})
	if flags is Dictionary:
		for k: Variant in flags:
			_game_state.flags[str(k)] = flags[k]
	# Party：编队 + 同行者（坏档防御：同行者不在编队则清空，T2.2 §6 #7 约定）
	var pt: Dictionary = data.get("party", {})
	_party.members.clear()
	var members: Variant = pt.get("members", [])
	if members is Array:
		for m: Variant in members:
			_party.members.append(str(m))
	_party.companion_id = str(pt.get("companion_id", ""))
	if _party.companion_id != "" and not (_party.companion_id in _party.members):
		_party.companion_id = ""
	# ShrineSystem：点亮回填（新增项补发 shrine_lit 刷新场景视觉）
	_shrine_system.deserialize(data.get("shrines", {}).get("lit_shrines", []))
	# MapSystem：区块解锁（直接写，不逐个发信号；起始区块保底）
	var mp: Dictionary = data.get("map", {})
	_map_system.unlocked_regions.clear()
	var regions: Variant = mp.get("unlocked_regions", [])
	if regions is Array:
		for r: Variant in regions:
			if not (str(r) in _map_system.unlocked_regions):
				_map_system.unlocked_regions.append(str(r))
	if not _map_system.unlocked_regions.has("region_camp"):
		_map_system.unlocked_regions.append("region_camp")
	# 预留项
	var gc: Dictionary = data.get("gacha", {})
	pity_counter = int(gc.get("pity_counter", 0))
	protagonist_name = str(data.get("protagonist", {}).get("name", PROTAGONIST_DEFAULT))
	# heart_bond / inventory / quests：对应系统落地后扩展应用（T5.x/T6.x）


## 自动档滚动：save_auto_2→_3、_1→_2、auto→_1，新档随后写 save_auto
func _rotate_auto() -> void:
	for i: int in [2, 1]:
		var src := "user://save_auto_%d.json" % i
		var dst := "user://save_auto_%d.json" % (i + 1)
		if FileAccess.file_exists(src):
			DirAccess.copy_absolute(src, dst)
	if FileAccess.file_exists("user://save_auto.json"):
		DirAccess.copy_absolute("user://save_auto.json", "user://save_auto_1.json")


## 递归转 JSON 安全类型（Vector2 等引擎类型降级字符串，避免静默丢数据）
func _json_safe(v: Variant) -> Variant:
	match typeof(v):
		TYPE_DICTIONARY:
			var out := {}
			for k: Variant in v:
				out[str(k)] = _json_safe(v[k])
			return out
		TYPE_ARRAY:
			var out2 := []
			for e: Variant in v:
				out2.append(_json_safe(e))
			return out2
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_NIL:
			return v
		_:
			return str(v)
