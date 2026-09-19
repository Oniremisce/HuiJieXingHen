## =============================================================
## 《汇界星痕》T0.4 GameState（全局状态，Autoload 单例）
## -------------------------------------------------------------
## 持有跨场景持久状态：星砂、星缘令、剧情 flag 字典。
## 依赖：EventBus（Autoload 顺序必须在 EventBus 之后）。
## 剧情信号桥接：dialogue_signal_bridge() 为 T4.2 预留骨架。
## =============================================================
extends Node

## 星砂（基础货币，战斗/任务产出，唤星消耗）
var star_sand: int = 0
## 星缘令（唤星抽取消耗品）
var starlink_tokens: int = 0
## 主角名（T2.5 命名面板写入；存档序列化项，SaveManager 桥接；
## 默认占位「异乡人」，重开新档由命名面板重新写入）
var hero_name: String = "异乡人"
## 剧情 flag 字典（key: String，value: bool/int/String 等任意 Variant）
var flags: Dictionary = {}


## 写入主角名并广播（T2.5 命名面板/读档应用统一入口）
func set_hero_name(name: String) -> void:
	if hero_name == name:
		return
	hero_name = name
	get_node("/root/EventBus").hero_name_changed.emit(name)


## ------------------------------------------------------------
## 剧情 flag 读写
## ------------------------------------------------------------
## 写入 flag（默认布尔 true，兼容数值/字符串型进度值，如好感度）
func set_flag(key: String, value: Variant = true) -> void:
	flags[key] = value

## 读取 flag，不存在返回 default
func get_flag(key: String, default: Variant = null) -> Variant:
	return flags.get(key, default)

## flag 是否存在（存在但值为 false 也算 true；需要值判断时用 get_flag）
func has_flag(key: String) -> bool:
	return flags.has(key)


## ------------------------------------------------------------
## 货币
## ------------------------------------------------------------
## 增减星砂（神像首亮奖励/战斗结算/唤星消耗等；负数=消耗）
func add_sand(amount: int) -> void:
	star_sand += amount


## ------------------------------------------------------------
## Dialogic 信号桥接接口（T4.2 落地；DialogicBridge 统一调用）
## ------------------------------------------------------------
## Dialogic 的 signal_event 触发后，由桥接层（scripts/dialogue/DialogicBridge.gd）
## 解析协议后统一调用本方法：
##   event_name：Dialogic signal 事件中的自定义信号名
##   data：信号附带参数字典
## 分发规则：
##   set_flag（data={"flag", "value"}）→ GameState 写剧情 flag
##   quest_advance（data={"quest_id", "step"}）→ 写剧情 flag + EventBus.quest_updated 广播
##   其余剧情事件（battle_request/recruit_request 等）按 P3/P6 需要扩展
func dialogue_signal_bridge(event_name: String, data: Dictionary) -> void:
	match event_name:
		"set_flag":
			var flag_name := str(data.get("flag", ""))
			if flag_name.is_empty():
				push_warning("[GameState] dialogue_signal_bridge：set_flag 缺少 flag 名（data=%s）" % [data])
				return
			var value: Variant = data.get("value", true)
			set_flag(flag_name, value)
			print("[GameState] set_flag %s=%s（对话桥接）" % [flag_name, str(flags[flag_name])])
		"quest_advance":
			var quest_id := str(data.get("quest_id", ""))
			var step := int(data.get("step", 0))
			set_flag("quest_%s_step" % quest_id, step)
			get_node("/root/EventBus").quest_updated.emit(quest_id, step)
			print("[GameState] quest_advance %s→step %d（对话桥接，quest_updated 已广播）" % [quest_id, step])
		_:
			push_warning("[GameState] dialogue_signal_bridge：未注册事件 '%s'（data=%s）" % [event_name, data])
