# 《汇界星痕》Tileset 占位规范（T1.1 美术协作交付）

> 岗位：美术01 · 交付性质：规范文本，不产资源（P0 阶段程序用色块推进）
> 消费方：系统程序（T1.1 已实现、T1.6 布置、T7.3 真实资源替换）
> 命名依据：推进表 §5.2 硬约定；ArtProvider 对应接口 `get_tile_texture`

***

## 1. 现状事实（T1.1 已实现，commit 79fa17f）

| 项 | 值 |
| --- | --- |
| tile 尺寸 | 64×32（2:1 等距菱形） |
| 布局 | `TILE_LAYOUT_DIAMOND_RIGHT`（tile_shape=1, tile_layout=4） |
| source 0 地面 | `assets/maps/tilesets/ground.png`，实色 RGB(140,160,140) = `#8CA08C` 灰绿，无碰撞 |
| source 1 障碍 | `assets/maps/tilesets/obstacle.png`，实色 RGB(63,71,91) = `#3F475B` 深蓝灰，带菱形碰撞多边形 (0,-16)/(32,0)/(0,16)/(-32,0) |
| tileset 资源 | `assets/maps/tilesets/test_tileset.tres`（texture_region_size = 64×32） |
| 贴图遮罩 | 菱形区域内不透明，四角透明（PNG alpha=0） |

## 2. 硬约定（换真实资源时不可变）

1. **tile 尺寸恒为 64×32**，菱形长轴:短轴 = 2:1。真实砖图按此规格绘制，菱形遮罩外透明。
2. **布局恒为 DIAMOND_RIGHT**，基向量 ex=(32,-16)、ey=(32,16)；TileMapLayer 坐标系与碰撞多边形写法不变。
3. tileset 源文件路径规范：`assets/maps/tilesets/<map_id>.tres`（当前 `test_tileset.tres`，营地可另存 `camp_tileset.tres` 或继续复用）。
4. 替换演练目标：**只换 texture / .tres 引用，业务代码与场景结构零改动**（T7.3 审计基准）。

## 3. 占位配色建议（P0~P6 色块阶段）

原则：**可通行=高明度低饱和，不可通行=低明度高对比**；同一地图内地面/障碍明度差 ≥ 25%，障碍再叠菱形碰撞轮廓即可无歧义识别；角色/交互物用高饱和色与地面拉开（见《营地布置建议》）。

| 用途 | 建议色 | 说明 |
| --- | --- | --- |
| 地面（可通行） | `#8CA08C` | 现状灰绿，保留 |
| 障碍（不可通行） | `#3F475B` | 现状深蓝灰，保留 |
| 广场地面（可选新 tile，T1.6） | `#D9C79E` | 暖沙色，与草地灰绿形成"营地广场"区域感；无碰撞；若加，作为 source 2 追加进 tileset，不动 source 0/1 |
| 后续题材砖（水面/路径等） | 暂不定 | 需要时按"明度分层 + 美术登记"流程追加，勿复用地面色 |

## 4. 真实资源替换路径（T7.3 预留）

- 真实 tileset 图按 §5.2 命名：`assets/maps/tilesets/<map_id>.tres` + 同目录贴图（如 `camp_ground.png`）。
- 替换步骤：新 PNG 保持 64×32 菱形遮罩 → TileSetAtlasSource 换 texture（texture_region_size 不变）→ 地图单元格重排（atlas 坐标映射新源）→ 业务零改动。
- 审计口径：地图视觉只允许经 TileMapLayer + tileset 资源取用，禁止业务脚本内联颜色画地面。
