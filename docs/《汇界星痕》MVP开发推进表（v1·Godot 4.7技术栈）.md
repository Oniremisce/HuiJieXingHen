# 《汇界星痕》MVP 开发推进表（v1 · Godot 4.7 技术栈）

> 配套文档：《汇界星痕》初期设定.md
项目路径：`D:\Dev\HuiJieXingHen`
技术栈：Godot 4.7 · GDScript · Dialogic 2（对话插件）· CSV 配表 · Git + GitHub Desktop + GitHub 私有仓库 · AI 美术/音乐资源 · Godot MCP（已连接）
开发方式：vibe coding

***

## 0. 如何使用本表

- 每张任务卡 = 一次独立的 Agent 指令单元。把「**【完整指令】**」代码块整体粘贴给 agent 即可，其余字段（依赖/预估/接口）供你排期与复查。
- 严格执行**依赖顺序**：被依赖任务未验收通过，不启动下游任务。
- Agent 验证统一走 **Godot MCP**（打开场景 / 运行项目 / 捕获输出 / 截图检查），MCP 工具名以你环境中实际暴露的为准（见 §2.6）。
- 每张卡完成后：验收全过 → `git commit`（格式 `T0.1: 描述`）→ push 到 GitHub 私有仓库（见 §2.7）。
- 所有视觉内容仍为**色块/几何体占位**；AI 美术/音乐资源在 T7.3 接入演练，命名与替换规范见 §2.8 与 §5。

***

## 1. MVP 范围与验收目标

| # | 交付项 | 验收目标（MVP 级） |
| --- | --- | --- |
| 1 | 等距 2.5D Q 版地图 ×1 | 可自由漫游、Y 轴遮挡正确、NPC 交互提示生效 |
| 2 | 觉醒者 ×3 | CSV 数据可加载、地图占位 + Dialogic 立绘占位可显示 |
| 3 | 主线剧情 ×1 | 地图触发 Dialogic 演出，完成 3 名觉醒者的剧情邂逅 |
| 4 | 心契任务 ×1 | 同行→互动→满阶，状态机完整可推进（quests.csv 驱动） |
| 5 | 三人回合制战斗 ×1 | 三人小队 vs 灾蚀兽，混元机制可触发，战斗演出占位 |
| 6 | 唤星模拟 ×1 | 星砂抽取（summon_pool.csv）→星缘令→（心契满阶后）招募入队闭环 |

**硬约束**：无真实美术资源（占位色块）；离线单机；所有资源可肝；唤星不跳过剧情（招募前置 = 邂逅 + 心契满阶）。

***

## 2. 技术基线与架构约定

### 2.1 技术选型

| 项 | 方案 |
| --- | --- |
| 引擎 | Godot 4.7 稳定版，GDScript（`project.godot` 锁定版本） |
| 对话 | Dialogic 2（`addons/dialogic`，Asset Library 安装），timeline 用 `.dtl` 纯文本格式 |
| 配表 | CSV（UTF-8），运行时自写解析器；台词 CSV 经 `tools/csv_to_dialogic.gd` 生成 `.dtl` |
| 等距 | TileMapLayer + isometric tileset（色块占位），角色 Node2D + Y-sort |
| 版本管理 | Git（本地）+ GitHub Desktop（可视化）+ GitHub 私有仓库 `HuiJieXingHen` |
| Agent 控制 | Godot MCP：打开/运行项目、读写场景与节点、捕获调试输出、截图 |
| 资源 | 占位阶段无美术；AI 生成资源（美术/音乐）按 §2.8、§5 规范后期接入 |

### 2.2 工程目录结构

```
D:\Dev\HuiJieXingHen\
├── project.godot
├── addons/dialogic/              # Dialogic 2 插件（随仓库提交）
├── scenes/
│   ├── main/                     # 主入口、全局串联
│   ├── map/                      # 地图、玩家、NPC、交互
│   ├── battle/                   # 战斗场景、演出
│   ├── recruit/                  # 唤星、招募、图鉴
│   └── ui/                       # HUD、任务面板
├── scripts/
│   ├── core/                     # 单例：DataManager/CSVParser/EventBus/GameState/Party/HeartBond/Inventory/SaveManager
│   ├── map/  battle/  dialogue/  data/  star_summon/  quests/  ui/
├── data/
│   └── csv/                      # ★ 所有配表源（UTF-8，首行列头）
├── dialogues/
│   └── timelines/                # Dialogic .dtl（由 CSV 转换工具生成，纳入版本管理）
├── tools/                        # 编辑器工具：csv_to_dialogic.gd 等（EditorScript）
├── assets/                       # AI 资源接入目录（各子目录 README 说明命名规范）
│   ├── sprites/characters/  portraits/  cg/  maps/tilesets/  skills/  ui/icons/  audio/
└── docs/                         # 推进表、验收报告、美术接入清单
```

### 2.3 核心数据模型（均由 CSV 行构造，字段可扩展）

- **CharacterData**：`id / name / faction（机律联邦·秘法评议会·太微仙盟）/ system（机律|秘法|玄门）/ hp / atk / def / spd / skill_small / skill_ult / portrait_id / sprite_id`
- **SkillData**：`id / name / type（small|ult）/ power / energy_cost / cutscene_id`
- **EnemyData**：`id / name / hp / atk / def / spd / ai_pattern / drop_sand`
- **StelliumData**：`id / name / main_stat / sub_stats / set_id`（MVP 仅入抽卡池）
- **SummonEntryData**：`entry_id / name / kind / gold / weight`
- **QuestData**：`quest_id / step / step_name / requirement / target / reward / next_step`

### 2.4 CSV 配表规范

| 表 | 路径 | 关键列 | MVP 初始行 |
| --- | --- | --- | --- |
| 角色 | `data/csv/characters.csv` | id,name,faction,system,hp,atk,def,spd,skill_small,skill_ult,portrait_id,sprite_id | 3（机律/秘法/玄门各一） |
| 技能 | `data/csv/skills.csv` | id,name,type,power,energy_cost,cutscene_id | 6（每角色小技能+终结技） |
| 敌人 | `data/csv/enemies.csv` | id,name,hp,atk,def,spd,ai_pattern,drop_sand | 1（灾蚀兽） |
| 星髓 | `data/csv/stellium.csv` | id,name,main_stat,sub_stats,set_id | 3（占位套装） |
| 抽卡池 | `data/csv/summon_pool.csv` | entry_id,name,kind,gold,weight | 6（星缘令/CG/材料/星髓） |
| 任务 | `data/csv/quests.csv` | quest_id,step,step_name,requirement,target,reward,next_step | 1（心契四步） |
| 台词 | `data/csv/dialogues_<章>.csv` | timeline_id,order,speaker_id,emotion,text,set_flag,flag_condition,choice_a,choice_b | 主线 1 + NPC 闲聊 |

**规则**：① UTF-8 编码（带 BOM 也行，解析器兼容）；② 逗号分隔，含逗号的字段用双引号包裹；③ 所有数值列缺省为 0，字符串列缺省为空，解析器容错不崩溃；④ 台词表是**唯一剧情文本源**，改台词只改 CSV → 重跑转换工具（见 T4.2）。

### 2.5 Dialogic 2 集成规范

- **Timeline**：`dialogues/timelines/*.dtl` 纯文本格式，由 `tools/csv_to_dialogic.gd` 从台词 CSV 生成；Dialogic 可视化编辑器可打开、可调试。
- **Character / Portrait**：在 Dialogic 插件内为每名觉醒者建 Character，Portrait 差分 = `emotion`（normal/happy/sad/angry 等），占位图用纯色 PNG（`assets/portraits/`）。
- **运行时**：`Dialogic.start(timeline_name)` 播放；监听 `Dialogic.timeline_ended`、`Dialogic.signal_event` 完成与剧情 flag 回写。
- **API 为准**：具体函数签名与文本语法以 Dialogic 2 官方文档（docs.dialogic.pro / `addons/dialogic` 内示例）为准，指令中不再逐字展开语法细节；语法错误集中在转换工具一处处理。
- **信号桥接**：Dialogic 的 `signal_event`（自定义信号事件）→ `EventBus` 转发 → `GameState` 写 flag，桥接层在 T4.2 实现。

### 2.6 Godot MCP 使用规范

- Agent 所有验证操作走 MCP（工具名**以你环境实际暴露的为准**，常见能力：打开编辑器/项目、打开场景、运行/停止项目、捕获调试输出、读写场景节点与属性、编辑器内执行脚本、截图）。
- **标准验证循环**：修改 → `run_project`（debug）→ 读取控制台输出/错误 → 截图（运行时画面）→ 检查场景树节点与属性 → 修复 → 复跑，直到验收项全过。
- **不依赖 GUI 的操作**：场景/脚本/配表文件可直接读写（MCP 与文件系统双通道），配表变更后跑 `run_project` 验证加载日志。
- 每卡验收都包含"通过 MCP 运行的证据"（控制台日志或截图），写进 commit 说明。

### 2.7 Git 工作流

- **仓库**：GitHub 私有仓库 `HuiJieXingHen`（首次创建/发布用 GitHub Desktop 完成一次，之后 agent 用 `git` CLI 提交推送，两者兼容同一仓库）。
- **.gitignore 必含**：`.godot/`、`*.import`、导出产物（`build/`、`*.exe` 等）、`user://` 数据；**不忽略**：`addons/dialogic`、`data/csv/`、`dialogues/timelines/`（`.dtl` 纯文本需入库）。
- **提交规范**：每个任务卡一个 commit，信息 `T0.1: 工程初始化`；一个阶段完成可打 tag（`v0.1-p0`，可选）。
- **push**：每卡完成后 `git push origin main`；冲突由用户用 GitHub Desktop 处理，或 agent 报告冲突清单。

### 2.8 AI 美术/音乐资源规范（接入演练在 T7.3）

- **美术**：AI 生成（即梦/豆包/Stable Diffusion 等）→ 统一风格词（等距 2.5D、Q 版三头身、二次元、统一主光源）→ 导出**透明底 PNG** → 按 §5.2 命名 → 对应 `assets/` 目录 → 由 ArtProvider 加载替换占位，业务代码零改动。
- **音乐**：AI 生成（Suno 等）→ `assets/audio/`：BGM `bgm_<scene>.ogg`（44.1kHz/16bit，建议 60~120s 循环段），音效 `sfx_<event>.ogg`（1~3s）。
- **合规**：使用自有生成资源，规避版权风险；AI 工具与风格词记录在 `docs/美术资源接入清单.md`。

***

## 3. 阶段总览与依赖关系

| 阶段 | 名称 | 任务数 | 预估轮次 | 依赖 |
| --- | --- | --- | --- | --- |
| P0 | 项目骨架与工具链 | 4 | 4~7 | — |
| P1 | 等距地图与移动 | 6 | 8~12 | P0 |
| P2 | 角色数据与队伍 | 3 | 5~7 | P0（可与 P1 并行） |
| P3 | 战斗系统 | 7 | 10~14 | P2 |
| P4 | Dialogic 剧情演出 | 4 | 8~12 | P1、P2（可与 P3 并行） |
| P5 | 心契任务 | 4 | 6~9 | P3、P4 |
| P6 | 唤星模拟 | 4 | 6~8 | P5 |
| P7 | 整合与验收 | 4 | 6~10 | 全部 |

```
graph TD
    P0[P0 项目骨架与工具链] --> P1[P1 等距地图与移动]
    P0 --> P2[P2 角色数据与队伍]
    P1 --> P4[P4 Dialogic 剧情演出]
    P2 --> P3[P3 战斗系统]
    P2 --> P4
    P3 --> P5[P5 心契任务]
    P4 --> P5
    P5 --> P6[P6 唤星模拟]
    P6 --> P7[P7 整合与验收]
```

**并行建议**：波次 1 = P0；波次 2 = P1 ∥ P2；波次 3 = P3 ∥ P4；波次 4 = P5；波次 5 = P6；波次 6 = P7。关键路径 ≈ P0 → P1 → P4 → P5 → P6 → P7。

***

## 4. 任务卡

> 每张卡「**【完整指令】**」可直接整块粘贴给 agent。公共约定（MCP 用法、Git 规范、CSV/Dialogic 规范）见 §2，不再逐卡重复；粘贴时如需可附加"遵循项目推进表 §2 公共约定"。

### P0 项目骨架与工具链

#### T0.1 工程初始化与工具链

| 字段 | 内容 |
| --- | --- |
| 目标 | Godot 4.7 工程、目录、Dialogic 2、Git 私有仓库、MCP 连通全部就绪 |
| 产出 | 可运行的工程骨架 + 首次 commit push |
| 依赖 | — |
| 接口预留 | `assets/` 各目录 README 写入 §2.8/§5 命名规范 |
| 预估 | 1~2 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T0.1 工程初始化与工具链
目标：在 D:\Dev\HuiJieXingHen 建立 Godot 4.7 工程骨架，装好 Dialogic 2，完成 Git 私有仓库首推，验证 Godot MCP 连通。
技术栈：Godot 4.7 · GDScript · Dialogic 2 · CSV 配表 · Git + GitHub 私有仓库 · Godot MCP。
前置：目录已存在；Godot MCP 已连接（先列出你环境中实际可用的 MCP 工具，后续验证统一用它）。

执行步骤：
1. 确认/初始化 Godot 4.7 工程：检查 project.godot 存在且版本为 4.7；无则用 MCP 或 godot --path 创建。设置主场景 res://scenes/main/Main.tscn（先建空 Main 场景）。
2. 建立目录结构（§2.2）：scenes/{main,map,battle,recruit,ui}、scripts/{core,map,battle,dialogue,data,star_summon,quests,ui}、data/csv/、dialogues/timelines/、tools/、assets 各子目录（每个 assets 子目录放 README.txt 写明命名规范，规范见项目推进表 §2.8/§5）。
3. 安装 Dialogic 2：从 Asset Library 安装到 addons/dialogic，Project Settings → Plugins 启用；确认编辑器出现 Dialogic 菜单。addons/dialogic 保留在仓库中。
4. 初始化 Git：git init；创建 .gitignore（至少忽略 .godot/、*.import、导出产物；不忽略 addons/dialogic、data/csv、dialogues/timelines）。
5. GitHub 私有仓库：若用户已通过 GitHub Desktop 创建并发布私有仓库 HuiJieXingHen 并关联本目录，则跳过；否则引导用户创建（或提供 gh 命令方案）。配置 git remote origin 为私有仓库地址。
6. MCP 连通验证：用 MCP 打开项目 → 运行一次空 Main 场景 → 捕获控制台输出确认无报错 → 停止运行。

产出：可打开的 Godot 4.7 工程骨架；目录齐全；Dialogic 2 启用；.gitignore 就绪；remote 指向私有仓库。

验收（全部通过）：
- [ ] project.godot 版本为 4.7，主场景 Main.tscn 可运行，MCP 运行无报错
- [ ] 目录结构与 assets README 齐全
- [ ] Dialogic 2 插件在 Plugins 中启用，编辑器可见 Dialogic 菜单
- [ ] git status 干净（首次 commit 后）；.gitignore 生效（.godot/ 未入库）
- [ ] 已 push 到 GitHub 私有仓库，远程分支与本地一致

提交：git commit -m "T0.1: 工程初始化与工具链" 并 push origin main。
```

#### T0.2 核心数据模型

| 字段 | 内容 |
| --- | --- |
| 目标 | 定义 CSV 行 → 数据对象模型 |
| 产出 | `scripts/core/data_models.gd` |
| 依赖 | T0.1 |
| 预估 | 1 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T0.2 核心数据模型
目标：按项目推进表 §2.3 实现数据类：CharacterData / SkillData / EnemyData / StelliumData / SummonEntryData / QuestData。
前置：T0.1 已通过。

执行步骤：
1. 新建 scripts/core/data_models.gd，定义上述类（RefCounted 即可，后续如需 Resource 再迁移）。
2. 每个类实现静态方法 from_csv_row(dict) -> 本类实例：按列名取值，数值用 int()/float() 容错转换（空值取默认：数值 0、字符串 ""），非法值打印警告但不中断。
3. 为 CharacterData 增加便捷方法：system_name()（机律/秘法/玄门）、faction_name()（机律联邦/秘法评议会/太微仙盟）。
4. 用 MCP 编辑器内执行脚本做冒烟测试：手工构造一行角色字典 → 生成实例 → 打印全部字段确认正确。

产出：data_models.gd；冒烟测试日志。

验收（全部通过）：
- [ ] 脚本无解析错误（MCP 编辑器内 execute 通过）
- [ ] 6 个类均可由字典构造，容错默认值正确
- [ ] 冒烟测试打印的字段与输入一致

提交：git commit -m "T0.2: 核心数据模型" 并 push。
```

#### T0.3 CSV 配表与加载管线

| 字段 | 内容 |
| --- | --- |
| 目标 | CSV 解析器 + DataManager + 全部初始配表 |
| 产出 | `data/csv/*.csv`（7 张表初始行）、`scripts/core/CSVParser.gd`、`scripts/core/DataManager.gd` |
| 依赖 | T0.2 |
| 接口预留 | 新增表只需在 DataManager 注册路径与模型，不污染业务代码 |
| 预估 | 2 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T0.3 CSV 配表与加载管线
目标：建立全部 CSV 配表（§2.4 七张表，含 MVP 初始行），实现自写 CSV 解析器与 DataManager 加载查询。
前置：T0.2 已通过。

执行步骤：
1. 建立 data/csv/ 下七张表，列头严格按 §2.4：
   - characters.csv：3 行（机律/秘法/玄门各一，id=awakened_mech_01 / awakened_arcane_01 / awakened_xian_01，name 填"待定"，faction/system 按设定填写，数值给占位值）
   - skills.csv：6 行（每角色小技能+终结技，cutscene_id 占位）
   - enemies.csv：1 行（corrosion_beast 灾蚀兽）
   - stellium.csv：3 行（占位套装）
   - summon_pool.csv：6 行（kind ∈ starlink_token/cg/material/stellium/stellium_material，其中星缘令与角色CG 设 gold=true，weight 建议合计约 5% 权重，数值可调）
   - quests.csv：1 个任务 4 步（heartbond_01：开启对话/赠礼/共同战斗/完成对话，requirement 与 target 用占位 id）
   - dialogues_main_01.csv、dialogues_npc_chat.csv：先建表头与 1~2 行示例（正式内容 T4.2/T4.3 填）
2. 实现 scripts/core/CSVParser.gd：parse(path) -> Array[Dictionary]；支持 UTF-8 BOM、CRLF、双引号包裹字段（含逗号/引号转义）、空行跳过；解析失败返回错误信息（文件+行号）而不崩溃。
3. 实现 scripts/core/DataManager.gd（Autoload）：启动时加载全部 CSV 到内存索引表；提供 get_character(id) / get_skill(id) / get_enemy(id) / get_summon_pool() / get_quest(quest_id) / get_dialogue_rows(timeline_id) 等查询；加载完成打印各表行数日志；注册到 Project Settings Autoload。
4. 用 MCP 运行项目，核对日志：characters=3、skills=6、enemies=1、stellium=3、summon_pool=6、quests=4 步；故意在某个 CSV 造一个坏行，确认报错定位到行号且项目不崩，改回后恢复。

产出：七张 CSV + CSVParser + DataManager（Autoload）。

验收（全部通过）：
- [ ] 运行日志各表行数与预期一致
- [ ] get_character("awakened_mech_01") 返回字段完整正确
- [ ] 坏行报错含文件与行号，项目不崩溃

提交：git commit -m "T0.3: CSV 配表与加载管线" 并 push。
```

#### T0.4 事件总线与全局状态

| 字段 | 内容 |
| --- | --- |
| 目标 | EventBus 信号 + GameState（资源/flag），预留 Dialogic 桥接 |
| 产出 | `scripts/core/EventBus.gd`、`scripts/core/GameState.gd` |
| 依赖 | T0.3 |
| 接口预留 | Dialogic 信号 → EventBus 转发层（T4.2 实现） |
| 预估 | 1 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T0.4 事件总线与全局状态
目标：实现 EventBus（全局信号）与 GameState（星砂/星缘令/剧情 flag），并预留 Dialogic 信号桥接接口。
前置：T0.3 已通过。

执行步骤：
1. EventBus（Autoload）声明信号：interact_requested（带 node）、dialogue_started / dialogue_finished、battle_started / battle_finished（带结果）、quest_updated（带 quest_id 与 step）、summon_completed、character_recruited（带 id）。
2. GameState（Autoload）：星砂 star_sand（int，默认 0）、星缘令 starlink_tokens（int）、剧情 flag 字典 flags: Dictionary（提供 set_flag/get_flag/has_flag）。
3. 预留桥接注释接口：dialogue_signal_bridge(event_name, data) —— T4.2 由 Dialogic signal_event 调用，本卡只留方法骨架与文档注释。
4. 用 MCP 运行一个临时测试：场景 A 发信号、场景 B 接收打印；GameState 读写值；确认 Autoload 顺序（EventBus 先于 GameState 等依赖方）。

产出：EventBus.gd、GameState.gd（均注册 Autoload）。

验收（全部通过）：
- [ ] 跨场景信号收发测试通过（控制台可证）
- [ ] GameState 读写正确，初始值 0/空
- [ ] dialogue_signal_bridge 骨架存在且注释说明用途

提交：git commit -m "T0.4: 事件总线与全局状态" 并 push。
```

### P1 等距地图与移动（占位色块）

#### T1.1 等距 TileMap 与色块 Tileset

| 字段 | 内容 |
| --- | --- |
| 目标 | 等距网格地图可渲染、可碰撞 |
| 产出 | `scenes/map/TestMap.tscn` + tileset 资源 |
| 依赖 | T0.1 |
| 接口预留 | tileset 源放 `assets/maps/tilesets/`，后期换真实砖块 |
| 预估 | 1~2 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T1.1 等距 TileMap 与色块 Tileset
目标：用 TileMapLayer 搭建等距网格地图，占位色块，障碍层带物理碰撞。
前置：T0.1 已通过。

执行步骤：
1. 新建 TestMap.tscn，根节点 Node2D；加 TileMapLayer（名称 Ground）。
2. 新建 tileset：新建 TileSet，TileShape = Isometric；新增两枚占位 tile（菱形色块）：ground（浅色，可通行）、obstacle（深色，带物理层 PhysicsLayer0 碰撞多边形）。
3. 用脚本或手绘铺设 24×24 的地面层：边缘一圈 obstacle 作围墙，内部散置若干 obstacle 作障碍（比例约 10%）。
4. 将 tileset 源保存到 assets/maps/tilesets/test_tileset.tres（占位路径规范）。
5. MCP：打开场景 → 运行 → 截图确认渲染无空洞、无 z-fighting（菱形间无缝隙）。

产出：TestMap.tscn、tileset 资源。

验收（全部通过）：
- [ ] 等距渲染正确，tile 之间无缝隙/重叠
- [ ] obstacle tile 的碰撞多边形存在（场景树可查）
- [ ] 运行截图可作为验收证据

提交：git commit -m "T1.1: 等距TileMap与色块Tileset" 并 push。
```

#### T1.2 2.5D 排序与遮挡

| 字段 | 内容 |
| --- | --- |
| 目标 | Y-sort 正确遮挡 |
| 产出 | TestMap 修改（Y-sort 生效） |
| 依赖 | T1.1 |
| 预估 | 1 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T1.2 2.5D 排序与遮挡
目标：启用 Y-sort，角色/装饰按 Y 轴正确遮挡。
前置：T1.1 已通过。

执行步骤：
1. TestMap 根节点开启 Y Sort（Y-sort 属性），地面与装饰层节点开启 y_sort_enabled。
2. 在 TestMap 放置 2 个"建筑"装饰占位：Node2D + 大色块（Polygon2D/ColorRect），y_sort_enabled = true，并放到 Ground 之后。
3. 临时放置一个测试角色（ColorRect 方块），在其 y 小于建筑时被建筑遮挡、大于建筑时遮挡建筑。
4. MCP：运行 → 手动把测试角色移到建筑前后（可用 MCP 输入模拟或脚本改 position）→ 截图两状态对比。

产出：TestMap（Y-sort 生效）。

验收（全部通过）：
- [ ] 角色在建筑"后方"（y 更小）被遮挡，逻辑 position 不变
- [ ] 截图两状态可对比验证

提交：git commit -m "T1.2: Y-sort遮挡" 并 push。
```

#### T1.3 玩家角色占位与移动

| 字段 | 内容 |
| --- | --- |
| 目标 | 等距网格自由移动、障碍碰撞 |
| 产出 | `scenes/map/Player.tscn`、`scripts/map/PlayerController.gd` |
| 依赖 | T1.1、T1.2 |
| 接口预留 | 视觉挂 `VisualRoot/Sprite`，后期换 Q 版精灵 |
| 预估 | 1~2 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T1.3 玩家角色占位与移动
目标：实现可在地图自由移动、不穿障碍的占位玩家（WASD/方向键八方向）。
前置：T1.1、T1.2 已通过。

执行步骤：
1. 新建 Player.tscn：CharacterBody2D 根，子节点 VisualRoot/Sprite（ColorRect 方块 + 朝向三角标记），CollisionShape2D 圆形，脚本 PlayerController.gd。
2. 移动：速度 200，八方向输入（WASD + 方向键），move_and_slide；碰撞层与 obstacle 的物理层互斥。
3. 朝向：根据最后移动方向翻转 Sprite 或旋转朝向三角。
4. 移动表现占位：行走时 Sprite 明暗/尺寸轻微呼吸（模拟走路动画）。
5. MCP：运行 TestMap，把 Player 实例加入场景；截图：自由移动正常、撞障碍停下。

产出：Player.tscn、PlayerController.gd。

验收（全部通过）：
- [ ] 八方向移动流畅，方向反馈正确
- [ ] 无法穿过障碍（被碰撞停下）
- [ ] 无控制时的输入残留（切窗口后不漂移）

提交：git commit -m "T1.3: 玩家移动" 并 push。
```

#### T1.4 相机跟随

| 字段 | 内容 |
| --- | --- |
| 目标 | 平滑跟随 + 边界限制 |
| 产出 | Player.tscn 修改（Camera2D） |
| 依赖 | T1.3 |
| 预估 | 1 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T1.4 相机跟随
目标：Camera2D 平滑跟随玩家，不越地图边界。
前置：T1.3 已通过。

执行步骤：
1. Player.tscn 加 Camera2D 子节点：position_smoothing 开启（speed 约 5~8），当前模式 enabled。
2. 将 Camera2D 的 limit_left/top/right/bottom 对齐 TestMap 边界（与地图像素尺寸一致）。
3. 缩放：zoom 设为 (0.9, 0.9)（等距下视野更完整，可调）。
4. MCP：运行 → 玩家移动到四角 → 截图确认画面不越界、跟随平滑无抖动。

产出：Player.tscn（含 Camera2D）。

验收（全部通过）：
- [ ] 跟随平滑，无卡顿抖动
- [ ] 地图四角玩家可见，画面不露出地图外空白
- [ ] 缩放后菱形贴图无变形

提交：git commit -m "T1.4: 相机跟随" 并 push。
```

#### T1.5 交互系统占位

| 字段 | 内容 |
| --- | --- |
| 目标 | 靠近 NPC 提示 + 按键交互（对接 Dialogic 入口预留） |
| 产出 | `scenes/map/Interactable.tscn`、`scripts/map/Interactable.gd` |
| 依赖 | T1.3 |
| 接口预留 | 交互动作字段（talk/open）由业务注册，后续接 Dialogic timeline 或战斗/拾取 |
| 预估 | 1~2 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T1.5 交互系统占位
目标：玩家靠近 NPC 时显示头顶提示，按键（E/空格）触发 interact_requested 信号，携带对象引用。
前置：T1.3 已通过。

执行步骤：
1. Interactable.tscn：Area2D + CollisionShape2D（触发范围约 60px）+ 提示标记（默认隐藏：色块三角 + TextLabel）。
2. Interactable.gd：属性 npc_id、display_name、action_type（占位，默认 "talk"）；玩家进入/离开 area 时显示/隐藏提示；玩家在范围内按 E 或空格 → EventBus.interact_requested.emit(self)。
3. 在 TestMap 放 2 个测试 NPC（色块 + Interactable），用 meta 存 npc_id。
4. MCP：运行 → 靠近/远离 NPC 截图提示显隐 → 按键确认信号发出（临时监听打印）。

产出：Interactable.tscn、Interactable.gd。

验收（全部通过）：
- [ ] 靠近提示出现、远离消失
- [ ] 范围内按键触发信号且带正确对象；范围外无效
- [ ] 多个 NPC 同时存在互不干扰

提交：git commit -m "T1.5: 交互系统占位" 并 push。
```

#### T1.6 营地地图成品与布置

| 字段 | 内容 |
| --- | --- |
| 目标 | MVP 地图（汇界营地）：漫游 + 3 觉醒者 NPC + 主线触发区 + 拾取点 |
| 产出 | `scenes/map/CampMap.tscn` |
| 依赖 | T1.4、T1.5 |
| 预估 | 1~2 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T1.6 营地地图成品与布置
目标：制作 MVP 可漫游的汇界营地地图，布置 3 名觉醒者 NPC 占位、主线触发区、道具拾取点。
前置：T1.4、T1.5 已通过。

执行步骤：
1. 以 TestMap 为基础另存为 CampMap.tscn，扩展为营地布局：广场开阔区 + 周边障碍围墙 + 房屋/树装饰占位（色块，y_sort_enabled）。
2. 放置 3 名觉醒者 NPC：色块 + 头顶名字标签（名字占位"待定"，npc_id = awakened_mech_01 / awakened_arcane_01 / awakened_xian_01），各挂 Interactable；NPC 站位分散（广场三点）。
3. 主线触发区：Area2D（覆盖广场入口），信号 body_entered → EventBus 发 interact_requested（携带 main_trigger 标记，供 T4.3 接 Dialogic）。
4. 道具拾取点：1 个"星砂结晶"占位（发光色块 + Interactable），拾取后写入 GameState（供 T5.3 赠礼用，本卡先做"拾取→入背包"骨架，Inventory 由 T6.1 完善）。
5. 将 CampMap 设为主场景（或由 Main 切换进入）。
6. MCP：全图漫游截图验证无卡死死角；三 NPC 均可交互；触发区/拾取点可进入。

产出：CampMap.tscn（主场景）。

验收（全部通过）：
- [ ] 全图漫游流畅，无死角/卡墙
- [ ] 3 个 NPC 交互提示正常（npc_id 正确）
- [ ] 进入触发区发信号；拾取点交互生效且背包有记录

提交：git commit -m "T1.6: 营地地图成品与布置" 并 push。
```

### P2 角色数据与队伍（可与 P1 并行）

#### T2.1 三名觉醒者数据（CSV）

| 字段 | 内容 |
| --- | --- |
| 目标 | 三体系觉醒者 CSV 数据成型 |
| 产出 | `data/csv/characters.csv`、`skills.csv` 正式内容 |
| 依赖 | T0.3 |
| 接口预留 | CSV 可后续加 live2d_config / model_path 列，旧行不受影响 |
| 预估 | 1 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T2.1 三名觉醒者数据（CSV）
目标：完善 characters.csv 与 skills.csv：三体系各一名觉醒者，技能完整，数值占位可调。
前置：T0.3 已通过。

执行步骤：
1. characters.csv 三行（T0.3 已有骨架，补全字段）：
   - awakened_mech_01：system=机律，faction=机律联邦
   - awakened_arcane_01：system=秘法，faction=秘法评议会
   - awakened_xian_01：system=玄门，faction=太微仙盟
   - name 保持"待定"（后续由你/策划在 CSV 直接改）；hp/atk/def/spd 给占位值（建议 hp 100/120/110，atk 12/15/13，def 10/8/12，spd 10/12/9，可调）
2. skills.csv 六行：每人 1 小技能（type=small，energy_cost=1，power≈1.2）+ 1 终结技（type=ult，energy_cost=3，power≈2.5）；cutscene_id 占位（如 mech_01_ult）。
3. 用 MCP 运行项目，确认 DataManager 日志 characters=3、skills=6；get_character 返回三体系正确。

产出：正式角色/技能 CSV。

验收（全部通过）：
- [ ] 三角色体系分别为机律/秘法/玄门
- [ ] 每人小技能+终结技齐全，数值可被 DamageCalc 读取（数值类型正确）
- [ ] 加载日志与查询验证通过

提交：git commit -m "T2.1: 三名觉醒者数据" 并 push。
```

#### T2.2 队伍系统

| 字段 | 内容 |
| --- | --- |
| 目标 | 3 人编队 + 同行临时槽位 + 体系组合判定 |
| 产出 | `scripts/core/Party.gd`（Autoload） |
| 依赖 | T2.1 |
| 预估 | 1~2 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T2.2 队伍系统
目标：实现 Party 单例：3 人编队、同行临时槽位、体系组合查询（供战斗共振/汇流/混元判定）。
前置：T2.1 已通过。

执行步骤：
1. Party.gd（Autoload）：members: Array[String]（角色 id，上限 3）、companion_id: String（同行角色 id，占用 1 个位置）。
2. API：add_member(id) / remove_member(id) / is_full() / has_member(id) / set_companion(id) / clear_companion() / get_members()。
3. 体系组合查询 team_systems() -> Dictionary：{systems: Array, all_same: bool, has_all_three: bool}（three = 机律/秘法/玄门齐全）。
4. 用 MCP 编辑器内执行脚本测试三种编组：全同体系 → all_same=true；三系齐 → has_all_three=true；两系 → 两者皆 false。

产出：Party.gd（Autoload）。

验收（全部通过）：
- [ ] 增删/满员/查询 API 行为正确，上限 3
- [ ] 同行角色占用槽位可设置/清除
- [ ] 三种编组的体系组合判定正确

提交：git commit -m "T2.2: 队伍系统" 并 push。
```

#### T2.3 地图角色占位表现

| 字段 | 内容 |
| --- | --- |
| 目标 | 队伍成员在地图可见（跟随玩家） |
| 产出 | `scripts/map/PartyFollower.gd` |
| 依赖 | T2.2、T1.3 |
| 接口预留 | 外观走 ArtProvider.get_character_sprite(id)（§5） |
| 预估 | 1 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T2.3 地图角色占位表现
目标：队伍成员以占位色块跟随玩家移动，外观经 ArtProvider 获取。
前置：T2.2、T1.3 已通过。

执行步骤：
1. 实现 ArtProvider 单例骨架（§5.1）：get_character_sprite(id) 当前返回占位色块（ColorRect 配置：按角色体系给不同颜色 + 名字），后续替换为真实资源加载。注册 Autoload。
2. PartyFollower.gd：监听 Party.members 变化，为每个成员生成占位精灵（名字标签），按入队顺序排列在玩家身后（间距约 48px），跟随移动（平滑插值）。
3. 同行角色（companion）同样显示，但头顶加"同行"小标签区分。
4. MCP：运行 CampMap → 用脚本把 3 名觉醒者加入 Party → 截图验证 3 名跟随者 + 名字正确；添加/移除成员时跟随者实时变化。

产出：ArtProvider.gd（骨架）、PartyFollower.gd。

验收（全部通过）：
- [ ] 队伍成员按序跟随，不丢队、不重叠
- [ ] 增删成员实时反映到地图
- [ ] 同行角色有"同行"标签

提交：git commit -m "T2.3: 地图角色占位表现" 并 push。
```

### P3 战斗系统

#### T3.1 敌人占位数据（灾蚀兽 · CSV）

| 字段 | 内容 |
| --- | --- |
| 目标 | 灾蚀兽 1 种（CSV） |
| 产出 | `data/csv/enemies.csv` 正式内容 |
| 依赖 | T0.3 |
| 预估 | 1 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T3.1 敌人占位数据（灾蚀兽）
目标：完善 enemies.csv：灾蚀兽属性 + 简单 AI + 星砂掉落。
前置：T0.3 已通过。

执行步骤：
1. enemies.csv 一行：id=corrosion_beast，name=灾蚀兽，hp≈150、atk≈10、def≈6、spd≈8（占位可调），ai_pattern=simple（描述：70% 普攻 / 30% 小技能），drop_sand=30。
2. MCP 运行项目确认加载 enemies=1；get_enemy 返回字段完整。

产出：enemies.csv。

验收（全部通过）：
- [ ] 加载成功，字段类型正确
- [ ] drop_sand 可被战斗结算读取

提交：git commit -m "T3.1: 灾蚀兽敌人数据" 并 push。
```

#### T3.2 战斗状态机

| 字段 | 内容 |
| --- | --- |
| 目标 | 完整回合循环（日志驱动，便于调数值） |
| 产出 | `scripts/battle/BattleManager.gd` |
| 依赖 | T2.1、T3.1 |
| 预估 | 1~2 轮 |

【完整指令 · 粘贴给 Agent】

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

| 字段 | 内容 |
| --- | --- |
| 目标 | 攻击 / 小技能 / 终结技 + 能量 + 目标选择 |
| 产出 | `scripts/battle/BattleUnit.gd`、`BattleCommand.gd` |
| 依赖 | T3.2 |
| 预估 | 1~2 轮 |

【完整指令 · 粘贴给 Agent】

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

| 字段 | 内容 |
| --- | --- |
| 目标 | 公式落地 + 战斗日志数值可验 |
| 产出 | `scripts/battle/DamageCalc.gd` |
| 依赖 | T3.3 |
| 预估 | 1 轮 |

【完整指令 · 粘贴给 Agent】

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

| 字段 | 内容 |
| --- | --- |
| 目标 | 按设定三态互斥机制 |
| 产出 | `scripts/battle/PartyBonus.gd` |
| 依赖 | T3.4、T2.2 |
| 预估 | 1 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T3.5 队伍机制判定（共振/汇流/混元）
目标：按《初期设定》实现三态互斥：共振（全同体系）/ 汇流（异体系且三系未齐）/ 混元（三系齐全，不触发前两者）。
前置：T3.4、T2.2 已通过。

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

#### T3.6 战斗演出占位（小技能立绘 / 终结技动画）

| 字段 | 内容 |
| --- | --- |
| 目标 | 演出流程成立，接口预留动态立绘/专属动画 |
| 产出 | `scenes/battle/SkillCutscene.tscn`、`scripts/battle/SkillCutscene.gd` |
| 依赖 | T3.4 |
| 接口预留 | PortraitRect（替换动态立绘）、CutsceneAnimation（替换专属动画） |
| 预估 | 1~2 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T3.6 战斗演出占位
目标：小技能切"半身立绘占位"，终结技播"专属动画占位"，演出可暂停战斗、可跳过。
前置：T3.4 已通过。

执行步骤：
1. SkillCutscene.tscn：全屏层（CanvasLayer）：PortraitRect（TextureRect，当前纯色块+角色名+技能名）+ CutsceneAnimation（AnimationPlayer，当前做色块缩放/变色/闪屏占位动画）+ 跳过提示。
2. SkillCutscene.gd：play(character_id, skill_id)；按 skill.type 分支：small → 立绘占位 0.8s；ult → 专属动画占位 2s + 大字"终结技：<技能名>"；空格跳过；播完发 finished 信号。
3. BattleManager 接入：执行指令时暂停回合推进 → 播演出 → 继续；立绘来源走 ArtProvider.get_portrait(id, emotion)（占位）。
4. MCP：运行战斗 → 触发小技能与终结技 → 截图演出画面 → 空格跳过 → 战斗继续。

产出：SkillCutscene.tscn、SkillCutscene.gd。

验收（全部通过）：
- [ ] 小技能/终结技演出分别触发且可结束
- [ ] 跳过可用，演出后战斗状态正确继续
- [ ] 演出画面含角色名与技能名，可作为占位证据

提交：git commit -m "T3.6: 战斗演出占位" 并 push。
```

#### T3.7 战斗场景接入与奖励

| 字段 | 内容 |
| --- | --- |
| 目标 | 地图 → 战斗 → 结算（星砂）闭环，供心契"共同战斗"复用 |
| 产出 | `scenes/battle/Battle.tscn`、`scripts/battle/BattleController.gd` |
| 依赖 | T3.5、T3.6、T1.5 |
| 预估 | 1~2 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T3.7 战斗场景接入与奖励
目标：实现战斗场景：从地图触发进入、三人 vs 灾蚀兽、胜利结算星砂、可复用于心契任务。
前置：T3.5、T3.6、T1.5 已通过。

执行步骤：
1. Battle.tscn：战斗舞台（色块地板）+ 敌我站位（我方三人左侧、敌方右侧，色块占位）+ BattleController.gd。
2. BattleController：监听 EventBus.battle_started(party_ids, enemy_ids, context) → 加载场景 → 驱动 BattleManager；胜利 → Inventory 加星砂（drop_sand）→ 发 battle_finished(win)；失败 → 重试提示。
3. 地图接入：CampMap 放"战斗触发点"（或由心契任务步骤触发），触发 → battle_started（当前队伍 3 人 vs corrosion_beast）；context 参数支持传入 quest_id（供 T5.3 判定"共同战斗"步骤完成）。
4. 战斗结束回地图：切换场景或原位恢复，状态干净。
5. MCP：从地图完整打一场（出手→演出→胜利→星砂到账→回地图），截图关键节点；失败流程测试一次不卡死。

产出：Battle.tscn、BattleController.gd。

验收（全部通过）：
- [ ] 地图进入战斗全流程可走通，星砂正确入背包
- [ ] context=quest_id 时可被 QuestRunner 识别（接口存在）
- [ ] 失败重试不卡死

提交：git commit -m "T3.7: 战斗场景接入与奖励" 并 push。
```

### P4 Dialogic 剧情演出

#### T4.1 Dialogic 2 集成与冒烟验证

| 字段 | 内容 |
| --- | --- |
| 目标 | Dialogic 2 可运行时播放 timeline（角色/表情/立绘占位） |
| 产出 | 首个 `.dtl`（smoke_test）+ Character/Portrait 配置 |
| 依赖 | T0.1（Dialogic 已装） |
| 接口预留 | Portrait 占位图路径走 §5.2 命名 |
| 预估 | 2 轮 |

【完整指令 · 粘贴给 Agent】

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

#### T4.2 CSV 台词表 → Dialogic timeline 转换管线

| 字段 | 内容 |
| --- | --- |
| 目标 | 台词以 CSV 为唯一源，一键生成 .dtl；Dialogic 信号桥接 flag 回写 |
| 产出 | `tools/csv_to_dialogic.gd`（EditorScript）、`data/csv/dialogues_*.csv` 模板、桥接脚本 |
| 依赖 | T4.1 |
| 接口预留 | 新增章节台词 = 新增 CSV + 重跑工具 |
| 预估 | 2 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T4.2 CSV台词表 → Dialogic timeline 转换管线
目标：实现从台词 CSV 生成 Dialogic .dtl 的转换工具（幂等可重跑），并实现 Dialogic 信号 → EventBus → GameState 的 flag 桥接。
前置：T4.1 已通过。文本语法以 Dialogic 官方 Timeline Text Syntax 为准，由转换工具统一产出，不在别处手写语法。

执行步骤：
1. 台词 CSV 列规范（§2.4）：timeline_id, order, speaker_id, emotion, text, set_flag, flag_condition, choice_a, choice_b。规则：order 决定行序；flag_condition 非空时该行仅在 GameState 满足该 flag 才显示（转换工具生成条件事件）；set_flag 非空时该行播放后写 GameState（生成 Dialogic 信号事件）；choice_a/choice_b 生成简单选项跳转（可选，MVP 主线可不填）。
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

| 字段 | 内容 |
| --- | --- |
| 目标 | 主线闭环：穿越 → 营地 → 依次邂逅 3 人（Dialogic 演出 + flag 落库） |
| 产出 | `data/csv/dialogues_main_01.csv`、`main_01.dtl`、触发脚本 |
| 依赖 | T4.2、T1.6 |
| 预估 | 2 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T4.3 主线剧情 1 段（邂逅 3 名觉醒者）
目标：用 CSV + Dialogic 实现主线第一段：异乡人穿越开场 → 营地 → 依次邂逅 3 名觉醒者 → 目标提示；地图触发区进入；flag 防重播。
前置：T4.2、T1.6 已通过。

执行步骤：
1. 在 Dialogic 中为 3 名觉醒者建 Character（id 与 CSV 角色 id 一致），各配 emotion 占位 Portrait（normal/happy/sad/angry 纯色图，路径 §5.2 规范）。
2. 编写 data/csv/dialogues_main_01.csv：
   - 开场：无角色旁白 3 句（异乡人穿越、落地营地）
   - 依次邂逅 3 人：每人 5~8 句，穿插 emotion 切换（如初见 normal → 惊讶 happy/sad），最后一句 set_flag=met_awakened_mech_01（三人依次 met_<id>）
   - 结尾旁白 2 句目标提示，set_flag=main_01_done
3. 跑 csv_to_dialogic 生成 main_01.dtl；Dialogic 编辑器打开确认。
4. 触发：CampMap 主线触发区 → Dialogic.start("main_01")；开场时把玩家移动锁定/相机聚焦（占位表现）；播放结束释放控制。
5. 防重播：GameState 检查 main_01_done，已完则触发区不再播放（改为提示文字）。
6. MCP：走到触发区 → 完整播放 → 截图邂逅画面 → 确认 met_* 与 main_01_done flag 落库 → 重进触发区不再播放。

产出：dialogues_main_01.csv、main_01.dtl、触发脚本。

验收（全部通过）：
- [ ] 三场邂逅对话完整播放，姓名/阵营/台词/立绘正确（截图）
- [ ] 3 个 met_<id> 与 main_01_done flag 全部写入
- [ ] 重走触发区不重播
- [ ] 剧情播放期间玩家输入被正确锁定/恢复

提交：git commit -m "T4.3: 主线剧情一段" 并 push。
```

#### T4.4 NPC 闲聊与日常接口占位

| 字段 | 内容 |
| --- | --- |
| 目标 | NPC 可对话（含 flag 分支）+ 日常事件接口占位 |
| 产出 | `dialogues_npc_chat.csv`、`EventScheduler.gd`（占位） |
| 依赖 | T4.3 |
| 预估 | 1 轮 |

【完整指令 · 粘贴给 Agent】

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

| 字段 | 内容 |
| --- | --- |
| 目标 | 邂逅→心契开启→同行→满阶 状态流转 |
| 产出 | `scripts/core/HeartBond.gd`（Autoload） |
| 依赖 | T4.3（读取 met\_<id> flag） |
| 预估 | 1 轮 |

【完整指令 · 粘贴给 Agent】

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

| 字段 | 内容 |
| --- | --- |
| 目标 | 心契角色临时入队可出战 |
| 产出 | `scripts/quests/CompanionManager.gd` |
| 依赖 | T5.1、T2.2、T3.7 |
| 预估 | 1 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T5.2 同行机制
目标：心契任务开启时目标角色以"同行"状态临时入队，可参与战斗与探索；任务完成/中断可离队。
前置：T5.1、T2.2、T3.7 已通过。

执行步骤：
1. CompanionManager.gd：on_quest_start(quest_id, character_id) → Party.set_companion(character_id)；on_quest_complete / on_quest_abort → clear_companion（任务完成满阶后由玩家决定是否正式招募，见 T6.3）。
2. 同行角色出战：T3.7 战斗入口读取 Party.get_members()（含同行），无需额外改动。
3. 地图表现：T2.3 已支持同行标签（确认生效即可）。
4. MCP 冒烟：开启心契任务 → 同行入队 → 进战斗（同行在队且可行动）→ 完成任务 → 同行清除。

产出：CompanionManager.gd。

验收（全部通过）：
- [ ] 同行角色入队且战斗可出战（日志）
- [ ] 任务完成/中断后同行状态正确清除
- [ ] 与 Party 槽位上限正确交互（满员时同行处理不崩溃）

提交：git commit -m "T5.2: 同行机制" 并 push。
```

#### T5.3 心契任务 1 个（quests.csv 驱动）

| 字段 | 内容 |
| --- | --- |
| 目标 | 完整可推进的心契任务线（四步） |
| 产出 | `data/csv/quests.csv` 正式内容、`scripts/quests/QuestRunner.gd` |
| 依赖 | T5.2、T3.7、T1.6 |
| 预估 | 2 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T5.3 心契任务1个（quests.csv驱动）
目标：实现 QuestRunner 与 heartbond_01 任务线（建议选秘法系 awakened_arcane_01）：开启对话 → 赠礼 → 共同战斗 → 完成对话 → 满阶。
前置：T5.2、T3.7、T1.6 已通过。

执行步骤：
1. quests.csv 补全 heartbond_01 四步（列：quest_id,step,step_name,requirement,target,reward,next_step）：
   - step1 开启对话：requirement=met_awakened_arcane_01；target=与 NPC 对话（触发其心契 timeline）
   - step2 赠礼：requirement=背包有 star_sand_crystal（T1.6 拾取物）；target=赠礼对话，reward=消耗道具
   - step3 共同战斗：requirement=无；target=触发 battle_started（context=heartbond_01）并胜利
   - step4 完成对话：requirement=step3 完成；target=结尾对话，reward=心契满阶
2. 为秘法角色写心契对话 CSV（dialogues_heartbond_01.csv）：开场/赠礼/结尾三段，set_flag 驱动步骤（如 hb01_step2_done）。
3. QuestRunner.gd：get_current_step(quest_id) / advance(quest_id, event) / is_complete；监听 EventBus（dialogue_finished、battle_finished、inventory 变化）自动推进；步骤未满足时 NPC 给出引导台词（不同 flag 分支）。
4. 完成 step4 → HeartBond.complete(id) → bonded；发 quest_updated。
5. MCP 全流程：邂逅 → 领任务 → 拾取结晶 → 赠礼 → 共同战斗 → 结尾 → 状态 bonded，每步日志/截图。

产出：quests.csv、QuestRunner.gd、dialogues_heartbond_01.csv。

验收（全部通过）：
- [ ] 四步严格按序推进，无法跳步（未满足条件时引导正确）
- [ ] 完成后 HeartBond=bonded，can_recruit=true
- [ ] 赠礼正确消耗道具；共同战斗胜利计入步骤

提交：git commit -m "T5.3: 心契任务一条" 并 push。
```

#### T5.4 任务面板占位

| 字段 | 内容 |
| --- | --- |
| 目标 | 极简任务追踪 UI |
| 产出 | `scenes/ui/QuestPanel.tscn` |
| 依赖 | T5.3 |
| 预估 | 1 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T5.4 任务面板占位
目标：HUD 任务面板：显示当前任务名/步骤/目标，监听 quest_updated 实时刷新。
前置：T5.3 已通过。

执行步骤：
1. QuestPanel.tscn：CanvasLayer + 面板（背景色块），显示任务名/当前步骤名/目标描述三行文本；默认隐藏，按 Q 或 Tab 切换显隐。
2. 监听 EventBus.quest_updated → 从 QuestRunner 取最新步骤刷新文本；无任务时显示空态"暂无任务"。
3. 接入 Main/CampMap HUD。
4. MCP：运行 → 推进心契任务各步骤 → 截图面板随步骤更新 → 无任务时空态正确。

产出：QuestPanel.tscn。

验收（全部通过）：
- [ ] 步骤推进面板同步更新（截图）
- [ ] 开关显隐正常，无任务时空态正确

提交：git commit -m "T5.4: 任务面板占位" 并 push。
```

### P6 唤星模拟

#### T6.1 资源与背包系统

| 字段 | 内容 |
| --- | --- |
| 目标 | 星砂/星缘令/道具/图鉴管理，各获取途径接通 |
| 产出 | `scripts/core/Inventory.gd`（Autoload） |
| 依赖 | T0.4、T3.7、T5.3 |
| 预估 | 1 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T6.1 资源与背包系统
目标：Inventory 单例：星砂、星缘令、道具、CG 图鉴；获取途径（战斗/剧情/任务/拾取）全部接通。
前置：T0.4、T3.7、T5.3 已通过。

执行步骤：
1. Inventory.gd（Autoload）：star_sand:int、starlink_tokens:int、items: Dictionary（道具 id->数量，含 star_sand_crystal）、cg_collection: Array[String]。
2. API：add_sand(n)/spend_sand(n)->bool、add_token(n)/spend_token(n)->bool、add_item(id,n)/has_item(id,n)/remove_item(id,n)、unlock_cg(id)/has_cg(id)。
3. 途径接通：T3.7 胜利奖励 → add_sand；T4.3 主线完成奖励 → add_sand；T5.3 任务奖励/赠礼消耗 → add_item/remove_item；T1.6 拾取 → add_item。
4. MCP 冒烟：各途径触发后数值正确；spend 不足返回 false 且不为负。

产出：Inventory.gd（Autoload）。

验收（全部通过）：
- [ ] 各获取途径后数值正确（日志）
- [ ] 消耗不足不产生负数
- [ ] CG 解锁/查询正确

提交：git commit -m "T6.1: 资源与背包系统" 并 push。
```

#### T6.2 唤星抽卡逻辑（summon_pool.csv）

| 字段 | 内容 |
| --- | --- |
| 目标 | 通用池概率可配置、可验证 |
| 产出 | `scripts/star_summon/SummonManager.gd` |
| 依赖 | T6.1 |
| 预估 | 1~2 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T6.2 唤星抽卡逻辑
目标：实现 SummonManager：按 summon_pool.csv 权重随机抽取，消耗星砂，出金判定（星缘令/角色CG），结果入背包。
前置：T6.1 已通过。

执行步骤：
1. 确认 summon_pool.csv（T0.3 已建）权重配置合理：出金条目（kind=starlink_token / cg）gold=true，建议出金总权重约 5%（可调）。
2. SummonManager.gd：single_draw() -> SummonEntryData：按权重随机选 1 条；消耗星砂（单抽建议 100，读取配置常量）；结果写入 Inventory（星缘令/材料/星髓；CG → unlock_cg）；发 EventBus.summon_completed(result)。
3. 提供 draw_n(n) 供模拟与连抽。
4. MCP 冒烟：跑 1000 次模拟，输出各 kind 占比；与权重配置比对（±2% 容差）；确认星砂扣减与入包一致。

产出：SummonManager.gd。

验收（全部通过）：
- [ ] 1000 次模拟各档位占比与权重一致（日志统计）
- [ ] 星砂扣减正确，结果入包一致
- [ ] 星砂不足时拒绝抽取并返回原因

提交：git commit -m "T6.2: 唤星抽卡逻辑" 并 push。
```

#### T6.3 招募解锁逻辑

| 字段 | 内容 |
| --- | --- |
| 目标 | 星缘令 + 心契满阶 → 招募；缺一正确拒绝 |
| 产出 | `scripts/recruit/RecruitManager.gd`、`scenes/recruit/RecruitUI.tscn` |
| 依赖 | T6.2、T5.1 |
| 预估 | 1~2 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T6.3 招募解锁逻辑
目标：招募界面：校验"持有对应星缘令 + HeartBond=bonded"，满足则入队，不满足给出缺项提示；未邂逅角色显示"？？？"。
前置：T6.2、T5.1 已通过。

执行步骤：
1. RecruitManager.gd：try_recruit(character_id) -> {ok, reason}：依次校验 ① 已邂逅（无 met flag → "？？？"）② HeartBond.can_recruit（否则提示"需先完成心契任务"）③ 持有对应星缘令（否则提示"缺少星缘令，可前往唤星"）；通过 → Party.add_member + Inventory.spend_token + EventBus.character_recruited。
2. 星缘令与角色对应：约定 token id = starlink_token_<char_id>（或通用星缘令，建议通用星缘令，MVP 简化为通用令牌即可）。
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

| 字段 | 内容 |
| --- | --- |
| 目标 | 出金惊喜 + CG 收藏界面 |
| 产出 | `scenes/recruit/SummonScene.tscn`、`CgGallery.tscn` |
| 依赖 | T6.2 |
| 接口预留 | CG 查看区预留高清图插槽（§5.2） |
| 预估 | 1~2 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T6.4 抽卡演出与图鉴占位
目标：抽卡演出（色块转场+出金反馈）与 CG 图鉴（收藏/查看占位）。
前置：T6.2 已通过。

执行步骤：
1. SummonScene.tscn：色块转场（1s）→ 揭示结果：出金（kind=starlink_token/cg）→ 金色闪屏 + 大字"星缘令 / 角色CG"；普通 → 普通反馈（道具名）；连续抽取支持连点；星砂不足禁用按钮并提示。
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

### P7 整合与验收

#### T7.1 全流程串联

| 字段 | 内容 |
| --- | --- |
| 目标 | 单次游玩走通 MVP 闭环（含数值平衡） |
| 产出 | Main 全局串联 + 数值平衡表 |
| 依赖 | 全部 |
| 预估 | 2~3 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T7.1 全流程串联
目标：新游戏 → 漫游 → 主线邂逅 3 人 → 心契任务 → 唤星抽星缘令 → 招募 → 三系编队触发混元 → 终战通关；保证资源数值必然可通。
前置：P0~P6 全部验收通过。

执行步骤：
1. Main 全局串联：标题/新游戏入口 → CampMap → 各系统按序触发（§4 依赖链）→ 通关展示（终战胜利结算界面占位）。
2. 数值平衡核对（重点）：统计 MVP 全程星砂总获取（主线奖励+战斗掉落+任务奖励+拾取）≥ 抽卡成本 × 2（单抽 100），确保玩家必能抽到星缘令；记录在 docs/数值平衡表.md（各来源数值+合计）。
3. 终战：招募后队伍 3 人三系 → 触发混元（T3.5）→ 打灾蚀兽（可调强）→ 通关。
4. MCP 完整回归：从新游戏到通关全程录像式走查（关键节点截图），日志记录各关键事件（邂逅/心契/抽卡/招募/混元/通关）。

产出：Main 串联场景、docs/数值平衡表.md。

验收（全部通过）：
- [ ] 单次游玩从头到尾无阻塞走通（回归日志）
- [ ] 数值平衡表显示星砂总收入 ≥ 抽卡成本×2
- [ ] 混元机制在终战生效（日志 [BONUS]）
- [ ] 通关界面出现且可返回

提交：git commit -m "T7.1: 全流程串联" 并 push。
```

#### T7.2 存档系统

| 字段 | 内容 |
| --- | --- |
| 目标 | 进度持久化（资源/队伍/flag/图鉴/心契） |
| 产出 | `scripts/core/SaveManager.gd` |
| 依赖 | T7.1 |
| 预估 | 1~2 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T7.2 存档系统
目标：SaveManager：序列化 GameState/Party/HeartBond/Inventory 到 user://save.json，自动+手动存档，读档恢复。
前置：T7.1 已通过。

执行步骤：
1. SaveManager.gd：save() 汇总（GameState 资源与 flags、Party members/companion、HeartBond states、Inventory 全部、CG 图鉴、当前场景）→ JSON → user://save.json；load() 反向恢复并校验版本字段（version=1）。
2. 自动存档点：主线完成、心契完成、战斗胜利、抽卡后；手动存档：菜单按键。
3. 损坏档处理：解析失败提示并回退默认，不崩溃。
4. MCP：打到中途 → 存档 → 重启项目 → 读档 → 截图确认资源/队伍/flag 完整恢复。

产出：SaveManager.gd。

验收（全部通过）：
- [ ] 存档→重开→进度完整恢复（截图对比）
- [ ] 坏档不崩溃且有提示
- [ ] 存档含版本号，未来可迁移

提交：git commit -m "T7.2: 存档系统" 并 push。
```

#### T7.3 美术接口审计与 AI 资源接入演练

| 字段 | 内容 |
| --- | --- |
| 目标 | ArtProvider 全覆盖 + AI 资源替换演练 + 接入清单 |
| 产出 | `docs/美术资源接入清单.md`、1 组 AI 资源替换实例 |
| 依赖 | T7.1 |
| 预估 | 2 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T7.3 美术接口审计与AI资源接入演练
目标：审计全部视觉出口都走 ArtProvider；用 AI 生成的 1 张角色图 + 1 段音乐按规范接入替换占位，验证业务零改动。
前置：T7.1 已通过。

执行步骤：
1. 审计：全项目搜索直接引用资源路径/内联色块作为"外观"的地方（角色、立绘、tile、CG、演出、UI 图标），补齐走 ArtProvider；生成 docs/美术资源接入清单.md：接口表（接口/当前占位/真实资源路径规则/替换步骤，格式见 §5.1）。
2. AI 资源演练（美术）：用 AI 工具生成 1 张觉醒者立绘（透明底 PNG，二次元 Q 版风格，提示词建议含"立绘、透明背景"）→ 命名 assets/portraits/awakened_mech_01_normal.png → ArtProvider.get_portrait 返回真实贴图；确认对话中该角色立绘替换成功且业务代码零改动。
3. AI 资源演练（音乐）：用 AI 工具生成 1 段 30~60s BGM → 转 OGG → assets/audio/bgm_camp.ogg → 在营地场景 AudioStreamPlayer 播放；确认音量/循环正常。
4. 回归：替换后跑全流程一次，确认无报错、无视觉缺失。

产出：docs/美术资源接入清单.md、替换实例。

验收（全部通过）：
- [ ] 审计清单覆盖全部视觉出口，无漏网
- [ ] 立绘替换后对话显示真实图片，业务代码零改动（git diff 仅资源文件）
- [ ] BGM 播放正常
- [ ] 替换后全流程回归通过

提交：git commit -m "T7.3: 美术接口审计与AI资源接入" 并 push。
```

#### T7.4 MVP 总验收

| 字段 | 内容 |
| --- | --- |
| 目标 | 对照 §1 六项 + 设定一致性最终核验 |
| 产出 | `docs/MVP验收报告.md` |
| 依赖 | T7.3 |
| 预估 | 2 轮 |

【完整指令 · 粘贴给 Agent】

```
任务：T7.4 MVP总验收
目标：逐项核验 MVP 六项交付物与《初期设定》一致性，输出验收报告，修复至 0 已知缺陷。
前置：T7.3 已通过。

执行步骤：
1. 按 §1 六项逐项实机走查（MCP 运行 + 截图 + 日志），记录结果与证据。
2. 设定一致性核对（对照《汇界星痕》初期设定.md）：混元互斥（三系齐不触发共振/汇流）、招募三步前置（邂逅+心契+星缘令）、唤星通用池无内购、星髓 6 槽/套装不叠加（MVP 数据占位即可，逻辑未实现需在报告标注"占位未实现"）、心契同行试用。
3. 输出 docs/MVP验收报告.md：六项结论、设定核对表、已知缺陷与影响、下一步建议（星髓系统、更多章节、AI 资源批量接入）。
4. 性能粗测：MCP 运行记录 FPS/内存，低端配置 ≥30fps。
5. 最终提交并 push；确认 GitHub 私有仓库与本地一致。

产出：docs/MVP验收报告.md。

验收（全部通过）：
- [ ] 六项交付物全部达标（报告含证据）
- [ ] 设定核对表完成，未实现项明确标注"占位/待实现"
- [ ] 已知缺陷全部记录且无 P0 级
- [ ] 仓库最终 push 完成

提交：git commit -m "T7.4: MVP总验收" 并 push。
```

***

## 5. 美术资源接口预留规范

### 5.1 唯一资源入口 ArtProvider

| 接口 | 用途 | 当前占位实现 | 后期替换（AI 资源） |
| --- | --- | --- | --- |
| `get_character_sprite(id)` | 地图角色外观 | 色块 + 名字 | `assets/sprites/characters/<id>_<state>.png`（Q 版精灵） |
| `get_portrait(id, emotion)` | 对话/战斗立绘 | 色块 + 情绪文字 | `assets/portraits/<id>_<emotion>.png`（AI 生成立绘） |
| `get_tile_texture(map_id, layer)` | 等距砖块 | 纯色菱形 | `assets/maps/tilesets/<map_id>.tres` |
| `get_cg(id)` | 星痕绘卷 CG | 色块 + 标题 | `assets/cg/<chapter>_<node>.png` |
| `get_skill_fx(skill_id)` | 战斗特效 | 色块动画 | `assets/skills/<skill_id>_fx.*` |
| `get_ui_icon(id)` | UI 图标 | 纯色方块 | `assets/ui/icons/<id>.png` |
| `get_bgm(scene_id)` / `get_sfx(event_id)` | 音频 | 静音占位 | `assets/audio/bgm_<scene>.ogg` / `sfx_<event>.ogg` |

### 5.2 资源目录与命名规范

```
assets/
├── maps/tilesets/        map_<地图id>.tres
├── sprites/characters/   <char_id>_<idle|walk|skill>.png
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

***

## 6. 排期建议（波次）

| 波次 | 并行组合 | 预估轮次 |
| --- | --- | --- |
| 1 | P0 骨架（T0.1→T0.4 串行） | 4~7 |
| 2 | P1 地图 ∥ P2 角色 | 8~12 |
| 3 | P3 战斗 ∥ P4 剧情（Dialogic） | 10~14 |
| 4 | P5 心契（需 P3、P4） | 6~9 |
| 5 | P6 唤星（需 P5） | 6~8 |
| 6 | P7 整合验收 | 6~10 |

- 总预估约 **50~75 轮 agent 迭代**，并行关键路径约 **40~60 轮**。
- **风险点**：① Dialogic 2 版本 API 与文本语法差异——指令统一"以 addons/dialogic 文档为准"，语法收敛在转换工具一处；② 等距碰撞与 Y-sort 细节多，P1 留弹性；③ 战斗数值平衡（T7.1）需手动调参；④ CSV 解析器对中文/逗号转义要重点测试（T0.3 验收已含坏行用例）。

***

## 7. MVP 总验收清单（最终勾验）
- [ ] **等距 2.5D 地图**：可漫游、遮挡正确、NPC 交互提示、相机跟随不越界
- [ ] **3 名觉醒者**：三体系各一，CSV 数据 / 地图占位 / Dialogic 立绘占位可用
- [ ] **主线 1 段**：触发区 → Dialogic 演出 → 邂逅 3 人 → flag 落库 → 不重播
- [ ] **心契任务 1 个**：开启→同行→赠礼→共同战斗→满阶（quests.csv 驱动）
- [ ] **三人回合制战斗**：三指令、伤害结算、混元机制、演出占位、星砂奖励
- [ ] **唤星模拟**：星砂→抽卡（summon_pool.csv）→星缘令→（心契满阶）招募；未满阶正确拒绝
- [ ] **接口预留**：ArtProvider 全覆盖，AI 资源替换演练通过（T7.3）
- [ ] **存档**：进度可恢复；**Git**：仓库与本地一致、提交规范
- [ ] **设定一致性**：与《初期设定》对照无误（混元互斥、招募三步、通用池、无内购）
