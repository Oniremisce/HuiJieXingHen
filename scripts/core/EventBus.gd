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

## 编队数据变更（T2.2 Party 发出；party_list = 编队角色 id 快照，
## 同行者本就 ∈ members 不重复计入；仅确有变更时发一次，规则见 docs/系统规则/队伍系统.md §3）
signal party_changed(party_list: Array)

## 地图区块解锁（T2.3 MapSystem 发出；神像点亮 / 剧情事件直调 unlock_region），
## 世界大地图、存档系统（T2.4）消费
signal map_region_unlocked(region_id: String)

## UI 面板打开/关闭（T2.3 MapUI 起统一走此对信号；panel_name 如 "map_sandbox"），
## 暂停管理器、音效等消费；T2.5 各面板接入后统一此出口
signal ui_open(panel_name: String)
signal ui_closed(panel_name: String)

## 神像点亮（T2.4 ShrineSystem 发出；场景内 Shrine 实体消费刷新亮态视觉、
## 世界大地图/箱庭图据 ShrineSystem 真值重绘）
signal shrine_lit(shrine_id: String)

## 玩家进入神像恢复光环（T2.4 Shrine 发出；任务/音效等消费）
signal shrine_entered_radius(shrine_id: String)

## 主角命名变更（T2.5 命名面板/读档发出；HUD 左上名、对话立绘标注等消费）
signal hero_name_changed(hero_name: String)
