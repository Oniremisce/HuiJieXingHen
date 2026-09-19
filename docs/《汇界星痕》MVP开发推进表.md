# 《汇界星痕》MVP 开发推进表

> **权威输入**：《汇界星痕》初期设定.md（设计规则）、`docs/系统设计架构/底层系统设计架构_v0.1.md`（系统规格）
> 项目路径：`D:\Dev\HuiJieXingHen`　技术栈：Godot 4.7 · GDScript · Dialogic 2 · CSV 配表 · Git + GitHub 私有仓库 · Godot MCP
> 开发方式：多 AI Agent 协作，岗位编号与职责见《岗位总览》

***

## 1. MVP 范围与验收目标

| # | 交付项 | 验收目标（MVP 级） |
| --- | --- | --- |
| 1 | 等距 2.5D Q 版地图 ×1（营地+首关） | 可自由漫游、Y 轴遮挡正确、被遮挡白描边生效、NPC 交互提示生效 |
| 2 | 觉醒者 ×3 | CSV 数据可加载、地图占位 + Dialogic 立绘占位可显示、头顶名牌读 CSV |
| 3 | 主线剧情 ×1 | 地图触发 Dialogic 演出（暂停世界），完成 3 名觉醒者的剧情邂逅 |
| 4 | 心契任务 ×1 | 同行→互动→满阶状态机完整（quests.csv 驱动）；NPC 头顶粉色 ？/！ 标记 |
| 5 | 三人回合制战斗 ×1 | 三人小队 vs 灾蚀兽，混元机制可触发，战斗演出占位，走 Transition 层 |
| 6 | 唤星模拟 ×1 | 星砂单抽 100 + 保底（pity_counter）→星缘令→（心契满阶后）招募入队闭环 |
| 7 | 视觉框架与地图 UI | 8 向动画接口、遮挡描边、Transition 层、M 键箱庭图、世界大地图区块解锁、常驻 HUD |
| 8 | 神像与存档 | 神像恢复/点亮/传送/存档；自动档+手动档（1 覆盖+3 回滚）；坏档不崩溃 |
| 9 | UI 面板体系 | B/C/G/J/M/Esc 快捷键、主页菜单（暂停世界）、角色列表+详情分页（含星髓面板骨架）、任务面板三色分组、设置三页、主角自定义命名 |
| 10 | 星髓体系 | 6 槽装备、2 件套数值/3 件套效果（体系无关）、面板三区、养成骨架 |

**硬约束**：无真实美术资源（占位色块）；离线单机；所有资源可肝；唤星不跳过剧情（招募前置 = 邂逅 + 心契满阶）；无内购；地图仅主角移动。

***

## 2. 技术基线与公共约定

### 2.1 权威分工

| 主题 | 权威出处 |
| --- | --- |
| 系统规格（渲染/玩法/UI/数据/美术） | `docs/系统设计架构/底层系统设计架构_v0.1.md`（下称「架构文档」，制作人修订版） |
| 设计规则（体系/心契/唤星/混元） | `docs/《汇界星痕》初期设定.md` |
| 任务卡定义与验收 | 本表 §4 |

### 2.2 已交付底座（T0.1~T2.1 已交付，勿重做）

- **Autoload 顺序**：Dialogic→DataManager→EventBus→GameState（勿调整；新增单例追加在尾部）。
- **数据模型**：`scripts/core/data_models.gd` 内部类，引用统一 `const DM := preload("res://scripts/core/data_models.gd")`（不依赖全局 class_name）。
- **EventBus 已注册 8 信号**：interact_requested / dialogue_started / dialogue_finished / battle_started / battle_finished / quest_updated / summon_completed / character_recruited；GameState：star_sand/starlink_tokens/flags + dialogue_signal_bridge 骨架。
- **地图**：TestMap（24×24 等距 DIAMOND_RIGHT，tile 64×32）、CampMap（主场景）；玩家 Player.tscn（八方向 + Camera2D 平滑跟随 + limit 钳制）；Interactable 组件（Area2D r=60、action `interact`=E+空格、R3 最近者仲裁、`interact_requested(self)`）。
- **数值口径**：energy_cost=1(small)/3(ult)；power=倍率制（float）；三觉醒者已命名（诺菈·星枢/艾蕾雅/洛清弦）。

### 2.3 技术选型与规范

| 项 | 方案 |
| --- | --- |
| 引擎 | Godot 4.7 稳定版，GDScript（project.godot 锁定） |
| 对话 | Dialogic 2，timeline `.dtl` 由 `tools/csv_to_dialogic.gd` 从台词 CSV 生成（T4.2） |
| 配表 | CSV（UTF-8），CSVParser 容错解析；坏行报错含文件+行号不崩溃 |
| 等距 | TileMapLayer + isometric tileset（TILE_LAYOUT_DIAMOND_RIGHT，tile 64×32），Y-sort 链式遮挡，实体 origin=脚底 |
| 输入绑定 | 统一 physical_keycode；action 由代码兜底注册（`_ensure_input_action()` 先例，防编辑器覆写回滚） |
| MCP 验证 | 每卡验收含「MCP 运行证据」（日志/截图/execute_code 断言）；execute_code 为纯表达式、不支持 lambda；访问 Autoload 用 `get_node("/root/名")` |
| Git | 每卡一 commit（`Tx.x: 描述`）→ push origin master；交接班表按 9 列模板追加 |

### 2.4 核心数据模型

- **CharacterData**：`id/name/faction/system/hp/atk/def/spd/skill_small/skill_ult/portrait_id/sprite_id`（预留 `starmarrow_slots`=6、`sprite_idle_8dir`/`sprite_walk_8dir`）
- **SkillData**：`id/name/type/power(float)/energy_cost/cutscene_id`（cutscene_id 沿用 cut_mech_ult/cut_arcane_ult/cut_xian_ult）
- **EnemyData**：`id/name/hp/atk/def/spd/ai_pattern/drop_sand`
- **StelliumData**：`id/name/rarity/set_id/set_name/set_type(2|3)/set_2_bonus/set_3_bonus/main_stat/sub_stats/lv`
- **SummonEntryData**：`entry_id/name/kind/gold/weight`
- **QuestData**：`quest_id/step/step_name/requirement/target/reward/next_step`（quests.csv 预留 `quest_type`=main/side/bond、`priority`、`mark_color`）

### 2.5 新增全局单例

| 单例 | 关键接口 |
| --- | --- |
| ArtProvider | get_character_sprite(id) / get_portrait(id, emotion) / get_tile_texture / get_cg / get_skill_fx / get_ui_icon / get_bgm / get_sfx |
| Transition | transition_scene(from_path, to_path, duration=0.4) / transition_portal(target_id, duration=0.4) / transition_fade_out / transition_fade_in |
| PauseManager | pause_game(reason) / resume_game(reason) / is_paused() |
| SaveManager | save_game(slot_id, is_auto=false)->bool / load_game(slot_id)->Dictionary / rollback_auto()->bool / has_save(slot_id)->bool |
| MapSystem | unlock_region(region_id) / is_region_unlocked(region_id)->bool / get_region_by_shrine(shrine_id)->String |

**EventBus 新增信号**（先注册再使用，禁止散写 emit）：`shrine_lit(shrine_id)`、`shrine_entered_radius(shrine_id)`、`map_region_unlocked(region_id)`、`party_changed(party_list)`、`starmarrow_changed(character_id, before, after)`、`ui_open(panel_name)`、`ui_closed(panel_name)`。

**货币归属裁决**：星砂/星缘令在 `GameState.star_sand/starlink_tokens`（已交付事实优先）；Inventory 管道具/星髓持有/CG 图鉴。

***

## 3. 阶段总览与依赖关系

| 阶段 | 名称 | 任务卡 | 状态 | 依赖 |
| --- | --- | --- | --- | --- |
| P0 | 项目骨架与工具链 | T0.1~T0.4 | ✅ 完成 | — |
| P1 | 等距地图与移动 | T1.1~T1.6 | ✅ 完成 | P0 |
| P2 | 角色数据、队伍与底层系统框架 | T2.1✅、T2.2 进行中、T2.3~T2.8 | 进行中 | P0（与 P1 并行） |
| P3 | 战斗系统 | T3.1~T3.7 | 待启动 | P2（T2.1/T2.2） |
| P4 | Dialogic 剧情演出 | T4.1~T4.4 | 待启动 | P1、P2 |
| P5 | 心契任务 | T5.1~T5.4 | 待启动 | P3、P4 |
| P6 | 唤星模拟 | T6.1~T6.5 | 待启动 | P5 |
| P7 | 整合与验收 | T7.1~T7.4 | 待启动 | 全部 |

```
graph TD
    P0[P0 骨架✅] --> P1[P1 地图✅]
    P0 --> P2[P2 数据/队伍/框架]
    P1 --> P4[P4 剧情演出]
    P2 --> P3[P3 战斗]
    P2 --> P4
    P2 --> P5[P5 心契]
    P3 --> P5
    P4 --> P5
    P5 --> P6[P6 唤星]
    P6 --> P7[P7 整合验收]
    T2.3/T2.4/T2.5[T2.3~T2.5 框架] --> P5
    T2.4 --> P6
```

**并行建议**：T2.3~T2.5（系统程序串行）与 T3.1（数值策划，仅依赖 T0.3）可立即并行；T2.6（美术）、T2.8（数值策划）随时可插空并行。

***

## 4. 任务卡

> 每张卡「【完整指令】」代码块可整体粘贴给 Agent。公共约定见 §2，不逐卡重复。

### 已完成卡（T0.1~T2.1）

| 卡 | 名称 | 定稿产出与关键决策 | commit |
| --- | --- | --- | --- |
| T0.1 | 工程初始化与工具链 | Godot 4.7 工程+目录+Dialogic 2+Git 私有仓库+MCP 连通 | 2398bc8 |
| T0.2 | 核心数据模型 | 6 数据类+from_csv_row 容错；preload 引用约定 | ac4bf75 |
| T0.3 | CSV 配表与加载管线 | 7 张 CSV+CSVParser+DataManager；坏行定位不崩溃 | aa839ef |
| T0.4 | 事件总线与全局状态 | EventBus 8 信号+GameState（货币/flags）+dialogue_signal_bridge 骨架 | 60f0087 |
| T1.1 | 等距 TileMap 与色块 Tileset | DIAMOND_RIGHT 64×32、24×24、障碍碰撞层 | 79fa17f |
| T1.2 | Y-sort 遮挡 | 链式 y_sort_enabled、origin=脚底规则 | b675b65 |
| T1.3 | 玩家八方向移动 | Player.tscn+PlayerController（SPEED=200、physical_keycode、兜底注册） | 7aafd7a |
| T1.4 | 相机平滑跟随 | Camera2D smoothing 7.0、zoom 0.9、limit 四缘贴合 | c68cc9c |
| T1.5 | 交互系统 | 规则文档 87812b1（系统策划01）；Interactable 组件+双测试 NPC f00cec0（系统程序03） | 87812b1 / f00cec0 |
| T1.6 | 营地地图成品与布置 | CampMap.tscn（主场景）+TriggerZone+拾取骨架+3 NPC+名牌 | b8721c2 |
| T2.1 | 三名觉醒者数据 | 数值口径 energy_cost=1/3、power 倍率 float（de32e43，数值策划01）；命名诺菈·星枢/艾蕾雅/洛清弦（b40cd66，剧情文案策划01） | de32e43 / b40cd66 |

> T2.1 遗留修补已登记：A1（名牌）、A2（冒烟断言）→ T2.7；A4（StelliumData 套装制）→ T2.8。

### 进行中：T2.2 队伍系统（架构对齐补充）

原卡指令（Party 单例：3 人编队、companion 同行槽、team_systems() 组合查询）维持不变，系统程序04 执行时**追加以下要求**：

1. Party 数据变更（add_member/remove_member/set_companion/clear_companion）后统一发 `EventBus.party_changed(party_list)`（EventBus 需先注册该信号）。
2. 同行槽只占编队数据，不生成任何地图实体/跟随者（架构 §1.3 已拍板：同行槽不生成地图实体）。
3. team_systems() 基于角色体系（characters.csv system 列），与星髓无关；星髓 6 槽是角色装备槽，归 T6.5，与本卡解耦。
4. 验收追加：party_changed 信号可被 get_node("/root/EventBus") 侧验证（占位 print 日志即可）。

### P2 后续卡（视觉框架 / 神像存档 / UI 面板 / 修补）

#### T2.3 视觉框架与地图 UI

| 字段 | 内容 |
| --- | --- |
| 目标 | 架构 §1 渲染层 + §2.3 地图系统 + §2.6 HUD 落地 |
| 产出 | ArtProvider/PauseManager/Transition/MapSystem 四 Autoload + 描边 shader + 箱庭图 + 世界大地图 + 常驻 HUD |
| 依赖 | T2.1（已过）；建议 T2.2 验收后启动（消费 party_changed） |
| 主责 | 系统程序◎、美术○（描边/线框视觉验证） |
| 预估 | 3~4 轮（内部分四步交付，每步 MCP 可验） |

【完整指令 · 粘贴给 Agent】

```
任务：T2.3 视觉框架与地图 UI
目标：按架构文档（docs/系统设计架构/底层系统设计架构_v0.1.md）§1 渲染层、§2.3 地图系统、§2.6 常驻 HUD、§4.4 接口清单落地。
前置：T2.1 已过；T2.2 进行中（party_changed 信号按先注册后使用处理，可先注册）。
公共约定：Autoload 追加在 Dialogic→DataManager→EventBus→GameState 之后；输入绑定用 physical_keycode 并代码兜底注册；引用数据类用 preload。

分四步交付：

【步骤1 全局单例与 Transition】
1. ArtProvider（Autoload）按架构 §5/推进表 §5.1 接口表实现占位：get_character_sprite(id)（按体系色色块+名字）、get_portrait(id, emotion)、get_tile_texture、get_cg、get_skill_fx、get_ui_icon、get_bgm/get_sfx（静音占位）。业务外观一律走此入口。
2. PauseManager（Autoload）：pause_game(reason)/resume_game(reason)/is_paused()，内部 get_tree().paused；reason 计数式管理（同 reason 多次 open/close 平衡）。
3. Transition 层（Autoload，CanvasLayer）：transition_scene(from_path, to_path, duration=0.4)、transition_portal(target_id, duration=0.4)、transition_fade_out/transition_fade_in；黑场淡入淡出；加载画面仅预留接口（MVP 秒切）。
4. MCP：CampMap 与 TestMap 互切验证 transition_scene（截图黑场过渡+落点正确）。

【步骤2 遮挡描边 + 8 向动画接口】
5. 描边 shader（CanvasItem.material）：纯白 1.5~2px 外描边；触发条件=前景元素 origin 全局 y > 角色脚部 y 且投影重叠（复用 Y-sort 排序数据，不射线检测）；随遮挡面积淡入淡出；玩家与 NPC 均适用。
6. Player/Sprite 与 NPC 视觉挂点预留 8 向动画接口：SpriteFrames 结构（idle 4 帧约 3s / walk 6~8 帧约 0.6s，屏幕空间 8 方向，斜向独立资源非左右翻转）；当前仍用色块占位，仅保证「帧动画切换接口就绪」（PlayerController 走停切换改走该接口）。
7. MCP：角色被 Building1/Building2 遮挡时截图白描边出现、移开后消失。

【步骤3 箱庭图 + 世界大地图（MapSystem）】
8. MapSystem（Autoload）：unlock_region(region_id)/is_region_unlocked(region_id)/get_region_by_shrine(shrine_id)；EventBus 注册并发 map_region_unlocked(region_id)。
9. 箱庭图（M 键）：全屏浮层=半透明暗底+仅描边线框（当前场景可行走区域轮廓：由 TileMapLayer used cells 边界实时生成）；标注：主角点位（体系色箭头）、任务相关 NPC（金色菱形）、神像（已点亮亮色/未点亮灰）、场景出口；NPC 标注仅任务相关（非全部可交互）。
10. 世界大地图：区块化显示；未解锁区块暗黑色剪影、已解锁正常着色、当前区块高亮描边；可点元素=已点亮神像（点击→确认框→transition_portal 传送）、区块名；解锁条件=点亮该区块任意神像（剧情事件解锁预留 map_region_unlocked 直调）。
11. 交互：M 开箱庭图；滚轮向下→平滑缩放过渡进世界大地图；世界大地图滚轮向上→返回箱庭图；ESC 关闭全部地图面板。开关走 ui_open/ui_closed 信号 + PauseManager 暂停。
12. MCP：M 开图→滚轮切换→ESC 关闭各截图；unlock_region 后大地图区块由暗转亮。

【步骤4 常驻 HUD 骨架】
13. HUD（CanvasLayer，常驻）：左上=主角自定义命名（读 GameState 主角名字段，占位「异乡人」）+编队角色头像（Party.party_changed 驱动，色块头像）+当前任务追踪 1 条（QuestRunner 未就绪前占位文本）；右上=小地图占位（简化箱庭缩略，可后期替换）；底部中央=交互提示位（复用 Interactable 提示，或预留挂点）；底部按键提示条（B/C/G/J/M/Esc 说明）首进场景 8s 淡出。
14. HUD 不参与世界 Y-sort（独立 CanvasLayer）；面板开关统一经 ui_open/ui_closed。

验收（全部通过）：
- [ ] 四 Autoload 注册且接口签名与架构 §4.4 一致（MCP 属性核对）
- [ ] 描边：遮挡出现/移开消失（截图×2）
- [ ] M 箱庭图线框与标注正确；滚轮双向切换；ESC 关闭（截图×3）
- [ ] 大地图区块暗/亮/当前高亮三态；点击已点亮神像可传送（暂以 TestMap 假神像验证，正式神像在 T2.4）
- [ ] HUD 四区布局正确（截图）；面板打开时 get_tree().paused=true、关闭恢复

提交：git commit -m "T2.3: 视觉框架与地图UI" 并 push。
```

#### T2.4 神像与存档

| 字段 | 内容 |
| --- | --- |
| 目标 | 架构 §2.2 神像机制 + §2.4 存档系统落地 |
| 产出 | Shrine.tscn/gd、ShrineSystem、SaveManager、CampMap 接入神像 ×1 |
| 依赖 | T2.3（Transition/MapSystem/PauseManager） |
| 主责 | 系统程序◎ |
| 预估 | 2~3 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T2.4 神像与存档
目标：实现神像四行为（恢复/点亮/传送/存档）与存档管线（自动档+手动档+回滚），接入 CampMap。
前置：T2.3 已通过（Transition/MapSystem/暂停可用）。

执行步骤：
1. EventBus 注册新信号：shrine_lit(shrine_id)、shrine_entered_radius(shrine_id)（先注册再 emit）。
2. Shrine.tscn/gd（可交互实体，占位视觉=色块+光环圈）：
   - 恢复：Area2D 光环半径 96px，玩家进入→自动恢复全部角色状态（MVP=HP/星缘满 + 状态重置；星髓无耐久概念，无需恢复）→ 飘字+光效反馈（占位）→ 发 shrine_entered_radius；不弹 UI。
   - 点亮：首次靠近显示「按 E 点亮」（复用 Interactable 提示规则）→ 按 E→短演出（光柱+粒子占位 1s）→ 解锁该神像传送点+get_region_by_shrine 所属区块 unlock_region→首亮奖励星砂×100（GameState.add_sand；常量可调）→ 发 shrine_lit；flag 持久化（lit_shrines）。
   - 传送：仅被世界大地图点击触发（T2.3 已接 transition_portal(target_id=shrine_id)）→ 落点=神像旁出生点。
   - 存档：已点亮神像旁按 E→神像菜单（全屏半透明面板：存档/恢复状态/查看此区域提示三项）→ 存档按钮调 save_game("manual")；菜单打开暂停世界。
3. ShrineSystem（Autoload）：lit_shrines 列表、shrine 数据表（MVP 硬编码 1 座：camp_shrine_01，region=camp；后续可 CSV 化）。
4. SaveManager（Autoload）：
   - save_game(slot_id, is_auto=false)->bool：汇总序列化→user://save_<slot>.json；内容=GameState 全部 flag+货币、Party（members/companion）、HeartBond（预留空表）、Inventory（预留空表）、任务进度（预留）、神像 lit_shrines、地图 unlocked_regions、抽卡 pity_counter（预留，默认 0）、主角命名；version=1。
   - load_game(slot_id)->Dictionary：坏档返回空字典+日志；rollback_auto()->bool：手动档损坏时回退最近自动档；has_save(slot_id)。
   - 自动档触发点：进场景（transition_scene 落地时）/任务关闭/点亮神像——本卡先接「点亮神像」与手动菜单，其余触发点在 T4.3/T5.3/T7.1 补挂钩。
5. CampMap 接入：放 1 座 camp_shrine_01（避开 NPC 站位与触发区）；恢复光环不与 Interactable 检测区冲突。
6. MCP 验证。

验收（全部通过）：
- [ ] 进光环自动恢复（飘字反馈）；shrine_entered_radius 日志
- [ ] 点亮流程完整：提示→演出→区块解锁→星砂+100→shrine_lit；重复按 E 不重复奖励
- [ ] 神像菜单存档→重启项目→读档→flag/货币/神像/区块状态完整恢复（截图对比）
- [ ] 手动写坏 user://save_manual.json→load 返回空字典+rollback_auto 可回退自动档，不崩溃
- [ ] 世界大地图点击已点亮神像→确认框→传送落点正确（Transition 全程）

提交：git commit -m "T2.4: 神像与存档" 并 push。
```

#### T2.5 UI 面板落地

| 字段 | 内容 |
| --- | --- |
| 目标 | 架构 §3 UI 层全部面板骨架与快捷键体系 |
| 产出 | scenes/ui/ 下九个面板 + Esc 层级导航 + 主角命名 |
| 依赖 | T2.3、T2.4 |
| 主责 | 系统程序◎、系统策划○（面板需求核对） |
| 预估 | 3~4 轮（分三步） |

【完整指令 · 粘贴给 Agent】

```
任务：T2.5 UI 面板落地
目标：按架构 §3.1 面板总览与 §2.7 手感细则，落地全部面板骨架、快捷键、Esc 层级导航、暂停世界。
前置：T2.3、T2.4 已通过。

统一规则：
- 面板基类 UIPanel（ scenes/ui/UIPanel.gd）：panel_name、open()/close()；开=ui_open(panel_name)+pause_game(panel_name)，关反向；面板均为全屏或半透明浮层（CanvasLayer，不参与 Y-sort）。
- 快捷键（physical_keycode+代码兜底注册）：B 背包、C 角色列表、G 唤星、J 任务、M 箱庭图（T2.3 已做）、Esc 层级导航。
- Esc 层级导航：当前无任何面板→打开主页菜单；在任何面板中→关闭当前面板回到上一层面板（面板栈管理）。

分三步交付：

【步骤1 主页菜单 + Esc 栈 + 主角命名】
1. 主页菜单 MainMenu（全屏）：快捷入口网格=出发（打开世界大地图）/编队（角色列表）/唤星/背包/任务/设置；顶部常显星砂数值（GameState.star_sand）；打开即暂停世界；背景默认氛围图（纯色渐变占位）。
2. 主角自定义命名：首次进入营地时弹命名面板（单行输入+确认），写入 GameState.hero_name；HUD 左上同步；重开新档重新命名。MVP 可简化为：CampMap 首次进入时触发一次。
3. Esc 栈：面板栈 push/pop，Esc 逐层回退；栈空时 Esc 打开主页菜单。主页菜单本身 Esc 可关闭。

【步骤2 角色列表 + 角色详情分页 + 星髓面板骨架】
4. 角色列表（C）：左详情右列表；右侧纵向头像列（已获角色：头像色块+名+等级+体系色角标；未获角色不显示）；点头像→左侧详情。
5. 角色详情页 1：高清立绘占位（色块）+四维（hp/atk/def/spd 读 CharacterData）+星缘（占位）+技能列表（读 SkillData：名/耗能/倍率）。
6. 角色详情页 2 =星髓面板（三区骨架，数据行 T2.8/T6.5 才有，先用空态+假数据 1 条验证布局）：装备区=6 槽网格 2×3（当前角色）；持有列表=筛选（稀有度/等级/套装——星髓体系无关，无体系筛选）；养成区=升级/突破按钮占位+属性预览。本卡只做布局与空态交互，装备逻辑在 T6.5。
7. 编队操作入口：角色列表中「加入编队/移出」按钮→Party.add_member/remove_member（上限 3，满员提示）。

【步骤3 任务面板 + 唤星面板 + 背包 + 设置】
8. 任务面板（J）：全屏列表按主线/支线/心契三组（组头三色：#FFA640/#6FC9FF/#FF8FC8）；条目=任务名+当前步骤+目标进度；无任务显示空态。数据源 QuestRunner 未就绪→读 quests.csv 直接列骨架。
9. 唤星面板（G）：星砂×100 单抽按钮（星砂不足禁用+提示）+保底进度条（pity_counter/60，占位）+结果展示区（T6.4 接演出）；本卡按钮可置灰标注「T6.2 开放」。
10. 背包（B）：分类 Tab（道具/材料/星髓/任务品）+网格+数量徽标；详情浮层占位；数据源 Inventory 未就绪→空态（T6.1 接）。
11. 设置三页：音频（BGM/音效/UI 三轨音量条）/画面（全屏窗口切换+分辨率下拉）/操作（键位表展示只读）；设置存独立档 user://settings.json（不混入进度档）。主页菜单背景选择器：设置→背景选择（氛围图/已获角色立绘占位列表），选择存设置档。
12. 全部面板开关走 ui_open/ui_closed+暂停；键位提示条（T2.3 HUD）更新为最终键位表。

验收（全部通过）：
- [ ] B/C/G/J/M 五键开合正确；Esc 逐层回退+栈空开主页菜单（操作截图序列）
- [ ] 主页菜单打开时世界暂停（角色不可移动）、关闭恢复
- [ ] 主角命名一次成功且 HUD 左上同步（截图）
- [ ] 角色列表三名觉醒者正确显示，详情四维/技能读 CSV 正确；编队加删实时反映（party_changed）
- [ ] 星髓面板三区布局+空态正确；任务面板三色分组正确
- [ ] 设置三页可调且重启后保留（独立档）

提交：git commit -m "T2.5: UI面板落地" 并 push。
```

#### T2.6 美术视觉规范（占位升级）

| 字段 | 内容 |
| --- | --- |
| 目标 | 架构 §五 美术资源规格的占位态落地与验证 |
| 产出 | 视觉规范文档 + 占位资源包 |
| 依赖 | T2.3（描边/线框可用后） |
| 主责 | 美术◎、系统程序○ |
| 预估 | 1~2 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T2.6 美术视觉规范
目标：按架构 §五 落地占位视觉规范并配合验证，保证后期 AI 资源零改动替换。
前置：T2.3 已通过（描边/箱庭图线框已可用）。

执行步骤：
1. 8 向角色姿势组占位规范：屏幕空间 8 方向（斜向独立资源非翻转）、idle 4 帧（~3s）、walk 6~8 帧（~0.6s）；给出每方向的色块占位图（可用脚本生成 8×2 帧占位条）放入 assets/sprites/characters/（命名 <char_id>_<idle|walk>_<dir>.png，§5.2）。
2. 神像视觉占位：光柱（竖向渐变色块）+粒子（CPUParticles2D 占位）+光环 96px 圈（半透明描边圆），供 T2.4 视觉升级。
3. UI 视觉规范：体系色（机律青 #00BFFF/秘法紫 #9370DB/玄门玉绿 #3CB371）、任务三色（主线 #FFA640/支线 #6FC9FF/心契 #FF8FC8）应用到面板边框/组头/角标；与 T2.5 面板核对一致性。
4. 遮挡描边效果验证：配合系统程序在 Building 前后走查白描边淡入淡出观感，提出宽度/透明度参数建议（1.5~2px 基准）。
5. 立绘规格：角色详情高清立绘与主页菜单背景的尺寸/构图建议（竖版 3:4、主体居中、背景柔化），写入 docs/美术资源接入清单.md。
6. 全部规范汇总更新 docs/美术资源接入清单.md（含 §5.1 接口表逐项当前占位态）。

验收（全部通过）：
- [ ] 8 向占位帧条可被 ArtProvider.get_character_sprite 加载且走停切换可见（截图）
- [ ] 神像占位视觉在场景中可辨识（光柱/光环）
- [ ] UI 三色/体系色与架构色彩表一致（截图对照）
- [ ] docs/美术资源接入清单.md 更新完毕

提交：git commit -m "T2.6: 美术视觉规范" 并 push。
```

#### T2.7 遗留修补（名牌 + 冒烟断言）

| 字段 | 内容 |
| --- | --- |
| 目标 | 清偿 T2.1 登记的 A1/A2 两项遗留 |
| 产出 | CampMap 名牌读 CSV；冒烟测试断言修正 |
| 依赖 | 无（随时可做，建议与 T2.3 并行插空） |
| 主责 | 系统程序◎ |
| 预估 | 半轮~1 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T2.7 遗留修补（A1/A2）
目标：修复 T2.1 命名落地后的两处不同步。
前置：T1.6、T2.1 已过。

执行步骤：
1. A1：CampMap.tscn 三觉醒者 NPC 名牌 Label 当前 display_name="待定"——改为运行时读 DataManager.get_character(npc_id).name（诺菈·星枢/艾蕾雅/洛清弦）；npc_id 属性仍是唯一真相，display_name 不再硬编码在场景里（_ready 时填充）。
2. A2：tools/smoke_test_data_models.gd 中断言 name=="待定" 的两处（约 L21/L35）改为：name 非空且 != "待定"（防回退）。
3. MCP 运行 CampMap：三名牌显示三名正式名（截图）；headless 跑冒烟脚本确认全绿。

验收（全部通过）：
- [ ] 三 NPC 名牌=正式命名（截图）
- [ ] 冒烟测试通过且对空名/「待定」报错
- [ ] 无其他行为变化（交互/触发区回归正常）

提交：git commit -m "T2.7: 遗留修补-名牌与断言" 并 push。
```

#### T2.8 星髓套装制数据修订

| 字段 | 内容 |
| --- | --- |
| 目标 | 架构 §2.5 星髓体系无关化的数据落地（A4） |
| 产出 | stellium.csv 新列结构 + StelliumData 适配 + 占位套装数据 |
| 依赖 | 无（T0.3 管线即可） |
| 主责 | 数值策划01◎（跨岗改 data_models.gd 需台账登记知会系统程序） |
| 预估 | 1 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T2.8 星髓套装制数据修订
目标：按架构 §2.5「星髓仅提供 2 件套数值属性+3 件套效果属性，与体系无关」重构 stellium.csv 与 StelliumData。
前置：T0.3、T2.1 已过。

执行步骤：
1. stellium.csv 列头改为：id,name,rarity,set_id,set_name,set_type,set_2_bonus,set_3_bonus,main_stat,sub_stats,lv
   - set_type ∈ {2,3}：2=该星髓属 2 件套组件（提供数值属性 main_stat/sub_stats）；3=3 件套组件（提供效果 set_3_bonus）
   - set_2_bonus/set_3_bonus：套装效果描述/数值（占位字符串或 JSON 片段，格式先定为 "attr:value;attr:value"）
   - 沿用 BaseRow 按列头映射，旧列语义变化处写清注释
2. 占位数据 6 行：2 个套装（各 1 个 2 件套组件+2 个 3 件套组件），rarity 占位 3/4/5 档，数值占位可调（正式数值 T6.5 前由你复核）。
3. 适配 scripts/core/data_models.gd 的 StelliumData：新增 rarity/set_name/set_type/set_2_bonus/set_3_bonus/lv 字段与 from_csv_row 解析（缺省容错：数值 0、字符串空）；保留 main_stat/sub_stats。
4. 更新 tools/smoke_test_data_models.gd 星髓断言为新字段结构。
5. MCP 运行确认 stellium=6 加载无坏行；str() 打印一行全字段验证。
6. 台账登记：data_models.gd 为跨岗改动（系统程序辖区），在系统程序交接班表追加一行说明「StelliumData 结构变更，T6.5 消费新字段」。

验收（全部通过）：
- [ ] stellium=6 加载无坏行，新字段类型正确
- [ ] set_type=2 行有 main_stat、set_type=3 行有 set_3_bonus（逻辑自洽）
- [ ] 冒烟测试更新后通过
- [ ] 跨岗登记完成

提交：git commit -m "T2.8: 星髓套装制数据修订" 并 push。
```

### P3 战斗系统

#### T3.1 敌人占位数据（灾蚀兽 · CSV）

| 字段 | 内容 |
| --- | --- |
| 目标/产出/依赖 | enemies.csv 正式内容（corrosion_beast，hp≈150/atk≈10/def≈6/spd≈8，ai_pattern=simple，drop_sand=30） |
| 依赖 | T0.3（已过，可立即并行） |
| 主责 | 数值策划◎ |
| 预估 | 1 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T3.1 敌人占位数据（灾蚀兽）
目标：完善 enemies.csv：灾蚀兽属性+简单 AI+星砂掉落。
前置：T0.3 已通过。

执行步骤：
1. enemies.csv 一行：id=corrosion_beast，name=灾蚀兽，hp≈150、atk≈10、def≈6、spd≈8（占位可调），ai_pattern=simple（70% 普攻/30% 小技能），drop_sand=30。
2. MCP 运行确认 enemies=1；get_enemy 返回字段完整、类型正确。

验收：
- [ ] 加载成功，drop_sand 可被战斗结算读取（数值类型正确）

提交：git commit -m "T3.1: 灾蚀兽敌人数据" 并 push。
```

#### T3.2 战斗状态机

```
任务：T3.2 战斗状态机
目标：实现回合制状态机：init(players, enemies) → 回合循环 → 胜负判定；每步输出日志。
前置：T2.1、T3.1 已通过。

执行步骤：
1. BattleManager.gd：状态枚举 intro/player_turn/enemy_turn/win/lose；init(party_ids: Array[String], enemy_ids: Array[String]) 从 DataManager 取数据构造 BattleUnit 列表。
2. 回合流程：回合开始 → 按 spd 排序行动 → 我方行动（等待指令，T3.3 接入）→ 敌方行动（按 ai_pattern 简单执行）→ 回合结束 → 检查胜负。
3. 每步 print 结构化日志：[BATTLE] 回合 N / 行动者 / 目标 / 结果 / 双方 HP。
4. 用 MCP 编辑器执行脚本做无 UI 冒烟：3 人 vs 1 兽，跑 20 回合确认无死锁、可进入 win/lose。

产出：BattleManager.gd。

验收（全部通过）：
- [ ] 日志展示完整回合循环与 HP 变化
- [ ] 可正常进入 win / lose，无死锁
- [ ] 胜负条件正确（全灭敌方=win；全灭我方=lose）

提交：git commit -m "T3.2: 战斗状态机" 并 push。
```

#### T3.3 指令系统

```
任务：T3.3 指令系统
目标：BattleUnit（HP/能量）+ 三种指令（普攻/小技能/终结技）+ 简单目标选择。
前置：T3.2 已通过。

执行步骤：
1. BattleUnit.gd：hp/max_hp/energy/max_energy（上限 3，回合开始 +1）、take_damage、is_alive、技能数据（从 SkillData）。
2. BattleCommand.gd：枚举 ATTACK/SKILL/ULT；execute 前校验：小技能需 energy≥1，终结技需 energy=3；能量不足返回不可用原因。
3. 目标选择：简化 UI（敌人列表按钮/上下键选择），MVP 可先"自动选第一个存活目标 + 手动确认"。
4. MCP 冒烟：脚本直接调用指令执行，验证伤害应用、能量扣除、目标死亡处理。

产出：BattleUnit.gd、BattleCommand.gd。

验收（全部通过）：
- [ ] 三种指令可执行，能量不足被禁用且有提示
- [ ] 死亡目标被跳过，敌人全灭正确结算
- [ ] 终结技消耗 3 能量且伤害倍率正确应用

提交：git commit -m "T3.3: 指令系统" 并 push。
```

#### T3.4 伤害与数值结算

```
任务：T3.4 伤害与数值结算
目标：实现伤害公式并接入战斗日志；数值全部来自 CSV。
前置：T3.3 已通过。

执行步骤：
1. DamageCalc.gd：damage = max(1, atk * skill_power - def)；暴击率 10%（占位）、暴击 ×1.5；输出伤害/暴击判定结果。
2. 把 DamageCalc 接入 BattleCommand 执行路径，日志输出：出手者/技能/伤害/是否暴击/目标剩余 HP。
3. 用 MCP 编辑器执行脚本做 3 组手动验算：给定 atk/def/power 手算期望值，与实际结果比对一致。
4. 数值均从 CharacterData/EnemyData/SkillData 读取，不硬编码。

产出：DamageCalc.gd。

验收（全部通过）：
- [ ] ≥3 组手算与实测一致（日志可证）
- [ ] 伤害下限为 1
- [ ] 数值全部来自 CSV，无硬编码

提交：git commit -m "T3.4: 伤害与数值结算" 并 push。
```

#### T3.5 队伍机制判定（共振/汇流/混元）

```
任务：T3.5 队伍机制判定（共振/汇流/混元）
目标：按《初期设定》实现三态互斥：共振（全同体系）/ 汇流（异体系且三系未齐）/ 混元（三系齐全，不触发前两者）。
前置：T3.4、T2.2 已通过。

认知说明：team_systems() 判定基于角色体系（characters.csv system 列），与星髓完全无关（星髓体系无关化，架构 §2.5）；三态互斥规则不变。

执行步骤：
1. PartyBonus.gd：输入 Party 的 team_systems() 结果，输出当前机制类型与效果：
   - 共振：全队 atk+10%（占位）
   - 汇流：全队 def+10%（占位）
   - 混元：全队 hp/max+8%、atk+5%（占位），且共振/汇流不出现
   - 三者皆不满足：无机制
2. 战斗开始时（BattleManager）调用判定并打印 [BONUS] 日志；效果在 DamageCalc 结算时生效。
3. MCP 冒烟：三种编组分别开战，日志显示对应机制；混元编组确认不出现共振/汇流字样。

产出：PartyBonus.gd。

验收（全部通过）：
- [ ] 三种编组分别触发共振/汇流/混元（日志可证）
- [ ] 混元时共振/汇流不触发（互斥）
- [ ] 加成实际作用于伤害结算（数值可复核）

提交：git commit -m "T3.5: 队伍机制判定" 并 push。
```

#### T3.6 战斗演出占位

```
任务：T3.6 战斗演出占位
目标：小技能切"半身立绘占位"，终结技播"专属动画占位"，演出可暂停战斗、可跳过。
前置：T3.4 已通过。

执行步骤：
1. SkillCutscene.tscn：全屏层（CanvasLayer）：PortraitRect（TextureRect，当前纯色块+角色名+技能名）+ CutsceneAnimation（AnimationPlayer，当前做色块缩放/变色/闪屏占位动画）+ 跳过提示。
2. SkillCutscene.gd：play(character_id, skill_id)；按 skill.type 分支：small → 立绘占位 0.8s；ult → 专属动画占位 2s + 大字"终结技：<技能名>"；空格跳过；播完发 finished 信号。
3. BattleManager 接入：执行指令时暂停回合推进 → 播演出 → 继续；立绘来源走 ArtProvider.get_portrait(id, emotion)（占位）。演出播放期间建议 pause_game("cutscene")（若 T2.3 PauseManager 已就绪则接入，否则留 TODO T4.3 统一接）。
4. MCP：运行战斗 → 触发小技能与终结技 → 截图演出画面 → 空格跳过 → 战斗继续。

产出：SkillCutscene.tscn、SkillCutscene.gd。

验收（全部通过）：
- [ ] 小技能/终结技演出分别触发且可结束
- [ ] 跳过可用，演出后战斗状态正确继续
- [ ] 演出画面含角色名与技能名，可作为占位证据

提交：git commit -m "T3.6: 战斗演出占位" 并 push。
```

#### T3.7 战斗场景接入与奖励

```
任务：T3.7 战斗场景接入与奖励
目标：实现战斗场景：从地图触发进入、三人 vs 灾蚀兽、胜利结算星砂、可复用于心契任务。
前置：T3.5、T3.6、T1.5 已通过。

执行步骤：
1. Battle.tscn：战斗舞台（色块地板）+ 敌我站位（我方三人左侧、敌方右侧，色块占位）+ BattleController.gd。
2. BattleController：监听 EventBus.battle_started(party_ids, enemy_ids, context) → 加载场景 → 驱动 BattleManager；胜利 → 星砂结算入 GameState.star_sand += drop_sand（Inventory 未就绪前暂记，T6.1 统一迁移 Inventory.add_sand，代码注释标注）→ 发 battle_finished(win)；失败 → 重试提示。
3. 地图接入：CampMap 放"战斗触发点"（或由心契任务步骤触发），触发 → battle_started（当前队伍 3 人 vs corrosion_beast）；context 参数支持传入 quest_id（供 T5.3 判定"共同战斗"步骤完成）。
4. 场景进入/退出改走 Transition 层（T2.3）：进入战斗=transition_scene(当前地图, battle 场景)；结算回地图同走 Transition；不再裸 change_scene。
5. MCP：从地图完整打一场（出手→演出→胜利→星砂到账→回地图），截图关键节点；失败流程测试一次不卡死。

产出：Battle.tscn、BattleController.gd。

验收（全部通过）：
- [ ] 地图进入战斗全流程可走通，Transition 进出正确
- [ ] context=quest_id 时可被 QuestRunner 识别（接口存在）
- [ ] 失败重试不卡死

提交：git commit -m "T3.7: 战斗场景接入与奖励" 并 push。
```

### P4 Dialogic 剧情演出

#### T4.1 Dialogic 2 集成与冒烟验证

```
任务：T4.1 Dialogic 2 集成与冒烟验证
目标：验证 Dialogic 2 在项目中可运行时播放对话：Character、Portrait（emotion 差分）、timeline 结束信号。
前置：T0.1 已通过（Dialogic 2 已启用）。涉及 Dialogic 的 API 与文本语法，以 addons/dialogic 文档与示例（docs.dialogic.pro）为准，不要臆造函数名。

执行步骤：
1. 在 Dialogic 插件中创建 1 个测试 Character（id=test_npc，display_name=测试NPC），配 2 个 Portrait：normal、happy（占位纯色 PNG，放 assets/portraits/test_npc_normal.png / happy.png，先由你用代码生成 64×128 纯色图）。
2. 手写第一个 timeline：dialogues/timelines/smoke_test.dtl，内容 3 句：第一句 normal、第二句 happy（切换表情）、第三句结尾；文本语法参考 Dialogic 官方 Timeline Text Syntax，务必能在 Dialogic 编辑器打开。
3. 在 Main 场景加运行时播放：脚本监听按键 1 → Dialogic.start("smoke_test")（函数签名以当前版本为准，可在 addons/dialogic 示例场景中确认）；监听 timeline 结束信号打印 [DIALOGIC] ended。
4. MCP：运行项目 → 按 1 → 截图对话窗（含角色名与立绘占位）→ 等结束确认日志；在 Dialogic 编辑器打开 smoke_test.dtl 无语法错误。

产出：smoke_test.dtl、测试 Character/Portrait、Main 播放脚本。

验收（全部通过）：
- [ ] 对话窗显示姓名/台词/立绘占位，表情切换生效（截图可证）
- [ ] timeline 播放结束触发信号且日志输出
- [ ] Dialogic 编辑器打开 .dtl 无报错

提交：git commit -m "T4.1: Dialogic集成与冒烟验证" 并 push。
```

#### T4.2 CSV台词表 → Dialogic timeline 转换管线

```
任务：T4.2 CSV台词表 → Dialogic timeline 转换管线
目标：实现从台词 CSV 生成 Dialogic .dtl 的转换工具（幂等可重跑），并实现 Dialogic 信号 → EventBus → GameState 的 flag 桥接。
前置：T4.1 已通过。文本语法以 Dialogic 官方 Timeline Text Syntax 为准，由转换工具统一产出，不在别处手写语法。

执行步骤：
1. 台词 CSV 列规范：timeline_id, order, speaker_id, emotion, text, set_flag, flag_condition, choice_a, choice_b。规则：order 决定行序；flag_condition 非空时该行仅在 GameState 满足该 flag 才显示（转换工具生成条件事件）；set_flag 非空时该行播放后写 GameState（生成 Dialogic 信号事件）；choice_a/choice_b 生成简单选项跳转（可选，MVP 主线可不填）。
2. tools/csv_to_dialogic.gd（EditorScript，在编辑器内运行）：扫描 data/csv/dialogues_*.csv → 生成 dialogues/timelines/<timeline_id>.dtl；幂等（重复运行结果一致）；打印转换统计（timeline 数/行数）；语法错误集中在此工具内按官方语法校验。
3. 桥接脚本 scripts/dialogue/DialogicBridge.gd（Autoload）：监听 Dialogic 的自定义信号事件（signal_event）→ 调用 EventBus.dialogue_signal_bridge(event_name, data) → GameState 写 flag；监听 timeline 结束 → EventBus.dialogue_finished。函数签名以当前 Dialogic 版本为准。
4. 验证：把 T4.1 的 smoke_test 改为由 CSV（dialogues_smoke.csv）生成 .dtl，重跑工具 → 删除手写文件 → 播放确认内容一致；修改 CSV 台词 → 重跑 → 播放内容变化。

产出：csv_to_dialogic.gd、DialogicBridge.gd、dialogues_smoke.csv。

验收（全部通过）：
- [ ] CSV 改词 → 重跑 → 播放内容同步（可证）
- [ ] set_flag 行播放后 GameState 对应 flag=true（日志）
- [ ] flag_condition 不满足时该行被跳过
- [ ] 工具幂等：连续跑两次输出 diff 为空

提交：git commit -m "T4.2: CSV转Dialogic转换管线" 并 push。
```

#### T4.3 主线剧情 1 段（邂逅 3 名觉醒者）

```
任务：T4.3 主线剧情 1 段（邂逅 3 名觉醒者）
目标：用 CSV + Dialogic 实现主线第一段：异乡人穿越开场 → 营地 → 依次邂逅 3 名觉醒者 → 目标提示；地图触发区进入；flag 防重播；对话期间暂停世界；主线完成后自动存档。
前置：T4.2、T1.6 已通过。

执行步骤：
1. 在 Dialogic 中为 3 名觉醒者建 Character（id 与 CSV 角色 id 一致），各配 emotion 占位 Portrait（normal/happy/sad/angry 纯色图，路径 §5.2 规范）；三名觉醒者 Character 的 display_name 读 CSV 正式命名（诺菈·星枢/艾蕾雅/洛清弦），与 T2.7 名牌一致。
2. 编写 data/csv/dialogues_main_01.csv：
   - 开场：无角色旁白 3 句（异乡人穿越、落地营地）
   - 依次邂逅 3 人：每人 5~8 句，穿插 emotion 切换（如初见 normal → 惊讶 happy/sad），最后一句 set_flag=met_awakened_mech_01（三人依次 met_<id>）
   - 结尾旁白 2 句目标提示，set_flag=main_01_done
3. 跑 csv_to_dialogic 生成 main_01.dtl；Dialogic 编辑器打开确认。
4. 触发：CampMap 主线触发区 → Dialogic.start("main_01")；开场前 pause_game("dialogue") 暂停世界（暂停地图层输入与敌意计时）；播放期间玩家移动输入锁定；timeline_ended 后 resume_game("dialogue") 恢复。
5. 防重播：GameState 检查 main_01_done，已完则触发区不再播放（改为提示文字）。
6. 自动存档挂钩：main_01_done 落库后调 save_game("auto", is_auto=true)（自动档触发点=任务关闭）。
7. MCP：走到触发区 → 完整播放 → 截图邂逅画面 → 确认 met_* 与 main_01_done flag 落库 → 重进触发区不再播放。

产出：dialogues_main_01.csv、main_01.dtl、触发脚本。

验收（全部通过）：
- [ ] 三场邂逅对话完整播放，姓名/阵营/台词/立绘正确（截图）
- [ ] 3 个 met_<id> 与 main_01_done flag 全部写入
- [ ] 重走触发区不重播
- [ ] 剧情播放期间玩家输入被正确锁定/恢复
- [ ] main_01_done 后自动存档触发

提交：git commit -m "T4.3: 主线剧情一段" 并 push。
```

#### T4.4 NPC闲聊与日常接口占位

```
任务：T4.4 NPC闲聊与日常接口占位
目标：营地 NPC 可闲聊对话（主线前后内容不同），预留"时间/章节/天气触发日常事件"接口（MVP 不启用）。
前置：T4.3 已通过。

执行步骤：
1. dialogues_npc_chat.csv：2~3 名 NPC（占位 id，如 guard_01 / merchant_01）各 2~3 句闲聊；同一 NPC 用 flag_condition 分支：main_01_done 前后台词不同。
2. 转换生成 npc_chat.dtl；NPC 交互（T1.5 Interactable）→ 按 npc_id 播放对应 timeline；主线 NPC 在 main_01_done 后变为"固定角色"（触发心契入口，T5.3 接）。
3. EventScheduler.gd（Autoload 占位）：接口 schedule_daily_event(time, chapter, weather) -> String（返回事件 id），MVP 内只返回空并注释说明未来接入，不实现调度逻辑。
4. MCP：主线前与主线后分别与同一 NPC 对话，确认内容分支正确（截图/日志）。

产出：dialogues_npc_chat.csv、EventScheduler.gd（占位）。

验收（全部通过）：
- [ ] 2 名以上 NPC 可对话
- [ ] flag 分支生效：主线前后内容不同
- [ ] EventScheduler 占位接口存在且不报错

提交：git commit -m "T4.4: NPC闲聊与日常接口" 并 push。
```

### P5 心契任务

#### T5.1 心契状态机

```
任务：T5.1 心契状态机
目标：实现 HeartBond：unknown → known（邂逅）→ bonding（心契开启）→ bonded（满阶可招募）；提供查询接口。
前置：T4.3 已通过（met_<id> flag 已写入）。

执行步骤：
1. HeartBond.gd（Autoload）：每角色状态存储 state: Dictionary（id -> state）；状态枚举 unknown/known/bonding/bonded。
2. 初始化/同步：get_state(id) 时若 GameState 有 met_<id> 且状态为 unknown → 自动置 known；start_quest(id) → bonding；complete(id) → bonded，发 EventBus.quest_updated。
3. can_recruit(id) -> bool：仅 bonded 返回 true（招募硬前置，防止跳过剧情）。
4. MCP 冒烟：模拟 three 角色依次 known → 一个 bonding → bonded；can_recruit 在 bonded 前恒 false。

产出：HeartBond.gd（Autoload）。

验收（全部通过）：
- [ ] 状态按路径流转正确，met flag 自动同步 known
- [ ] can_recruit 在 bonded 前恒 false
- [ ] 状态变更触发 quest_updated 信号

提交：git commit -m "T5.1: 心契状态机" 并 push。
```

#### T5.2 同行机制

```
任务：T5.2 同行机制
目标：心契任务开启时目标角色以"同行"状态临时占编队槽，可参与战斗；任务完成/中断离队。
前置：T5.1、T2.2、T3.7 已通过。

认知说明：地图上仅主角渲染移动（架构 §1.3），同行角色不生成地图实体、无跟随者、无头顶标签——同行只体现为 Party 数据槽位与战斗出战。

执行步骤：
1. CompanionManager.gd：on_quest_start(quest_id, character_id) → Party.set_companion(character_id)（触发 party_changed）；on_quest_complete/on_quest_abort → clear_companion。
2. 出战：战斗入口读 Party.get_members()（含同行），T3.7 无需改动，验证即可。
3. 槽位交互：编队满员（3/3）时开启同行任务的处理按 T2.2 规则执行（不崩溃，规则以系统策划01 队伍规则文档为准）。
4. MCP 冒烟：开启心契任务→同行入队（party_changed 日志）→进战斗同行在队可行动→任务完成→同行清除。

验收（全部通过）：
- [ ] 同行入队/清除正确，party_changed 信号可证
- [ ] 战斗中同行可出战（日志）
- [ ] 满员场景不崩溃
- [ ] 全程无地图实体生成（角色列表/编队 UI 数据正确）

提交：git commit -m "T5.2: 同行机制" 并 push。
```

#### T5.3 心契任务 1 个（quests.csv 驱动）+ NPC 任务标记

```
任务：T5.3 心契任务 1 个（quests.csv 驱动）+ NPC 任务标记
目标：实现 QuestRunner 与 heartbond_01 任务线（建议选秘法系 awakened_arcane_01）：开启对话 → 赠礼 → 共同战斗 → 完成对话 → 满阶；NPC 头顶粉 ？/！ 标记。
前置：T5.2、T3.7、T1.6 已通过。

执行步骤：
1. quests.csv 补全 heartbond_01 四步（列：quest_id,step,step_name,requirement,target,reward,next_step）：
   - step1 开启对话：requirement=met_awakened_arcane_01；target=与 NPC 对话（触发其心契 timeline）
   - step2 赠礼：requirement=背包有 star_sand_crystal（T1.6 拾取物，Inventory.has_item 或旧 flag inv_star_sand_crystal 两通道都判）；target=赠礼对话，reward=消耗道具
   - step3 共同战斗：requirement=无；target=触发 battle_started（context=heartbond_01）并胜利
   - step4 完成对话：requirement=step3 完成；target=结尾对话，reward=心契满阶
2. 为秘法角色写心契对话 CSV（dialogues_heartbond_01.csv）：开场/赠礼/结尾三段，set_flag 驱动步骤（如 hb01_step2_done）。
3. QuestRunner.gd：get_current_step(quest_id) / advance(quest_id, event) / is_complete；监听 EventBus（dialogue_finished、battle_finished、inventory 变化）自动推进；步骤未满足时 NPC 给出引导台词（不同 flag 分支）。
4. NPC 头顶任务标记：该 NPC 有关联任务时显示标记——待接取=问号 ？、已接取待交互=感叹号 ！；心契任务用粉红 #FF8FC8；位置在名牌上方、轻微上下浮动；渲染沿 T1.5 提示规则（不参与 Y-sort、z_index=100、逐 NPC 独立显隐）；同一 NPC 多任务按 主线>心契>支线 取最高优先级一个（MVP 仅心契，逻辑预留）。实现挂 Interactable（新增 mark 状态接口），由 QuestRunner 步骤变化驱动刷新。
5. 完成 step4 → HeartBond.complete(id) → bonded；发 quest_updated； bonded 后自动 save_game("auto", is_auto=true)（自动档触发点=任务关闭）。
6. MCP 全流程：邂逅 → 领任务 → 拾取结晶 → 赠礼 → 共同战斗 → 结尾 → 状态 bonded，每步日志/截图；头顶 ！ 标记正确显示。

产出：quests.csv、QuestRunner.gd、dialogues_heartbond_01.csv。

验收（全部通过）：
- [ ] 四步严格按序推进，无法跳步（未满足条件时引导正确）
- [ ] 完成后 HeartBond=bonded，can_recruit=true
- [ ] 赠礼正确消耗道具；共同战斗胜利计入步骤
- [ ] NPC 头顶粉 ？/！ 标记随任务状态正确切换
- [ ] 任务完成后自动存档触发

提交：git commit -m "T5.3: 心契任务一条+NPC任务标记" 并 push。
```

#### T5.4 任务面板数据接入

| 字段 | 内容 |
| --- | --- |
| 目标 | 任务面板接入真实任务数据 + HUD 追踪联动 |
| 产出 | QuestPanel 数据填充、HUD 任务追踪 |
| 依赖 | T5.3、T2.5（面板壳已建） |
| 主责 | 系统策划○（需求）、系统程序◎ |
| 预估 | 1 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T5.4 任务面板数据接入
目标：T2.5 建好的任务面板（J）填充真实任务数据，三色分组生效，HUD 追踪联动。
前置：T5.3、T2.5 已通过。

执行步骤：
1. 任务面板（J 键）：数据源改 QuestRunner 实时状态；按主线/支线/心契分组（组头三色 #FFA640/#6FC9FF/#FF8FC8，与 NPC 头顶标记同色系）；条目=任务名+步骤名+目标进度+指引描述。
2. HUD 左上任务追踪 1 条：显示当前追踪任务（默认=最新接取的心契任务）任务名+当前步骤；quest_updated 实时刷新。
3. 监听 quest_updated 全量刷新；无任务空态「暂无任务」。
4. MCP：推进心契任务各步骤，截图面板与 HUD 追踪同步更新；步骤完成前面板与头顶 ！ 标记一致。

验收（全部通过）：
- [ ] J 开合、三色分组正确（截图）
- [ ] 步骤推进面板+HUD 同步（截图×2）
- [ ] 空态正确；与 NPC 头顶标记状态一致

提交：git commit -m "T5.4: 任务面板数据接入" 并 push。
```

### P6 唤星模拟

#### T6.1 资源与背包系统

```
任务：T6.1 资源与背包系统
目标：Inventory 单例：道具/星髓持有/CG 图鉴；货币保留在 GameState；各获取途径接通。
前置：T0.4、T3.7、T5.3 已通过。

执行步骤：
1. Inventory.gd（Autoload）：items: Dictionary（道具 id→数量，含 star_sand_crystal）、starmarrow: Dictionary（星髓持有 id→{count, lv}）、cg_collection: Array[String]。
2. API：货币接口对 GameState 的包装（add_sand/spend_sand/add_token/spend_token 引导业务调 GameState）；add_item/has_item/remove_item/unlock_cg/has_cg/add_stellium/has_stellium 管道具、星髓、CG。
3. T1.6 拾取迁移（A3）：CampMap 星砂结晶拾取从 GameState.set_flag("inv_star_sand_crystal",1) 迁移为 Inventory.add_item("star_sand_crystal",1)（节点 queue_free 保留；旧 flag 保留兼容读取一次后废弃）。
4. T3.7 胜利星砂迁移：GameState 直记处改 Inventory.add_sand 包装（若 T3.7 用了暂记方案）。
5. 途径接通：T3.7 胜利奖励 → add_sand；T4.3 主线完成奖励 → add_sand；T5.3 任务奖励/赠礼消耗 → add_item/remove_item；T1.6 拾取 → add_item。
6. 背包面板（T2.5 的 B）接真数据：分类 Tab 道具/材料/星髓/任务品（星髓 Tab 列 starmarrow 持有）。
7. MCP 冒烟：各途径触发后数值正确；spend 不足返回 false 且不为负。

产出：Inventory.gd（Autoload）。

验收（全部通过）：
- [ ] 货币在 GameState，Inventory 管道具/星髓/CG
- [ ] 各获取途径后数值正确（日志）
- [ ] 消耗不足不产生负数
- [ ] CG 解锁/查询正确
- [ ] 背包面板接真数据后显示正确

提交：git commit -m "T6.1: 资源与背包系统" 并 push。
```

#### T6.2 唤星抽卡逻辑

| 字段 | 内容 |
| --- | --- |
| 目标 | 通用池概率可配置、保底生效、可验证 |
| 产出 | `scripts/star_summon/SummonManager.gd` |
| 依赖 | T6.1 |
| 主责 | 数值策划◎（权重/保底数值）、系统程序◎（实现） |
| 预估 | 1~2 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T6.2 唤星抽卡逻辑
目标：SummonManager：按 summon_pool.csv 权重随机抽取，单抽消耗 100 星砂，保底计数生效，结果入包。
前置：T6.1 已通过。

经济闭环（架构 §2.8）：星砂→唤星消耗（单抽 100）；星缘令为唤星产出→用于角色入队解锁。无十连（UI 无十连按钮；draw_n(n) 仅保留供模拟验证）。

执行步骤：
1. summon_pool.csv 权重复核：出金条目（kind=starlink_token/cg）gold=true，出金总权重约 5%（数值策划可调）；星髓条目按 T2.8 新结构入包。
2. SummonManager.gd：single_draw()->SummonEntryData：按权重随机 1 条；消耗 GameState 星砂 100（常量 SINGLE_COST=100）；保底 pity_counter：每抽 +1，达 60（常量 PITY_MAX=60，待数值策划确认可调）未出金则本次必出金并清零；出金即清零；结果写入 Inventory（星缘令/材料/星髓/CG→unlock_cg）；发 EventBus.summon_completed(result)。
3. draw_n(n) 保留（仅模拟用）；pity_counter 需可被存档（SaveManager 存档清单已预留字段）。
4. MCP 冒烟：1000 次模拟输出各 kind 占比与权重比对（±2% 容差）；保底验证：构造 pity_counter=59 再抽必出金；星砂扣减=100×次数；不足时拒绝并返回原因。

验收（全部通过）：
- [ ] 1000 次模拟占比与权重一致（±2%）
- [ ] 保底第 60 抽必出金且计数清零（日志可证）
- [ ] 单抽固定扣 100；星砂不足拒绝
- [ ] 结果入包与信号一致

提交：git commit -m "T6.2: 唤星抽卡逻辑" 并 push。
```

#### T6.3 招募解锁逻辑

```
任务：T6.3 招募解锁逻辑
目标：招募界面：校验"持有星缘令 + HeartBond=bonded"，满足则入队，不满足给出缺项提示；未邂逅角色显示"？？？"。
前置：T6.2、T5.1 已通过。

执行步骤：
1. RecruitManager.gd：try_recruit(character_id) -> {ok, reason}：依次校验 ① 已邂逅（无 met flag → "？？？"）② HeartBond.can_recruit（否则提示"需先完成心契任务"）③ 持有星缘令（否则提示"缺少星缘令，可前往唤星"）；通过 → Party.add_member + Inventory.spend_token + EventBus.character_recruited。
2. 星缘令简化为通用令牌即可。
3. RecruitUI.tscn：角色列表（占位色块+名字/？？？）+ 状态标签（已邂逅/心契中/可招募）+ 招募按钮 + 结果提示；入口：营地"招募台"交互或菜单键。
4. MCP 测试三分支：未邂逅 → 拒绝显示？？？；已邂逅未满阶 → 拒绝提示心契；满阶+持令 → 招募成功入队（Party 日志）。

产出：RecruitManager.gd、RecruitUI.tscn。

验收（全部通过）：
- [ ] 三种前置分支拒绝/成功行为正确，提示明确
- [ ] 招募成功后角色入队、令牌消耗、信号发出
- [ ] 防止跳过剧情（未满阶恒拒绝）

提交：git commit -m "T6.3: 招募解锁逻辑" 并 push。
```

#### T6.4 抽卡演出与图鉴占位

```
任务：T6.4 抽卡演出与图鉴占位
目标：抽卡演出（色块转场+出金反馈）与 CG 图鉴（收藏/查看占位）。
前置：T6.2 已通过。

执行步骤：
1. SummonScene.tscn：色块转场（1s）→ 揭示结果：出金（kind=starlink_token/cg）→ 金色闪屏 + 大字"星缘令 / 角色CG"；普通 → 普通反馈（道具名）；连续抽取支持连点；星砂不足禁用按钮并提示。演出期间接 pause_game("cutscene")（若 PauseManager 已就绪）。
2. CgGallery.tscn：已解锁 CG 列表（色块 + 标题占位，数据来自 Inventory.cg_collection）；未解锁显示锁图标占位；点击已解锁项 → 全屏查看占位大图（预留 ArtProvider.get_cg(id) 接口）。
3. 入口：唤星台/招募界面按钮互跳。
4. MCP：抽卡（含一次出金）→ 截图演出 → 图鉴出现新 CG → 查看占位图。

产出：SummonScene.tscn、CgGallery.tscn。

验收（全部通过）：
- [ ] 抽卡流程完整，出金/普通反馈可区分（截图）
- [ ] 图鉴只显示已解锁 CG，查看占位可打开
- [ ] 星砂不足时正确禁用

提交：git commit -m "T6.4: 抽卡演出与图鉴" 并 push。
```

#### T6.5 星髓装备与养成

| 字段 | 内容 |
| --- | --- |
| 目标 | 架构 §2.5 + §3.1 星髓面板三区落地（装备 6 槽/筛选/养成骨架） |
| 产出 | 星髓装备逻辑 + 属性并入 + 养成骨架 |
| 依赖 | T2.8（数据）、T2.5（面板壳）、T6.1（持有数据） |
| 主责 | 系统程序◎、数值策划○（养成数值与效果数值） |
| 预估 | 2 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T6.5 星髓装备与养成
目标：角色详情星髓面板（页2）从骨架变可用：装备/卸下、筛选、属性并入、养成骨架。
前置：T2.8、T2.5、T6.1 已通过。

规格（架构 §2.5）：每角色固定 6 槽（2×3）；星髓与体系无关；2 件套组件提供数值属性（main_stat/sub_stats），3 件套组件提供效果属性（set_3_bonus）；同 set_id 集齐件数触发对应档效果。

执行步骤：
1. EventBus 注册 starmarrow_changed(character_id, before, after)；装备/卸下后发射（before/after=该角色已装备星髓 id 数组快照）。
2. 装备规则：每槽 1 件；同 1 件星髓不可同时装在多名角色（持有唯一性）；装备/卸下写 Inventory.starmarrow 状态（equipped_by 字段）。
3. 套装判定：按当前角色 6 槽内 set_id 计件——某 set 集齐 2 件 2 件套组件→并入其 set_2_bonus 数值属性；集齐 3 件 3 件套组件→激活 set_3_bonus 效果（MVP 效果以属性面板标注+战斗 DamageCalc 可读取的加成钩子形式落地；战斗消费在 T3.4 接口上加挂，若无合适钩子则本卡输出 get_stellium_bonus(character_id)->Dictionary 供战斗侧调用，战斗接入留 T7.1 回归验证）。
4. 角色详情页 1 的四维显示=基础值+星髓加成（加成来源标注）。
5. 持有列表筛选：稀有度/等级/套装（无体系维度）。
6. 养成区骨架：升级（lv+1，消耗星砂占位 100/级，属性成长公式占位线性）与突破（lv 上限提升占位）；数值策划后续可只改数值不改逻辑；养成结果入档（CharacterData 养成数据）。
7. 存档：装备状态与养成 lv 纳入 SaveManager 清单（CharacterData 已获角色字段）。
8. MCP 验证。

验收（全部通过）：
- [ ] 装备/卸下 6 槽正确，唯一性约束生效（同件不可双穿）
- [ ] 2 件套数值并入四维显示（前后对比截图）
- [ ] 3 件套效果激活标注；get_stellium_bonus 返回正确
- [ ] starmarrow_changed 信号可证；筛选三维度可用
- [ ] 升级/突破占位流程可走；存档→读档后装备与 lv 恢复

提交：git commit -m "T6.5: 星髓装备与养成" 并 push。
```

### P7 整合与验收

#### T7.1 全流程串联

```
任务：T7.1 全流程串联
目标：Main 接管 main_scene，单次游玩走通 MVP 闭环；保证资源数值必然可通。
前置：P0~P6 全部验收通过。

执行步骤：
1. Main 接管 main_scene：标题/新游戏（含主角命名）→ CampMap → 各系统按依赖链触发 → 通关结算占位。
2. 全流程检查点扩充：神像点亮与恢复、世界大地图区块解锁与传送、箱庭图标注、HUD 四区、面板开合与 Esc 层级、暂停/恢复、星髓装备属性并入。
3. 数值平衡表（docs/数值平衡表.md）增加：星砂总收入 ≥ 单抽100×2 + 保底余量分析（pity 60 抽口径）；首亮奖励 100 计入来源。
4. 自动存档触发点回归：进场景/任务关闭/点亮神像 三处逐一验证。
5. 终战：招募后三系编队→混元（T3.5）→灾蚀兽（可调强）→通关；星髓加成在终战伤害日志可证（T6.5 的 get_stellium_bonus 消费验证）。
6. MCP 完整回归：从新游戏到通关全程录像式走查（关键节点截图），日志记录各关键事件（邂逅/心契/抽卡/招募/混元/通关）。

产出：Main 串联场景、docs/数值平衡表.md。

验收（全部通过）：
- [ ] 单次游玩从头到尾无阻塞走通（回归日志）
- [ ] 数值平衡表显示星砂总收入 ≥ 单抽100×2 + 保底余量
- [ ] 混元机制在终战生效（日志 [BONUS]）
- [ ] 自动存档三处触发点逐一验证通过
- [ ] 通关界面出现且可返回

提交：git commit -m "T7.1: 全流程串联" 并 push。
```

#### T7.2 存档回归与全量回归测试

| 字段 | 内容 |
| --- | --- |
| 目标 | 存档系统已在 T2.4 交付，本卡做全档位回归 + 全系统回归 |
| 产出 | 回归记录（交接班表） |
| 依赖 | T7.1 |
| 主责 | 系统程序◎ |
| 预估 | 1~2 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T7.2 存档回归与全量回归测试
目标：验证 T2.4 存档管线在全部系统就绪后的完整性，并做一次全系统回归。
前置：T7.1 已通过。

执行步骤：
1. 存档内容逐项回归（对照架构 §4.2 清单）：GameState flags/货币、Party、HeartBond、Inventory（道具/星髓/CG）、任务进度、神像 lit_shrines、地图 unlocked_regions、pity_counter、角色养成（星髓装备/lv）、主角命名——存档→重启→读档逐项断言（日志+截图）。
2. 槽位行为：自动档独立于手动档；手动覆盖式 1 槽；构造坏档→rollback_auto 回退成功不崩溃；version 字段存在。
3. 全系统回归：沿 T7.1 串联流程完整走一遍（新档→通关），记录各系统异常清单并当场修复小问题（大问题登记交接班表升级处理）。
4. 输出回归记录行到系统程序交接班表。

验收（全部通过）：
- [ ] 存档清单逐项恢复正确（对照表）
- [ ] 坏档回滚可用
- [ ] 全流程回归无 P0/P1 级问题

提交：git commit -m "T7.2: 存档回归与全量回归" 并 push。
```

#### T7.3 美术接口审计与 AI 资源接入演练

```
任务：T7.3 美术接口审计与 AI 资源接入演练
目标：审计全部视觉出口都走 ArtProvider；用 AI 生成的 1 张角色图 + 1 段音乐按规范接入替换占位，验证业务零改动。
前置：T7.1 已通过。

执行步骤：
1. 审计：全项目搜索直接引用资源路径/内联色块作为"外观"的地方（角色、立绘、tile、CG、演出、UI 图标），补齐走 ArtProvider；生成 docs/美术资源接入清单.md：接口表（接口/当前占位/真实资源路径规则/替换步骤）。
2. AI 资源演练（立绘）：用 AI 工具生成 1 张觉醒者立绘（透明底 PNG，二次元 Q 版风格，竖版 3:4）→ 命名 assets/portraits/awakened_mech_01_normal.png → ArtProvider.get_portrait 返回真实贴图；确认对话中该角色立绘替换成功且业务代码零改动。
3. AI 资源演练（音乐）：用 AI 工具生成 1 段 30~60s BGM → 转 OGG → assets/audio/bgm_camp.ogg → 在营地场景 AudioStreamPlayer 播放；确认音量/循环正常。
4. AI 资源演练（8 向帧条）：用 AI 生成 1 套 8 向占位帧条之一的方向（如 walk 南下 6 帧）替换色块帧，验证 ArtProvider.get_character_sprite 接口零改动替换即可生效。
5. 回归：替换后跑全流程一次，确认无报错、无视觉缺失。

产出：docs/美术资源接入清单.md、替换实例。

验收（全部通过）：
- [ ] 审计清单覆盖全部视觉出口，无漏网
- [ ] 立绘替换后对话显示真实图片，业务代码零改动（git diff 仅资源文件）
- [ ] BGM 播放正常
- [ ] 8 向帧条替换零改动生效
- [ ] 替换后全流程回归通过

提交：git commit -m "T7.3: 美术接口审计与AI资源接入" 并 push。
```

#### T7.4 MVP 总验收

```
任务：T7.4 MVP 总验收
目标：逐项核验 MVP 十项交付物与架构文档一致性，输出验收报告，修复至 0 已知缺陷。
前置：T7.3 已通过。

执行步骤：
1. 按 §1 十项逐项实机走查（MCP 运行 + 截图 + 日志），记录结果与证据。
2. 设定一致性核对（对照架构文档与《汇界星痕》初期设定.md）：
   ① 混元互斥（三系齐不触发共振/汇流）；
   ② 招募三步前置（邂逅+心契满阶+星缘令）；
   ③ 唤星通用池无内购、单抽 100、保底 60 生效、无十连；
   ④ 星髓：6 槽、体系无关、2 件套数值/3 件套效果；
   ⑤ 心契同行：编队可出战、地图无跟随实体；
   ⑥ 架构 §1~§3 规格抽验：描边白、HUD 四区、Esc 层级、滚轮双向地图、神像四行为、面板暂停世界；
   ⑦ MVP 后项（CG 全量/成就/完整音频/自定义键位）标注 📌 MVP+。
3. 输出 docs/MVP验收报告.md：十项结论、设定核对表、已知缺陷与影响、下一步建议（星髓系统、更多章节、AI 资源批量接入）。
4. 最终提交并 push；确认 GitHub 私有仓库与本地一致。

产出：docs/MVP验收报告.md。

验收（全部通过）：
- [ ] 十项交付物全部达标（报告含证据）
- [ ] 设定核对表完成，未实现项明确标注"占位/待实现"
- [ ] 已知缺陷全部记录且无 P0 级
- [ ] 仓库最终 push 完成

提交：git commit -m "T7.4: MVP总验收" 并 push。
```

***

## 5. 美术资源接口规范

### 5.1 唯一资源入口 ArtProvider

| 接口 | 用途 | 当前占位实现 | 后期替换（AI 资源） |
| --- | --- | --- | --- |
| `get_character_sprite(id)` | 地图角色外观 | 色块 + 名字 | `assets/sprites/characters/<char_id>_<idle|walk>_<dir>.png` 8 方向帧条（dir ∈ n/ne/e/se/s/sw/w/nw） |
| `get_portrait(id, emotion)` | 对话/战斗立绘 | 色块 + 情绪文字 | `assets/portraits/<id>_<emotion>.png`（AI 生成立绘，竖版 3:4） |
| `get_tile_texture(map_id, layer)` | 等距砖块 | 纯色菱形 | `assets/maps/tilesets/<map_id>.tres` |
| `get_cg(id)` | 星痕绘卷 CG | 色块 + 标题 | `assets/cg/<chapter>_<node>.png` |
| `get_skill_fx(skill_id)` | 战斗特效 | 色块动画 | `assets/skills/<skill_id>_fx.*` |
| `get_ui_icon(id)` | UI 图标 | 纯色方块 | `assets/ui/icons/<id>.png` |
| `get_bgm(scene_id)` / `get_sfx(event_id)` | 音频 | 静音占位 | `assets/audio/bgm_<scene>.ogg` / `sfx_<event>.ogg` |

### 5.2 资源目录与命名规范

```
assets/
├── maps/tilesets/        map_<地图id>.tres
├── sprites/characters/   <char_id>_<idle|walk|skill>_<dir>.png  （dir ∈ n/ne/e/se/s/sw/w/nw）
├── portraits/            <char_id>_<normal|happy|sad|angry>.png
├── cg/                   <chapter>_<node>.png   （如 main_01_opening.png）
├── skills/               <skill_id>_cutscene.*
├── ui/icons/             <icon_id>.png
└── audio/                bgm_<scene>.ogg  /  sfx_<event>.ogg
```

### 5.3 数据扩展点（向后兼容）

- CSV 后续可加列：`live2d_config`（动态立绘）、`model_path`（3D 模型）、`voice_path`（语音）——旧行缺列解析器取默认值，不破坏加载。
- 台词 CSV 新增章节 = 新建 `dialogues_<章>.csv` + 重跑转换工具，不改代码。
- 抽卡池只改 `summon_pool.csv` 权重即可调概率。

### 5.4 场景节点规范

- 占位视觉统一挂在 `VisualRoot → Sprite / Portrait / Cutscene` 下；替换资源只改 VisualRoot 内部，不动移动/战斗/对话逻辑节点。
- 战斗演出预留 `SkillCutscene` 两个插槽：`PortraitRect`（小技能半身立绘）、`CutsceneAnimation`（终结技专属动画）。
- Dialogic 立绘占位 = Character Portrait，替换时在 Dialogic 内换资源即可，timeline 与 CSV 不动。

### 5.5 补充规范

- **8 向帧条**：屏幕空间 8 方向（斜向独立资源非左右翻转）、idle 4 帧（~3s）、walk 6~8 帧（~0.6s）；命名 `<char_id>_<idle|walk>_<dir>.png`（dir ∈ n/ne/e/se/s/sw/w/nw）。
- **立绘规格**：竖版 3:4、高清、背景柔化；角色详情与主页菜单背景共用。
- **神像视觉**：光柱（竖向渐变色块）+ 粒子（CPUParticles2D 占位）+ 光环 96px 圈（半透明描边圆）。
- **遮挡描边**：纯白 1.5~2px 外描边，CanvasItem.material，触发条件=前景元素 origin 全局 y > 角色脚部 y 且投影重叠；随遮挡面积淡入淡出。
- **AI 资源接入规范**：AI 生成（即梦/豆包/SD 等）→ 统一风格词（等距 2.5D、Q 版三头身、二次元、统一主光源）→ 导出透明底 PNG → 按 §5.2 命名 → 对应 assets/ 目录 → ArtProvider 加载替换，业务代码零改动。AI 工具与风格词记录在 `docs/美术资源接入清单.md`。
- **音乐**：AI 生成（Suno 等）→ assets/audio/：BGM `bgm_<scene>.ogg`（44.1kHz/16bit，建议 60~120s 循环段），音效 `sfx_<event>.ogg`（1~3s）。
- **合规**：使用自有生成资源，规避版权风险。

***

## 6. 排期建议（波次）

| 波次 | 内容 | 卡 | 状态 |
| --- | --- | --- | --- |
| 1 | P0 骨架 | T0.1~T0.4 | ✅ 完成 |
| 2 | P1 地图 ∥ P2 | T1.1~T1.6 ✅；T2.1 ✅；**T2.2 进行中**；T2.3→T2.4→T2.5 串行（系统程序）；T2.6（美术）/T2.7/T2.8（数值）插空并行；T3.1 可提前 | 进行中 |
| 3 | P3 战斗 ∥ P4 剧情 | T3.2~T3.7 ∥ T4.1~T4.4 | 待启动 |
| 4 | P5 心契 | T5.1→T5.2→T5.3→T5.4 | 待启动 |
| 5 | P6 唤星 | T6.1→T6.2→T6.3/T6.4∥T6.5 | 待启动 |
| 6 | P7 整合验收 | T7.1→T7.2∥T7.3→T7.4 | 待启动 |

- 关键路径：P2 框架（T2.3~T2.5）→ P4 → P5 → P6 → P7。
- 风险点：① Dialogic 2 API 差异（语法收敛在转换工具）；② T2.3 体量大（四步交付，步间可验收）；③ 星髓战斗加成钩子（T6.5 与 T3.4 的衔接，必要时 T7.1 统一回归）；④ 保底数值 60 抽待数值策划01 复核。

***

## 7. MVP 总验收清单（最终勾验）

- [ ] **等距 2.5D 地图**：可漫游、遮挡正确+白描边、NPC 交互提示、相机跟随不越界
- [ ] **3 名觉醒者**：三体系各一，CSV 数据/地图占位（正式名名牌）/Dialogic 立绘占位可用
- [ ] **主线 1 段**：触发区→Dialogic 演出（暂停世界）→邂逅 3 人→flag 落库→不重播
- [ ] **心契任务 1 个**：开启→同行（无地图实体）→赠礼→共同战斗→满阶；NPC 头顶粉 ？/！ 标记
- [ ] **三人回合制战斗**：三指令、伤害结算、混元机制、演出占位、星砂奖励、Transition 进出
- [ ] **唤星模拟**：单抽 100+保底 60→星缘令→（心契满阶）招募；未满阶正确拒绝；无十连
- [ ] **视觉框架**：8 向接口、描边、Transition、M 箱庭图、世界大地图区块解锁、HUD 四区
- [ ] **神像与存档**：恢复/点亮/传送/存档四行为；自动+手动双槽+回滚；坏档不崩溃
- [ ] **UI 面板**：B/C/G/J/M/Esc 体系、主页菜单暂停、角色详情分页、任务三色、设置三档、主角命名
- [ ] **星髓体系**：6 槽装备、套装判定、属性并入、养成骨架、存档恢复
- [ ] **接口预留**：ArtProvider 全覆盖，AI 资源替换演练通过（T7.3）
- [ ] **设定一致性**：与《初期设定》+架构文档对照无误（架构文档全部规格复核）
