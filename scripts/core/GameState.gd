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
## 剧情 flag 字典（key: String，value: bool/int/String 等任意 Variant）
var flags: Dictionary = {}


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
## Dialogic 信号桥接接口（T4.2 实现，本卡仅骨架）
## ------------------------------------------------------------
## Dialogic 的 signal_event 触发后，由桥接层（T4.2 的 DialogicBridge）统一调用：
##   event_name：Dialogic signal_event 中的自定义信号名，如 "quest_advance"
##   data：信号附带参数字典，如 {"quest_id": "heartbond_01", "step": 1}
## 约定分发规则（T4.2 落地）：
##   quest_advance → GameState 写剧情 flag + EventBus.quest_updated 广播
##   其余剧情事件（battle_request/recruit_request 等）按 P3/P6 需要扩展
## 本卡骨架只回显参数做联调验证，不产生任何状态变更。
func dialogue_signal_bridge(event_name: String, data: Dictionary) -> void:
	print("[GameState] dialogue_signal_bridge（骨架）：event=%s, data=%s（T4.2 接入 Dialogic signal_event）" % [
		event_name, data,
	])
