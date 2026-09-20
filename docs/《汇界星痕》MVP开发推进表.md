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
| 5 | 三人回合制战斗 ×1 | 三人小队 vs 灾蚀兽，混元机制可触发，友方技能（治疗/护盾/增伤）生效，战斗演出占位，走 Transition 层 |
| 6 | 唤星模拟 ×1 | 星砂单抽 100 / 十连 1000 + 保底（pity_counter）→星缘令→（心契满阶后）招募入队闭环；全屏唤星界面（右上星砂数量/主体角色展示图/右下单抽+十连按钮）+抽卡动画（十连竖排结果/星缘令特殊动画/CG 播放一次） |
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
- **数值口径**：power=倍率制（float）；战斗为大招充能制（无耗能字段，见 docs/系统规则/战斗系统.md §3，skills.csv 的 energy_cost 列由 T2.8 移除）；三觉醒者已命名（诺菈·星枢/艾蕾雅/洛清弦）。

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

- **CharacterData**：`id/name/faction/system/hp/atk/def/spd/skill_small/skill_ult/portrait_id/sprite_id/background`（background=T2.9 新增，缺省空；字段契约见 `docs/系统规则/角色系统.md` §2；预留 `starmarrow_slots`=6、`sprite_idle_8dir`/`sprite_walk_8dir`）
- **SkillData**：`id/name/type/power(float)/target_side/target_scope/effect/cutscene_id`（target_side 缺省 enemy、effect 缺省 damage、三列与技能数据=T2.9 落位；power 语义按 effect 复用，口径=`docs/系统规则/角色系统.md` §3；无 energy_cost 字段；cutscene_id 沿用 cut_mech_ult/cut_arcane_ult/cut_xian_ult）
- **EnemyData**：`id/name/hp/atk/def/spd/skill_small/skill_ult/ai_pattern/drop_sand`（双技能列 T3.1 执行）
- **StelliumData**：`id/name/set_id/set_name/slot(1-6)/main_stat/main_base/main_max/set_2_bonus/set_3_bonus`（无稀有度；实例字段 lv/sub_unlocked/equipped_by 在 Inventory.starmarrow 逐枚实例，T2.8 执行）
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
| P2 | 角色数据、队伍与底层系统框架 | T2.1~T2.10 全部 ✅（含角色系统补充卡 T2.9→T2.10） | ✅ 完成 | P0（与 P1 并行） |
| P3 | 战斗系统 | T3.1~T3.7 ✅；返工卡 T3.8→T3.9→T3.10→T3.11（战斗系统修订） | 返工待启动 | P2（T2.1/T2.2） |
| P4 | Dialogic 剧情演出 | T4.1~T4.3 ✅、T4.4 待放行评估 | 进行中 | P1、P2 |
| P5 | 心契任务 | T5.1~T5.4 | 待启动 | P3、P4 |
| P6 | 唤星模拟 | T6.1~T6.5 | 待启动 | P5 |
| P7 | 整合与验收 | T7.1~T7.4 | 待启动 | 全部 |

```
graph TD
    P0[P0 骨架✅] --> P1[P1 地图✅]
    P0 --> P2[P2 数据/队伍/框架✅]
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

**并行建议**：T0.1~T3.7、T4.1~T4.3、T2.9、T2.10 已交付（见 §4 已完成卡一览）；**待启动**：战斗系统修订返工卡 T3.8→T3.9→T3.10→T3.11（战斗程序01 主责，口径=docs/系统规则/战斗系统.md）。**并行约束**：T2.9 已验收、T2.10 设计器已交付，T3.10/T3.11 数据前置（skills.csv 三技能列）封锁已解除；T4.4 待放行评估；P5 启动判定：T5.1 前置（T4.3）已过可启用。**T2.10 遗留待制作人04 裁定**：§3 技能 id「按体系」（skill_<体系>_<s1|ult>）与 §6「新角色=characters.csv 一行+skills.csv 两行」冲突——同体系第 2 个角色无法新增专属技能行（详见系统程序交接班表 T2.10 行）。

***

## 4. 任务卡

> 每张卡「【完整指令】」代码块可整体粘贴给 Agent。公共约定见 §2，不逐卡重复。

### 已完成卡（T0.1~T3.7、T4.1~T4.3）

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
| T2.2 | 队伍系统 | Party Autoload：3 人编队+同行槽+team_systems() 三态判定（混元→共振→汇流）、API 返回 bool、party_changed 统一信号（规则 f6979a9，系统策划01） | f6979a9 / 5933d91 |
| T2.3 | 视觉框架与地图 UI | ArtProvider/PauseManager/Transition/MapSystem 四 Autoload+遮挡描边+箱庭图/世界大地图+常驻 HUD（修复 97eec2c、MCP 验收 534c29f） | 42adb70 |
| T2.4 | 神像与存档 | 神像四行为+SaveManager 手动/自动档+坏档回滚（顺带清偿传送落点/地图点击坐标两 bug） | da18d96 |
| T2.5 | UI 面板落地 | UIPanel 基类+UISystem 面板栈+主页菜单/角色列表详情分页/星髓三区骨架/任务三色/唤星占位/背包/设置三页/主角命名；面板名清单锁死供 T5.4/T6.x | a36a19c |
| T2.6 | 美术视觉规范（占位升级） | 视觉规范文档+占位资源包+哨兵资源；8 向帧条契约锁死供 T3.6/T7.3（验证回填 5dd5f62） | 98775fb |
| T2.7 | 遗留修补（名牌+冒烟断言） | 名牌读 CSV（quest_npc 组遍历，npc_id 唯一真相）+冒烟断言防回退 | 938a7b2 |
| T2.8 | 星髓槽位制数据修订 | stellium.csv 重构 12 行槽位制+skills.csv 删 energy_cost+EnemyData 扩双技能列（跨岗登记 data_models.gd） | bad246c |
| T2.9 | 角色系统数据落地与三角色迁移 | SkillData 扩 target_side/target_scope/effect 三字段（缺省 enemy/single/damage 容错）+ CharacterData.background；skills.csv 三角色技能按角色系统.md §5 重定义迁移（诺菈 ally+heal 2.0/shield 3.0、艾蕾雅 enemy+all 1.2/ally+all amp 30、洛清弦 enemy+column 1.2/enemy+all 2.5）+ enemy 两技能显式 enemy+single+damage；CharListPanel 展示 background+三字段；6 冒烟回归 EXIT=0（验收 2026-09-20） | 32ccc2b / 81df7cf / 099d575 |
| T2.10 | 角色设计器 | tools/character_designer.gd（headless）：characters.csv/skills.csv 全行校验（列数/枚举/id 规则/引用/占位资源）+ DataManager·ArtProvider 冒烟 + 逐项报告 `EXIT=0\|1`；端到端实测新角色零代码入角色列表（列表截图 + 数据用后删）；三类坏数据（缺列/坏枚举/坏引用）FAIL 定位到行；口径冲突（§3 技能 id 按体系 vs §6 新角色两行技能）报制作人04 | 58438b1 |
| T3.1 | 敌人占位数据（灾蚀兽） | 四维 150/10/6/8+ai_pattern=simple+drop_sand=30+skill_small/skill_ult 双技能列 | ad2a25d |
| T3.2 | 战斗状态机（跑速条制） | SpeedBarSimulator 跑速条模拟器替代 spd 排序+回合边界+tie-break（spd→我方→编队序） | 8a9ec4b / 48e9978 |
| T3.3 | 指令系统（充能制） | charge 充能条 0~100+图标三态+charge_free 预留+指令校验 | 495723f |
| T3.4 | 伤害与数值结算 | 增伤乘区+合击伤害入口；暴击乘区连乘/一次 int 截断/max(1,·)/合击条件增伤求和四口径裁定 | 1c397dd |
| T3.5 | 队伍机制 | 共振合击/汇流充能拉条/混元增幅 30%（四维）；拉条大招不计计数窗口；combo_calc 阵营过滤修复 | dfe5f2d |
| T3.6 | 战斗演出占位 | 立绘常驻+切换（激活/小技能）+大招/合击全屏 CG 层+跳过+敌方同规格演出 | 9481ea4 |
| T3.7 | 战斗场景接入与奖励 | Battle.tscn 复用地图地板+battle_started/finished 链+星砂结算+Transition 进出；协作：CampMap 触发区跨岗登记与回归 | 34f4e24 |
| T4.1 | Dialogic 2 集成与冒烟验证 | Dialogic 2 集成+测试 dch/dtl+播放/结束信号冒烟 | b0ea063 |
| T4.2 | CSV→Dialogic 转换管线 | csv_to_dialogic.gd 幂等管线+DialogicBridge 桥接+set_flag/flag_condition 列约定 | c15a809 |
| T4.3 | 主线剧情 1 段（邂逅 3 人） | 正式台词 CSV+触发区分发+flag 清单（收尾 403f5ca 重跑管线） | 338d8d3 |

> T2.1 遗留修补已由 T2.7（A1 名牌 / A2 冒烟断言）、T2.8（A4 套装制）清偿完毕。
> **战斗系统修订返工卡=T3.8/T3.9/T3.10（见 P3 返工卡段）。**

### T2.2 队伍系统（✅ 已完成）

| 字段 | 内容 |
| --- | --- |
| 目标 | 3 人编队 + 同行临时槽位 + 体系组合判定 + party_changed 信号 |
| 产出 | `scripts/core/Party.gd`（Autoload） |
| 依赖 | T2.1 |
| 主责 | 系统程序◎、系统策划○（队伍规则确认） |
| 预估 | 1~2 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T2.2 队伍系统
目标：实现 Party 单例：3 人编队、同行临时槽位、体系组合查询（供战斗共振/汇流/混元判定）、party_changed 信号。
前置：T2.1 已通过。队伍规则以系统策划01 队伍规则文档为准（若未就绪，按以下默认规则实现，后续对齐）。

执行步骤：
1. Party.gd（Autoload）：members: Array[String]（角色 id，上限 3）、companion_id: String（同行角色 id，占用 1 个编队位置）。
2. API：add_member(id) / remove_member(id) / is_full() / has_member(id) / set_companion(id) / clear_companion() / get_members()。
3. party_changed 信号：Party 数据变更（add_member/remove_member/set_companion/clear_companion）后统一发 EventBus.party_changed(party_list)（EventBus 需先注册该信号；party_list 为当前编队 id 数组，含同行）。
4. 同行槽只占编队数据，不生成任何地图实体/跟随者（架构 §1.3：地图仅主角移动，同行角色无地图实体）。
5. 体系组合查询 team_systems() -> Dictionary：{systems: Array, all_same: bool, has_all_three: bool}（three = 机律/秘法/玄门齐全）；基于角色体系（characters.csv system 列），与星髓无关；星髓 6 槽是角色装备槽，归 T6.5，与本卡解耦。
6. 用 MCP 编辑器内执行脚本测试三种编组：全同体系 → all_same=true；三系齐 → has_all_three=true；两系 → 两者皆 false。

产出：Party.gd（Autoload）。

验收（全部通过）：
- [ ] 增删/满员/查询 API 行为正确，上限 3
- [ ] 同行角色占用槽位可设置/清除
- [ ] 三种编组的体系组合判定正确
- [ ] party_changed 信号在每次数据变更后发出（get_node("/root/EventBus") 侧验证，占位 print 日志即可）

提交：git commit -m "T2.2: 队伍系统" 并 push。
```

### P2 后续卡（视觉框架 / 神像存档 / UI 面板 / 修补）

#### T2.3 视觉框架与地图 UI（✅ 已完成）

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

#### T2.4 神像与存档（✅ 已完成）

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

#### T2.5 UI 面板落地（✅ 已完成）

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
5. 角色详情页 1：高清立绘占位（色块）+四维（hp/atk/def/spd 读 CharacterData）+星缘（占位）+技能列表（读 SkillData：名/倍率）。
6. 角色详情页 2 =星髓面板（三区骨架，数据行 T2.8/T6.5 才有，先用空态+假数据 1 条验证布局）：装备区=6 槽网格 2×3（当前角色）；持有列表=筛选（**等级/套装，MVP 无稀有度**——星髓体系无关，无体系筛选）；养成区=强化按钮占位+属性预览。本卡只做布局与空态交互，装备逻辑在 T6.5。
7. 编队操作入口：角色列表中「加入编队/移出」按钮→Party.add_member/remove_member（上限 3，满员提示）。

【步骤3 任务面板 + 唤星面板 + 背包 + 设置】
8. 任务面板（J）：全屏列表按主线/支线/心契三组（组头三色：#FFA640/#6FC9FF/#FF8FC8）；条目=任务名+当前步骤+目标进度；无任务显示空态。数据源 QuestRunner 未就绪→读 quests.csv 直接列骨架。
9. 唤星面板（G）：星砂×100 单抽按钮（星砂不足禁用+提示）+保底进度条（pity_counter/60，占位）+结果展示区（T6.4 接演出）；本卡按钮可置灰标注「T6.2 开放」。📌 设定修订：T6.4 将此占位升级为**全屏唤星界面**（右上星砂/主体角色展示图/右下单抽+十连），本骨架仅作占位勿扩展。
10. 背包（B）：分类 Tab（**道具/材料/任务品，无星髓 Tab**——星髓不入背包，查看/装备在角色面板星髓面板）+网格+数量徽标；详情浮层占位；数据源 Inventory 未就绪→空态（T6.1 接）。
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

#### T2.6 美术视觉规范（占位升级）（✅ 已完成）

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

#### T2.7 遗留修补（名牌 + 冒烟断言）（✅ 已完成）

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

#### T2.8 星髓套装制数据修订（✅ 已完成）

| 字段 | 内容 |
| --- | --- |
| 目标 | 架构 §2.5 星髓体系无关化的数据落地（A4） |
| 产出 | stellium.csv 新列结构 + StelliumData 适配 + 占位套装数据 |
| 依赖 | 无（T0.3 管线即可） |
| 主责 | 数值策划01◎（跨岗改 data_models.gd 需台账登记知会系统程序） |
| 预估 | 1 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T2.8 星髓槽位制数据重构与技能耗能列移除
目标：按 docs/系统规则/星髓系统.md 重构 stellium.csv 与 StelliumData（套装×槽位制、无稀有度）；按 docs/系统规则/战斗系统.md §3/§8 移除 skills.csv energy_cost 列。
前置：T0.3、T2.1 已过。

执行步骤：
1. stellium.csv 列头改为：id,name,set_id,set_name,slot,main_stat,main_base,main_max,set_2_bonus,set_3_bonus
   - （set_id, slot）唯一确定星髓类型；2 套 × 6 槽 = **12 行**，现骨架 3 行重写
   - 1~3 号位 main_stat 固定（atk/def/hp）；4~6 号位 main_stat 为随机池（`|` 分隔，如 pct_atk|pct_def|pct_hp，main_base/main_max 与池一一对应；5 号位 crit|crit_dmg|pct_atk、6 号位 charge|spd）
   - set_2_bonus/set_3_bonus 格式 "attr:value;attr:value"：套装1=crit:15% / cond_dmg:hp>70%,50%；套装2=crit_dmg:15% / cond_dmg:hp<50%,50%
   - **无 rarity 列**（MVP 无稀有度，星髓系统.md §3/§7.2）
2. 适配 scripts/core/data_models.gd 的 StelliumData：字段=新列头全集 + from_csv_row 解析（缺省容错：数值 0、字符串空）。
3. skills.csv **删除 energy_cost 列**，SkillData 同步删除 energy_cost 字段（战斗为大招充能制、无耗能字段，见战斗系统.md §3；power 倍率不变）。
4. 更新 tools/smoke_test_data_models.gd：星髓断言为新结构（含 slot 1-6）；删除 energy_cost 相关断言。
5. MCP 运行确认 stellium=12、skills=6 加载无坏行；str() 打印各一行验证。
6. 台账登记：data_models.gd 与 skills.csv 均为跨岗改动（系统程序辖区），在系统程序交接班表追加一行（StelliumData/SkillData 结构变更，T3.3/T6.5 消费新字段）。

验收（全部通过）：
- [ ] stellium=12 加载无坏行，slot 覆盖 1-6，1~3 号位固定/4~6 号位池逻辑自洽
- [ ] skills.csv 无 energy_cost 列，SkillData 无该字段，冒烟测试通过
- [ ] 跨岗登记完成

提交：git commit -m "T2.8: 星髓槽位制数据修订" 并 push。
```

### P2 补充卡（角色系统）

> 承接 `docs/系统规则/角色系统.md`（角色设定唯一口径：§2 字段契约 / §3 技能形式 / §5 三角色定稿 / §6 新增接口 / §7 设计器）。**执行顺序 T2.9→T2.10；T2.9 完成前 T3.10/T3.11 不得开工**（skills.csv/SkillData 三技能列为其数据前置）。

#### T2.9 角色系统数据落地与三角色迁移 ✅

| 字段 | 内容 |
| --- | --- |
| 目标 | 角色系统.md §2/§3 数据契约落地：characters.csv 增 background 列、skills.csv 增 target_side/target_scope/effect 三列、三角色技能按 §5 重定义迁移 |
| 产出 | 数据契约扩字段 + 三角色迁移（背景+技能重定义） |
| 依赖 | T2.8（已过） |
| 主责 | 系统程序◎、数值策划○（技能数据）、剧情文案策划○（background 文案、技能占位名复核） |
| 预估 | 1 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T2.9 角色系统数据落地与三角色迁移
目标：按 docs/系统规则/角色系统.md §2/§3/§5 落地角色数据契约并完成现有三角色迁移。
前置：T2.8 已通过；必读角色系统.md §2/§3/§4.1/§5。

执行步骤：
1. characters.csv 新增 **background 列**（一句话背景，缺省空容错）；剧情文案策划 ○ 按角色系统.md §5 人设基线填三角色 background（与 dialogues_main_01 口径一致）。
2. skills.csv 新增 **target_side（enemy 缺省/ally）、target_scope（single/column/all）、effect（damage 缺省/heal/shield/amp）三列**（缺省值容错）；按角色系统.md §5 迁移三角色技能数据：
   - 洛清弦：s1 enemy+column（power 1.2）、ult enemy+all（power 2.5）
   - 艾蕾雅：s1 enemy+all（power 1.2）、ult **ally+all，effect=amp，power=30**（技能名占位改「大源回响·辉映」）
   - 诺菈：s1 **ally+single，effect=heal，power=2.0**（占位名「应急修复协议」）、ult **ally+single，effect=shield，power=3.0**（占位名「协议·护盾阵列」）
   - power 语义按 effect 复用（heal/shield=×atk 系数、amp=增伤百分点，§3）；技能占位名由剧情文案策划 ○ 复核后定稿并登记交接班表。
3. CharacterData 扩 background；SkillData 扩 target_side/target_scope/effect（缺省值容错）；tools/smoke_test_data_models.gd 断言同步扩（三角色技能字段回读+缺省值容错用例）。
4. headless 冒烟：三角色加载、新列回读断言（对照角色系统.md §5 表逐值）；既有全部冒烟回归 EXIT=0。
5. MCP：角色详情面板展示 background；日志输出三角色技能三字段表。

产出：background+三技能列、模型扩字段、三角色迁移（背景+技能重定义）。

验收（全部通过）：
- [ ] 三角色 background 非空且与人设基线一致
- [ ] skills.csv 三列回读与角色系统.md §5 逐值一致（含 ally 技能与 amp/heal/shield）
- [ ] 缺省值容错：enemy/damage 缺省、缺列旧数据不崩
- [ ] 数据冒烟断言全过；既有冒烟回归 EXIT=0
- [ ] 技能占位名复核登记（剧情文案 ○）

提交：git commit -m "T2.9: 角色系统数据落地与三角色迁移" 并 push。
```

#### T2.10 角色设计器 ✅ 完成（系统程序06 主责）

| 字段 | 内容 |
| --- | --- |
| 目标 | 角色系统.md §7：tools/character_designer.gd（校验+冒烟+报告），支撑按 §6 接口零代码新增角色 |
| 产出 | character_designer.gd |
| 依赖 | T2.9（已过） |
| 主责 | 系统程序◎、数值策划○（校验规则确认） |
| 预估 | 1 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T2.10 角色设计器
目标：按 docs/系统规则/角色系统.md §7 实现 tools/character_designer.gd（headless 可跑）。
前置：T2.9 已通过；必读角色系统.md §2/§3/§6/§7。

执行步骤：
1. 校验器：characters.csv / skills.csv 全行检查——列数、枚举值（system/type/target_side/target_scope/effect）、id 规则（awakened_<体系>_<序号>、skill_<体系>_<s1|ult>）、引用存在（skill_small/skill_ult 在 skills.csv 中存在、cutscene_id 符合 cut_<体系>_ult 约定、portrait/sprite 资源文件存在）；FAIL 明细含文件+行号。
2. 冒烟：DataManager 加载断言（角色数、各角色字段回读）+ ArtProvider 取占位资源非空。
3. 报告：逐项 PASS/FAIL 输出，EXIT=0/1。
4. 端到端验证：临时新增测试角色（characters.csv+skills.csv 各一行+占位立绘/精灵资源）→ 设计器 PASS → 游戏加载断言（角色数 +1、字段回读、角色列表 UI 可见）→ 验证后删除测试数据（git 状态恢复干净）。
5. 故意注入坏数据（缺列/坏枚举/坏引用）各一例，验证 FAIL 正确命中并定位。

产出：tools/character_designer.gd。

验收（全部通过）：
- [ ] 测试角色经设计器 PASS 后游戏内零代码生效（角色列表可见，截图）
- [ ] 三类坏数据各被正确 FAIL 且定位到行（日志）
- [ ] 正常三角色校验/冒烟全 PASS（EXIT=0）
- [ ] 测试数据删除后仓库与 CSV 恢复原状

提交：git commit -m "T2.10: 角色设计器" 并 push。
```

### P3 战斗系统

#### T3.1 敌人占位数据（灾蚀兽 · CSV）（✅ 已完成）

| 字段 | 内容 |
| --- | --- |
| 目标/产出/依赖 | enemies.csv 正式内容（corrosion_beast，hp≈150/atk≈10/def≈6/spd≈8，ai_pattern=simple，drop_sand=30） |
| 依赖 | T0.3（已过，可立即并行） |
| 主责 | 数值策划◎ |
| 预估 | 1 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T3.1 敌人占位数据（灾蚀兽）
目标：完善 enemies.csv：灾蚀兽属性+双技能+星砂掉落（战斗系统 §3：敌人也有小技能/大招）。
前置：T0.3 已通过。

执行步骤：
1. skills.csv 增敌人技能两行（占位数值）：enemy_beast_small（type=small，power≈1.0）、enemy_beast_ult（type=ult，power≈1.8）；id 前缀 enemy_ 区分角色技能。
2. enemies.csv：id=corrosion_beast，name=灾蚀兽，hp≈150、atk≈10、def≈6、spd≈8（占位可调），**skill_small=enemy_beast_small、skill_ult=enemy_beast_ult**，ai_pattern=simple，drop_sand=30。
   - ai\_pattern 口径（战斗系统 §8）：MVP 恒 simple=充能未满用小技能、充满放大招；列保留为后续行为模式扩展位。
3. MCP 运行确认 enemies=1、skills=8；get_enemy 字段完整、双技能 id 可关联到 skills.csv 行。

验收：
- [ ] 加载成功，drop_sand 可被战斗结算读取（数值类型正确）
- [ ] skill_small/skill_ult 两列关联有效

提交：git commit -m "T3.1: 灾蚀兽敌人数据(双技能)" 并 push。
```

#### T3.2 战斗状态机（✅ 已完成）

```
任务：T3.2 战斗状态机（跑速条制）
目标：按 docs/系统规则/战斗系统.md §2 实现跑速条制状态机：init → 速度条模拟循环 → 胜负判定；每步输出日志。
前置：T2.1、T3.1 已通过。
权威依据：docs/系统规则/战斗系统.md §2（跑速条制）。

执行步骤：
1. BattleManager.gd：状态枚举 intro/running/action/win/lose；init(party_ids, enemy_ids) 从 DataManager 取数据构造 BattleUnit 列表。
2. **速度条模拟器**（§2）：速度条上限 100；回合开始全员置 0 → 按各自 spd 前推 → 最先到达 100 者出手（平局：spd 高者优先→我方优先→编队序）→ 出手后归 0 且**本轮不再前推**（每轮限出手一次）→ 全员都出手过后本回合结束、全员归零进下一回合。演出期间后台跑条瞬间推进到出手回合、出手时跑条暂停（演出接入在 T3.6，本卡先留暂停钩子）。
3. 敌方行动：按 ai_pattern=simple 执行（充能未满用小技能、充满放大招；充能积累同 §3 数值 +20/+15/+10）；我方行动等待指令（T3.3 接入）。
4. 每步 print 结构化日志：[BATTLE] 回合 N / 行动者 / 速度条位置 / 目标 / 结果 / 双方 HP。
5. MCP 无 UI 冒烟：3 人 vs 1 兽，跑 20 回合确认无死锁、可进 win/lose；出手顺序与 spd 规则可复算。

产出：BattleManager.gd（含速度条模拟器）。

验收（全部通过）：
- [ ] 日志展示跑速条推进与出手顺序（与 spd 平局规则一致）
- [ ] 回合边界正确（每轮每人一次、全员出手完进下一轮）
- [ ] 可正常进入 win / lose，无死锁

提交：git commit -m "T3.2: 战斗状态机(跑速条制)" 并 push。
```

#### T3.3 指令系统（✅ 已完成）

```
任务：T3.3 指令系统（充能制）
目标：BattleUnit（HP/充能条）+ 两种指令（小技能/大招）+ 目标选择；按 docs/系统规则/战斗系统.md §3 实现。
前置：T3.2 已通过。
权威依据：docs/系统规则/战斗系统.md §3（充能制）；SkillData 已无 energy_cost（T2.8）。

执行步骤：
1. BattleUnit.gd：hp/max_hp、charge/charge_max（默认 100）、charge_free（默认 false，机制预留，三觉醒者恒 false）、take_damage、is_alive、技能数据（SkillData 小技能/大招各一）。
2. 充能积累（§3 数值）：**小技能命中 +20 / 受到伤害 +15 / 自身回合激活开始 +10**；clamp 到 charge_max；释放大招后 charge=0。
3. BattleCommand.gd：枚举 SKILL/ULT（无独立普攻，小技能即每轮可用基础攻击）；校验：小技能恒可用、大招需 charge==charge_max 或 charge_free=true（图标三态：未满灰/满亮闪/释放中）；不满足返回原因。
4. 目标选择：MVP「自动选第一个存活目标 + 手动确认」。
5. MCP 冒烟：脚本调用指令，验证伤害应用、充能积累三途径与重置、目标死亡处理。

产出：BattleUnit.gd、BattleCommand.gd。

验收（全部通过）：
- [ ] 两种指令可执行；大招充能未满禁用有提示、充满可释放并归零
- [ ] 充能积累三途径数值正确（日志可证）
- [ ] 死亡目标被跳过，敌人全灭正确结算

提交：git commit -m "T3.3: 指令系统(充能制)" 并 push。
```

#### T3.4 伤害与数值结算（✅ 已完成）

```
任务：T3.4 伤害与数值结算（增伤乘区+合击入口）
目标：伤害公式+星髓条件增伤乘区+合击技伤害入口；数值全部来自 CSV。
前置：T3.3 已通过。
权威依据：docs/系统规则/战斗系统.md §4.1/§4.4、docs/系统规则/星髓系统.md §7.1。

执行步骤：
1. DamageCalc.gd：damage = max(1, (atk * skill_power - def)) * (1 + 条件增伤)；条件增伤=星髓 3 件套（目标当前 HP/max_hp >70% / <50% 判定；接口 get_stellium_bonus(character_id)，T6.5 前空实现返回 0）；暴击率 10%（占位）+暴击词条加成、暴伤 ×1.5+爆伤词条加成。
2. **合击技伤害入口**（§4.1）：combo_damage = (存活者 atk 之和 × 100% - def) 走同一管线（含 def 减免与条件增伤乘区）；专用暴击率=三人暴击率之和÷300%、专用暴伤=**固定 300%**（不吃词条加成）；供 T3.5 调用。
3. 接入 BattleCommand 执行路径，日志输出：出手者/技能/伤害/是否暴击/目标剩余 HP。
4. MCP 手动验算 ≥3 组（普通/暴击/条件增伤各一组）与手算一致。
5. 数值均从 CharacterData/EnemyData/SkillData 读取，不硬编码。

产出：DamageCalc.gd。

验收（全部通过）：
- [ ] ≥3 组手算与实测一致（日志可证）
- [ ] 增伤乘区生效；合击入口暴击率/暴伤为专用值（公式可复核）
- [ ] 伤害下限为 1；数值全部来自 CSV

提交：git commit -m "T3.4: 伤害结算(增伤乘区+合击入口)" 并 push。
```

#### T3.5 队伍机制（共振合击 / 汇流充能拉条 / 混元增幅）（✅ 已完成）

```
任务：T3.5 队伍机制（共振合击/汇流充能拉条/混元增幅）
目标：按 docs/系统规则/战斗系统.md §4 实现三态效果；判定逻辑沿用 Party.team_systems()（T2.2 交付，接口不变）。
前置：T3.4 已通过。
权威依据：docs/系统规则/战斗系统.md §4。

执行步骤：
1. PartyBonus.gd：进战斗时取 team_systems() 判定（has_all_three→混元 / all_same→共振 / 两系→汇流，互斥，判定顺序固定）：
   - **混元**：全队四维 hp/atk/def/spd ×1.3（星髓并入后乘算，持续整场；不含暴击/爆伤/充能）。
   - **共振**：监听三人大招释放计数（各 ≥1 次满足→触发合击；触发后计数重置可循环；死亡角色计数保留且不计入 atk 求和）→ 触发瞬间**不看跑条插入合击**：调 T3.4 合击入口 combo_damage → 对全体敌人结算 → 播合击 CG（调 T3.6 演出钩子）；合击不改变三人跑条位置与充能。
   - **汇流**：单体=角色释放大招后 charge 置为上限的 30%（不归 0）；全体=三人都释放过后全员拉条 +30（≥100 者按跑条规则立即触发出手，多达标 spd 优先；本轮已出手单位拉条无效；演出中拉条延迟到演出结束后结算）。
2. 敌人无体系效果；战斗开始打印 [BONUS] 日志标注体系类型。
3. MCP 冒烟：三种编组分别开战——共振编组三人大招后合击触发（日志+伤害复核）；汇流编组大招后 charge=30、三人齐后拉条；混元编组四维 ×1.3 且日志无共振/汇流字样。

产出：PartyBonus.gd。

验收（全部通过）：
- [ ] 三种编组各触发对应效果（日志可证），互斥无交叉
- [ ] 共振合击伤害=存活者 atk 之和×100% 走 T3.4 管线（数值可复核）
- [ ] 汇流充能 30%/拉条 30% 数值与时机正确；混元四维增幅可证

提交：git commit -m "T3.5: 队伍机制(合击/充能拉条/增幅)" 并 push。
```

#### T3.6 战斗演出占位（✅ 已完成）

```
任务：T3.6 战斗演出占位（立绘常驻+CG 层）
目标：按 docs/系统规则/战斗系统.md §7 布局：右下角立绘常驻+小技能动态立绘切换、大招全屏 CG、合击 CG 演出层；演出期间跑条暂停、可跳过。
前置：T3.4 已通过。
权威依据：docs/系统规则/战斗系统.md §7。

执行步骤：
1. BattleCutscene.tscn（CanvasLayer）：右下角 PortraitRect（常驻，TextureRect 色块+角色名）/ UltCGRect（全屏，技能名大字）/ ComboCGRect（全屏，合击技名大字）/ SkipHint；AnimationPlayer 色块占位动画。
2. BattleCutscene.gd：play_active(id)（回合激活→更新右下角立绘）/ play_skill(id, skill_id)（小技能动态立绘占位 0.8s，播毕切回常态）/ play_ult(id, skill_id)（全屏 CG 占位 2s）/ play_combo()（合击 CG 占位 2s）；空格跳过；播完发 finished 信号。
3. BattleManager 接入：激活回合更新右下角立绘；大招/合击演出优先——演出期间跑条暂停（T3.2 钩子），演出结束恢复推进并结算拉条等延迟效果（§4.2）；立绘走 ArtProvider.get_portrait(id, emotion)（占位）。
4. MCP：运行战斗 → 截图右下角立绘/大招全屏/合击全屏 → 空格跳过 → 战斗继续。

产出：BattleCutscene.tscn、BattleCutscene.gd。

验收（全部通过）：
- [ ] 三种演出（小技能切换/大招 CG/合击 CG）分别触发且可结束
- [ ] 跳过可用；演出期间跑条暂停、结束后恢复
- [ ] 画面含角色名/技能名/合击技名（占位证据）

提交：git commit -m "T3.6: 战斗演出(立绘常驻+CG层)" 并 push。
```

#### T3.7 战斗场景接入与奖励（✅ 已完成）

```
任务：T3.7 战斗场景接入与奖励
目标：实现战斗场景：从地图触发进入、三人 vs 灾蚀兽、胜利结算星砂、可复用于心契任务。
前置：T3.5、T3.6、T1.5 已通过。

执行步骤：
1. Battle.tscn：**复用当前地图地板**（TileMapLayer 地板层，战斗系统 §1）+ 隐藏建筑物/装饰/跑图 UI + 敌我站位（我方三人左侧、敌方右侧，Q 版色块占位）+ 战斗 UI 层 + BattleController.gd。
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

### P3 返工卡（战斗系统修订）

> 承接 `docs/系统规则/战斗系统.md` 现行修订（规格→卡映射见其 §10）。开工前必读该文档（唯一规则口径）；既有战斗冒烟（tools/smoke_test_battle*.gd）为回归底线，每卡收工必须复跑不劣化。**执行顺序 T3.8→T3.9→T3.10→T3.11；T3.10/T3.11 以 T2.9（角色系统技能数据）为前置。**

#### T3.8 跑条动画与速度条 UI 重构（含右下角头像修复）

| 字段 | 内容 |
| --- | --- |
| 目标 | 战斗系统.md §2+§6：速度条改屏幕左侧竖向细长条+圆形头像+跑条动画；修复右下角参战头像血条缺失 |
| 产出 | 速度条 UI 重构 + 跑条动画 + 头像血条修复 |
| 依赖 | T3.7（已过）；规则依据=战斗系统.md §2/§6 |
| 主责 | 战斗程序◎、美术○（视觉核对） |
| 预估 | 1~2 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T3.8 跑条动画与速度条 UI 重构
目标：按 docs/系统规则/战斗系统.md §2/§6 重构速度条表现层并修复头像缺失。
前置：T3.7 已通过；必读战斗系统.md §2（跑速条制）与 §10（承接映射）。

执行步骤：
1. 速度条 UI 重构：原右侧竖条 → **屏幕左侧竖向细长进度条**（上限 100，进度条样式）；我方与敌人的**圆形小头像**置于条上随位置实时移动（**头像直径 = 速度条宽度 × 2**，敌我头像可辨（配色/边框区分））。
2. 跑条动画（§2.3）：非出手单位的跑条过程以**动画呈现，禁止瞬间切换到下一出手单位**；视觉基准=按**当前出战单位平均跑条速度**换算「完整跑完全条 = 1 秒」（常量 RUNBAR_FULL_TIME 暴露可调）；各头像按自身速度呈现相对快慢；出手回合动画暂停、出手后恢复循环。
3. 后台/表现解耦：出手先后判定仍走既有 SpeedBarSimulator 后台结算（结果不变），动画仅同步表现，不改变战斗节奏与胜负结果。
4. 修复右下角参战角色头像（§6 必显项，实机遗失）：三人头像横排+各自血条+当前激活回合高亮，战斗全程常显。
5. headless 冒烟：既有 tools/smoke_test_battle*.gd 全部复跑 EXIT=0（结果零变化）；新增断言：RUNBAR_FULL_TIME 常量存在且=1.0、头像节点条位随模拟位置移动。
6. MCP：进战斗截图速度条（左侧+圆形头像）与右下角头像血条；连续两出手间截图证明头像在条上移动（非跳变）。

产出：速度条 UI 重构、跑条动画、头像血条修复。

验收（全部通过）：
- [ ] 速度条位于屏幕左侧竖向、圆形头像直径=条宽×2（截图）
- [ ] 跑条动画连续可见，无瞬间切换（截图×2 时序）
- [ ] 右下角参战头像+血条常显且激活高亮（截图）
- [ ] 后台结算结果与既有实现零差异（冒烟复跑 EXIT=0）
- [ ] 1 秒基准常量可调（改值生效，日志可证）

提交：git commit -m "T3.8: 跑条动画与速度条UI重构" 并 push。
```

#### T3.9 对阵阵型与多敌编组

| 字段 | 内容 |
| --- | --- |
| 目标 | 战斗系统.md §9：4×3 斜向格子对阵布置（多敌上限 6），为目标选择提供格位基础 |
| 产出 | 阵型生成器 + 多敌编组支持 |
| 依赖 | T3.8 已通过 |
| 主责 | 战斗程序◎ |
| 预估 | 1~2 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T3.9 对阵阵型与多敌编组
目标：按 docs/系统规则/战斗系统.md §9 落地对阵阵型与多敌编组，替换既有「我左敌右」旧站位。
前置：T3.8 已通过；必读战斗系统.md §9。

执行步骤：
1. 阵型生成器：4 列 × 3 行格子区域，矩形**斜向摆放**（区域右边缘向上斜 45°、左边缘向下斜 45°）；**第一列（1×3）=我方**（屏幕中间左下角同排排列）、**第二列=空白分界线**、**第三/四列×3 行=敌方阵地**（屏幕中间右上角排列）；我方按实际出战人数站位、敌方按 battle_started 的 enemy_ids 数量站位（1~6，空位允许）。
2. 多敌编组支持：BattleController/BattleManager 支持 enemy_ids 数组 1~6（MVP 正式战斗仍=灾蚀兽 1 只不变；用测试编组验证 3 敌/6 敌）；**「前列」=第三列（靠我方）、「后列」=第四列**（供 T3.10 column scope 消费）。
3. Q 版模型规格：与地图上角色大小一致（复用 T2.6 既有小人规格）。
4. headless 冒烟：阵型坐标断言（斜向偏移=数学换算核对、12 格锚点正确）；多敌编组 1/3/6 站位与战斗流程通；既有冒烟回归 EXIT=0。
5. MCP：进战斗截图阵型全景（我左下/敌右上/斜向）；3 敌与 6 敌测试编组各一场截图。

产出：阵型生成器、多敌编组支持。

验收（全部通过）：
- [ ] 阵型 4×3 斜向摆放正确，我方左下/敌方右上/第二列空白（截图）
- [ ] 敌方 1/3/6 人编组均正确站位且战斗流程完整（截图×2）
- [ ] Q 版模型与地图角色同规格
- [ ] 既有战斗冒烟回归 EXIT=0 不劣化

提交：git commit -m "T3.9: 对阵阵型与多敌编组" 并 push。
```

#### T3.10 手动模式与目标选择（含伤害/效果飘字）

| 字段 | 内容 |
| --- | --- |
| 目标 | 战斗系统.md §8：自动/手动切换、手动指令按钮+E/Q、目标选择状态（敌我箭头+移动键）、目标三字段驱动、飘字组件 |
| 产出 | 手动模式+目标选择（敌/友）+飘字组件 |
| 依赖 | T3.9 已通过；**T2.9 已通过（技能三列数据前置）** |
| 主责 | 战斗程序◎ |
| 预估 | 2 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T3.10 手动模式与目标选择
目标：按 docs/系统规则/战斗系统.md §6/§8 实现自动/手动模式、目标选择状态（敌/友）与飘字组件。
前置：T3.9、T2.9 已通过；必读战斗系统.md §6/§8（含 §3.1 目标三字段、§8.2 箭头规则）。

执行步骤：
1. 自动/手动切换（§8.1）：屏幕右上角开关，**默认自动**，战斗中随时切换立即生效；自动=AI 自动选技能与目标（无选择 UI）；切换开关不重置跑条与充能。
2. 手动模式指令（§8.1/§6）：轮到我方角色出手（战斗待机）时，右下角立绘下方**并排显示小技能/大招两按钮**（大招充能未满灰显、满则亮色闪光）；快捷键 **E=小技能、Q=大招**（physical_keycode+代码兜底注册，防编辑器覆写回滚）；等待操作期间跑条动画暂停（§2.3）。
3. 目标三字段驱动（§3.1）：按 T2.9 交付的 target_side/target_scope/effect 计算目标集合——enemy+single=单选 1 敌 / enemy+column=一列敌（前列/后列=T3.9 阵型第三/四列）/ enemy+all=全部敌 / **ally+single=单选 1 队友 / ally+all=全队**；**目标集合选取器**独立函数预留（后续组合范围不改战斗框架）。
4. 目标选择状态（§8.2）：选定技能后进入——目标头顶箭头指示（**敌方=向下箭头、友方=向上箭头**）；**移动键（方向键）**按格位顺序在可选目标间切换；各类型箭头数量与免选规则按 §8.2 表（enemy all/ally all 免选直接确认）；**E/空格=确认释放、Esc=取消回指令按钮**（目标状态下 E 为确认语义）。
5. 飘字组件（§8.3）：头顶飘字（伤害=白/红占位、**治疗=绿、护盾=蓝**，向上飘动渐隐，色块字 Label 占位）；本卡交付组件与触发接口，heal/shield/amp 实际触发归 T3.11。
6. 战斗内按键作用于战斗 UI（E 在战斗内=小技能/确认，不触发跑图 interact）。
7. headless 冒烟：目标集合断言（五类技能类型含 ally）；手动模式状态机日志断言（待机→选技能→选目标→确认→结算）；Esc 取消回退；飘字组件生成/回收。
8. MCP：右上角开关切换截图；手动全流程（E 选技能→箭头→移动键切换→确认）截图×3；敌/友箭头区分截图。

产出：手动模式、目标选择状态（敌/友）、目标集合选取器、飘字组件。

验收（全部通过）：
- [ ] 右上角开关随时切换立即生效，默认自动（截图+日志）
- [ ] 手动流程按钮+快捷键均可走通，大招未满按 Q 无效有提示（截图）
- [ ] 目标集合五类型正确：敌单体任意/敌整列前后列/敌全体免选/友单体队友切换/友全体免选（截图×3）
- [ ] 敌方向下箭头、友方向上箭头视觉区分（截图）
- [ ] 既有战斗冒烟回归 EXIT=0 不劣化

提交：git commit -m "T3.10: 手动模式与目标选择" 并 push。
```

#### T3.11 友方技能效果实现

| 字段 | 内容 |
| --- | --- |
| 目标 | 战斗系统.md §3.1 effect 结算：heal/shield/amp 生命周期+自动模式友方 AI+效果飘字触发，接通诺菈/艾蕾雅技能 |
| 产出 | 友方技能结算+buff 生命周期+友方 AI |
| 依赖 | T3.10 已通过（含 T2.9 数据前置） |
| 主责 | 战斗程序◎、数值策划○（占位数值复核） |
| 预估 | 1~2 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T3.11 友方技能效果实现
目标：按 docs/系统规则/战斗系统.md §3.1 实现 heal/shield/amp 三效果结算与 buff 生命周期，接通角色系统.md §5 重定义后的诺菈/艾蕾雅技能。
前置：T3.10 已通过（T2.9 数据已就位）；必读战斗系统.md §3.1/§8.2/§8.3、角色系统.md §3/§5。

执行步骤：
1. effect 分发：技能释放按 effect 枚举分流——damage 走既有伤害管线；heal/shield/amp 走新结算入口（目标集合来自 T3.10 选取器）。
2. heal：目标恢复 HP=施法者 atk×power，上限不超过最大 HP（溢出截断）；触发绿色飘字（T3.10 组件）。
3. shield：目标获得护盾值=施法者 atk×power（同目标重复释放叠加刷新）；受击时**先于 HP 吸收**，耗尽即消失、不随时间衰减；触发蓝色飘字。
4. amp：目标获得「下次攻击伤害 +power 百分点」标记；出手结算时接入伤害乘区（与星髓增伤乘区并列，顺序=增伤乘区阶段）并消费移除；多名队友可同时持有各自标记。
5. 自动模式友方 AI：heal 优先血量比例最低队友；shield 优先无盾且血量比例最低者（占位逻辑）；ally+all 免选直接放。
6. 死亡交互：单位死亡时其 shield/amp 标记清除。
7. headless 冒烟：治疗回血+溢出截断；护盾先吸收后掉血+耗尽消失+叠加刷新；amp 增伤乘区+消费移除；诺菈/艾蕾雅技能全链（施放→目标→结算→飘字信号）；既有冒烟回归 EXIT=0。
8. MCP：诺菈治疗/护盾各一次（截图飘字+血条/盾条变化）；艾蕾雅增伤后队友攻击伤害前后对比（日志）；洛清弦整列/全体伤害回归。

产出：heal/shield/amp 结算、buff 生命周期、友方 AI 占位逻辑、效果飘字触发。

验收（全部通过）：
- [ ] 诺菈小技能治疗正确（atk×2.0 上限截断）、大招护盾先吸收后掉血（截图）
- [ ] 艾蕾雅大招全体队友 +30% 增伤生效且出手消费后移除（日志）
- [ ] 洛清弦整列/全体伤害不受影响（回归）
- [ ] 治疗绿/护盾蓝飘字显示（截图）
- [ ] 自动模式友方 AI 可用；既有冒烟回归 EXIT=0 不劣化

提交：git commit -m "T3.11: 友方技能效果实现" 并 push。
```

### P4 Dialogic 剧情演出

#### T4.1 Dialogic 2 集成与冒烟验证（✅ 已完成）

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

#### T4.2 CSV台词表 → Dialogic timeline 转换管线（✅ 已完成）

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

#### T4.3 主线剧情 1 段（邂逅 3 名觉醒者）（✅ 已完成）

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
1. Inventory.gd（Autoload）：items: Dictionary（道具 id→数量，含 star_sand_crystal）、starmarrow: Array[Dictionary]（**星髓逐枚实例**：instance_id/set_id/slot/lv/sub_unlocked/equipped_by，各实例独立）、cg_collection: Array[String]。
2. API：货币接口对 GameState 的包装（add_sand/spend_sand/add_token/spend_token 引导业务调 GameState）；add_item/has_item/remove_item/unlock_cg/has_cg/add_stellium/has_stellium 管道具、星髓、CG。
3. T1.6 拾取迁移（A3）：CampMap 星砂结晶拾取从 GameState.set_flag("inv_star_sand_crystal",1) 迁移为 Inventory.add_item("star_sand_crystal",1)（节点 queue_free 保留；旧 flag 保留兼容读取一次后废弃）。
4. T3.7 胜利星砂迁移：GameState 直记处改 Inventory.add_sand 包装（若 T3.7 用了暂记方案）。
5. 途径接通：T3.7 胜利奖励 → add_sand；T4.3 主线完成奖励 → add_sand；T5.3 任务奖励/赠礼消耗 → add_item/remove_item；T1.6 拾取 → add_item。
6. 背包面板（T2.5 的 B）接真数据：分类 Tab 道具/材料/任务品（**无星髓 Tab**——starmarrow 仓库仅数据层，查看/装备走角色面板星髓面板 T6.5）。
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
目标：SummonManager：按 summon_pool.csv 权重随机抽取，单抽 100 / 十连 1000 星砂，保底计数生效，结果入包。
前置：T6.1 已通过。

经济闭环（架构 §2.8）：星砂→唤星消耗（单抽 100、十连 1000）；星缘令为唤星产出→用于角色入队解锁。十连=一次扣 1000、连抽 10 次、结果统一返回供 T6.4 展示。

执行步骤：
1. summon_pool.csv 权重复核：出金条目（kind=starlink_token/cg）gold=true，出金总权重约 5%（数值策划可调）；星髓条目按 T2.8 新结构入包。
2. SummonManager.gd：single_draw()->SummonEntryData：按权重随机 1 条；消耗 GameState 星砂 100（常量 SINGLE_COST=100）；保底 pity_counter：每抽 +1，达 60（常量 PITY_MAX=60，待数值策划确认可调）未出金则本次必出金并清零；出金即清零。multi_draw(n=10)->Array[SummonEntryData]：循环 n 次复用单抽判定（pity 逐抽累计、跨抽连续生效），总消耗=100×n（常量 MULTI_COST=1000），星砂不足时整体拒绝不扣费不部分执行。结果统一写入 Inventory（星缘令/材料/星髓/CG→unlock_cg）；EventBus.summon_completed(results: Array) 恒发数组（单抽长度 1、十连长度 10）。
3. pity_counter 需可被存档（SaveManager 存档清单已预留字段）；外部模拟验证可直接循环调用 single_draw。
4. MCP 冒烟：1000 次模拟输出各 kind 占比与权重比对（±2% 容差）；保底验证：构造 pity_counter=59 再抽必出金；单抽扣 100；十连一次扣 1000 且恰返回 10 条；星砂不足（单抽<100 / 十连<1000）拒绝并返回原因，不产生负数。

验收（全部通过）：
- [ ] 1000 次模拟占比与权重一致（±2%）
- [ ] 保底第 60 抽必出金且计数清零（日志可证）
- [ ] 单抽固定扣 100；十连一次扣 1000 且恰返回 10 条结果
- [ ] 星砂不足时单抽/十连均整体拒绝，无部分扣费、无负数
- [ ] 结果入包与 summon_completed 信号一致（单抽 1 条/十连 10 条）

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
任务：T6.4 全屏唤星界面、抽卡演出与图鉴占位
目标：全屏唤星界面（布局+抽卡动画+结果页，替代 T2.5 唤星面板占位）与 CG 图鉴（收藏/查看占位）。
前置：T6.2 已通过。
设定依据：《初期设定》§四（唤星界面与抽卡演出）、架构 §3.1 面板规格唤星行。

执行步骤：
1. SummonScene.tscn 全屏唤星界面：**右上角常显星砂数量**（GameState.star_sand 实时刷新）；**界面主体=角色展示图**（ArtProvider.get_portrait 高清立绘占位居中）；**右下角并排「单抽×100」「十连×1000」按钮**（对应星砂不足禁用+提示）。G 键/主页菜单「唤星」入口改开本界面（T2.5 唤星面板骨架由本卡重构替换）。演出期间接 pause_game("cutscene")（若 PauseManager 已就绪）。
2. 抽卡动画与结果页：点击抽取→色块转场（1s）抽卡动画→揭示结果。单抽：结果 1 条居中揭示（出金 kind=starlink_token/cg→金色闪屏+大字"星缘令/角色CG"；普通→普通反馈道具名）。十连：结果页**竖向并排**（纵向列表）展示 10 条（条目=色块+名+kind 角标，出金条目高亮）。**结果含星缘令→播放特殊动画**（金色闪屏+大字，单抽/十连一致）；**结果含角色 CG→全屏播放一次该 CG**（ArtProvider.get_cg 占位，点击关闭回结果页，同次抽取不重复播放）。动画支持连点加速/跳过，连抽期间结果逐条入列。
3. CgGallery.tscn：已解锁 CG 列表（色块 + 标题占位，数据来自 Inventory.cg_collection）；未解锁显示锁图标占位；点击已解锁项 → 全屏查看占位大图（预留 ArtProvider.get_cg(id) 接口）。
4. 入口：唤星界面/招募界面按钮互跳。
5. MCP：单抽与十连各一次（覆盖出金与 CG）→ 截图全屏布局（右上星砂/主体展示图/右下双按钮）、抽卡动画、十连竖排结果页、星缘令特殊动画、CG 全屏播放、图鉴出现新 CG。

产出：SummonScene.tscn、CgGallery.tscn。

验收（全部通过）：
- [ ] 全屏唤星界面布局正确：右上星砂数量实时、主体角色展示图、右下单抽/十连并排按钮（截图）
- [ ] 抽卡动画完整播放且可连点加速；出金/普通反馈可区分（截图）
- [ ] 十连结果页竖向并排显示 10 条，出金条目高亮（截图）
- [ ] 结果含星缘令播放特殊动画；含角色 CG 全屏播放一次且同次不重复
- [ ] 星砂不足时对应按钮正确禁用并提示
- [ ] 图鉴只显示已解锁 CG，查看占位可打开

提交：git commit -m "T6.4: 全屏唤星界面与抽卡演出" 并 push。
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

规格（docs/系统规则/星髓系统.md）：每角色固定 6 槽（2×3），槽位一一对应不可混用；星髓与体系无关；**套装件数制**——同 set_id 计件 ≥2 激活 2 件套加成、≥3 再激活 3 件套条件增伤（6 件同套不叠加，支持 3+3/2+2+2 组合）；星髓逐枚实例（Inventory.starmarrow，各自 lv/副词条独立，同件不可多角色同穿）。

执行步骤：
1. EventBus 注册 starmarrow_changed(character_id, before, after)；装备/卸下后发射（before/after=该角色已装备星髓实例 id 数组快照）。
2. 装备规则：每槽 1 件、槽位与星髓 slot 一一对应；同一枚星髓实例不可同时装在多名角色（持有唯一性）；装备/卸下写实例 equipped_by 字段。
3. 套装判定（件数制）：按当前角色 6 槽内同 set_id 计件——≥2 件激活 2 件套数值加成（crit/crit_dmg 类并入面板）；≥3 件再激活 3 件套条件增伤（战斗效果：get_stellium_bonus(character_id)->Dictionary 返回 {cond_dmg_hp_gt70 / cond_dmg_hp_lt50}，T3.4 伤害管线消费，回归验证留 T7.1）。
4. 角色详情页 1 的四维显示=基础值+星髓加成（加成来源标注）。
5. 持有列表筛选：**等级/套装两维**（MVP 无稀有度，无体系维度）。
6. 养成区：强化（lv 0→+10，消耗星髓强化材料占位；**每 +2 级觉醒 1 条副词条**——不重复、数值固定不浮动，主词条 main_base→main_max 线性成长占位）；无突破概念；养成结果入档（starmarrow 实例 lv/sub_unlocked）。
7. 存档：星髓实例（含 lv/副词条/equipped_by）纳入 SaveManager 清单（Inventory.starmarrow）。
8. MCP 验证。

验收（全部通过）：
- [ ] 装备/卸下 6 槽正确，槽位对应与唯一性约束生效（同件不可双穿）
- [ ] 2 件套数值并入四维显示（前后对比截图）；3+3 双套装并存正确
- [ ] 3 件套条件增伤 get_stellium_bonus 返回正确
- [ ] starmarrow_changed 信号可证；筛选等级/套装两维可用
- [ ] 强化 0→+10 流程可走、每 +2 觉醒副词条（不重复）；存档→读档后装备与 lv 恢复

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
   ③ 唤星通用池无内购、单抽 100 / 十连 1000、保底 60 生效；唤星界面与演出规格符合 §1 #6（全屏布局/右上星砂/右下双按钮/十连竖排/星缘令特殊动画/CG 播放一次）；
   ④ 星髓：6 槽、体系无关、2 件套数值/3 件套效果；
   ⑤ 心契同行：编队可出战、地图无跟随实体；
   ⑥ 架构 §1~§3 规格抽验：描边白、HUD 四区、Esc 层级、滚轮双向地图、神像四行为、面板暂停世界；
   ⑦ MVP 后项（CG 全量/成就/完整音频/自定义键位）标注 📌 MVP+；
   ⑧ 角色定位与技能效果符合《角色系统》§4.1/§5（生存辅助/增伤副C/群体输出，友方技能 target_side=ally 生效）。
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
- 战斗演出预留 `BattleCutscene` 三类插槽：右下角 `PortraitRect`（激活/小技能动态立绘切换）、`UltCGRect`（大招全屏 CG）、`ComboCGRect`（合击全屏 CG）。
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
| 2 | P1 地图 ∥ P2 | T1.1~T1.6 ✅；T2.1~T2.10 全部 ✅（含补充卡 T2.9→T2.10；T3.1 提前交付 ✅） | ✅ 完成 |
| 3 | P3 战斗 ∥ P4 剧情 | T3.1~T3.7 ✅、T4.1~T4.3 ✅；**待启动**：返工卡 T3.8→T3.9→T3.10→T3.11（战斗系统修订）；T4.4 待放行评估 | 进行中（返工待启动） |
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
- [ ] **三人回合制战斗**：三指令、伤害结算、友方技能（治疗/护盾/增伤）、目标选择箭头（敌我区分）、混元机制、演出占位、星砂奖励、Transition 进出
- [ ] **唤星模拟**：单抽 100 / 十连 1000+保底 60→星缘令→（心契满阶）招募；未满阶正确拒绝；全屏唤星界面（右上星砂/主体展示图/右下双按钮）+十连竖排结果+星缘令特殊动画+CG 播放一次
- [ ] **视觉框架**：8 向接口、描边、Transition、M 箱庭图、世界大地图区块解锁、HUD 四区
- [ ] **神像与存档**：恢复/点亮/传送/存档四行为；自动+手动双槽+回滚；坏档不崩溃
- [ ] **UI 面板**：B/C/G/J/M/Esc 体系、主页菜单暂停、角色详情分页、任务三色、设置三档、主角命名
- [ ] **星髓体系**：6 槽装备、套装判定、属性并入、养成骨架、存档恢复
- [ ] **接口预留**：ArtProvider 全覆盖，AI 资源替换演练通过（T7.3）
- [ ] **设定一致性**：与《初期设定》+架构文档对照无误（架构文档全部规格复核）
