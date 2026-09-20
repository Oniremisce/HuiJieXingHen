extends RefCounted
## =============================================================
## T3.9 阵型生成器（纯数学模块，无场景/无渲染依赖）
## 口径：docs/系统规则/战斗系统.md §9 对阵阵型 + 部署者返工裁定
##（2026-09-21：按参考图站位观感重排，模型不得与界面 UI 重叠；
##  原 45° 旋转矩形口径废止）
## -------------------------------------------------------------
## 4 列 × 3 行逻辑格网，斜投影两方向向量（参考图观感）：
##   · 行方向（同列相邻行，行内排布）= 向右下缓斜 ROW_ANGLE°
##     ——我方三人与敌方前排三人都是近水平横排、微向右下
##   · 列方向（列间推进）由三组列基准点表达（相对视口比例）：
##     第一列(我方)左中 → 第三列(敌前)右中 → 第四列(敌后)右上
##     第二列为空白分界线（不站人、不产出锚点）
##   · 第三列=敌方前列（靠我方）、第四列=敌方后列（§3.1/§8.2，
##     T3.10 column scope 消费）
## UI 避让硬约束（§6 + 返工裁定）：全部锚点避开左下角角色信息
## 板块区（y≥板顶）、左侧速度条区、屏幕四缘（模型 64×96 +
## 头顶血条/名字组件安全盒）。
## 返回结构仅含三组锚点，**不含棋盘格**（§6 禁止项：战斗 UI 不
## 绘制格线/格底，格子仅为模型站位逻辑位置）。
## 纯静态函数，无 class_name（headless --script 无缓存可跑，惯例）。
## =============================================================

## 行方向：向右下缓斜角度（参考图观感：横排微斜，非 45° 陡斜）
const ROW_ANGLE_DEG := 10.0
## 行距 = 视口宽 × ROW_STEP_R（同行相邻站位间距）
const ROW_STEP_R := 0.095

## 三组列基准点（x 相对视口宽、y 相对视口高；r=0 行锚点，行内沿行方向推进）
## 我方左中部、敌方前列右中部、敌方后列右上——第二列空白分界不产出
const ALLY_BASE := Vector2(0.185, 0.475)
const FRONT_BASE := Vector2(0.550, 0.420)
const BACK_BASE := Vector2(0.560, 0.280)

## 模型+头顶组件安全盒半径（断言/UI 避让用；模型 64×96 中心锚点）
const UNIT_HALF_W := 32.0
const UNIT_HALF_H := 48.0

## 生成 4×3 阵型锚点（列 0/2/3 三组，第二列空白不产出）
##   viewport_size: 视口尺寸（默认 1152×648 设计分辨率）
##   row/col: 网格行列（§9 固定 4×3，参数保留便于断言/扩展）
##   arena_rect_center/spacing: 兼容旧签名（本几何用列基准+行距参数化，
##     传值不使用；保留占位便于 T3.10/后续调参）
## 返回 {"ally":[Vector2×3], "enemy_front":[Vector2×3], "enemy_back":[Vector2×3]}
## 锚点=**视口空间**（屏幕坐标）；battle_arena 落位时经地图相机逆映射
## 转世界坐标（Battle 层挂在地图场景下，直接用视口坐标会被相机拖偏）。
static func take_param(viewport_size: Vector2 = Vector2(1152, 648),
		row: int = 3, col: int = 4,
		arena_rect_center: Vector2 = Vector2.ZERO,
		spacing: float = 0.0) -> Dictionary:
	var row_step := viewport_size.x * ROW_STEP_R
	var dr := Vector2(1, 0).rotated(deg_to_rad(ROW_ANGLE_DEG))  # 行方向：右下缓斜
	var ally: Array = []
	var front: Array = []
	var back: Array = []
	for r in range(row):
		var off := dr * row_step * float(r)
		ally.append(Vector2(viewport_size.x * ALLY_BASE.x, viewport_size.y * ALLY_BASE.y) + off)
		front.append(Vector2(viewport_size.x * FRONT_BASE.x, viewport_size.y * FRONT_BASE.y) + off)
		back.append(Vector2(viewport_size.x * BACK_BASE.x, viewport_size.y * BACK_BASE.y) + off)
	return {"ally": ally, "enemy_front": front, "enemy_back": back}
