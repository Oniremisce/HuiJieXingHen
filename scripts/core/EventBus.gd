## =============================================================
## 《汇界星痕》T0.4 EventBus（全局事件总线，Autoload 单例）
## -------------------------------------------------------------
## 所有跨模块解耦通信统一走此总线：发射方 emit，接收方 connect。
## 注意：Autoload 顺序必须先于 GameState 等依赖方（见 project.godot）。
## Dialogic 信号 → EventBus 的转发层在 T4.2 实现（见 GameState.dialogue_signal_bridge）。
## =============================================================
extends Node

## 地图交互请求（玩家对 NPC/物件发起交互，携带目标节点）
signal interact_requested(node: Node)

## 对话演出开始/结束（timeline_id 与 dialogues CSV 的 timeline_id 一致）
signal dialogue_started(timeline_id: String)
signal dialogue_finished(timeline_id: String)

## 战斗开始（敌人 id 列表，如 ["corrosion_beast"]）
signal battle_started(enemy_ids: Array)
## 战斗结束（结果字典，如 {"outcome": "win", "rounds": 3}）
signal battle_finished(result: Dictionary)

## 心契任务步骤推进（quest_id 对应 quests.csv，step 为新步骤编号）
signal quest_updated(quest_id: String, step: int)

## 唤星单抽完成（结果字典，如 {"entry_id", "name", "kind", "gold"}）
signal summon_completed(result: Dictionary)

## 觉醒者招募入队（character_id 对应 characters.csv）
signal character_recruited(character_id: String)
