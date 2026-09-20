extends RefCounted
## =============================================================
## T3.9 阵型生成器（纯数学模块，无场景/无渲染依赖）
## 口径：docs/系统规则/战斗系统.md §9 对阵阵型
## -------------------------------------------------------------
## 4 列 × 3 行格子矩形**斜向摆放**（区域右边缘向上斜 45°、
## 左边缘向下斜 45°）：以阵型区域中心为原点，把 4×3 网格整体
## 旋转 -45°（列方向向量=(cos45,-sin45)=向右上 45°）。
##   · 第一列(1×3)=我方（屏幕中间左下角同排排列）
##   · 第二列=空白分界线（不站人，本模块不产出该列锚点）
##   · 第三列=敌方前列（靠我方）、第四列=敌方后列（§3.1/§8.2，
##     T3.10 column scope 消费）
## 返回结构仅含三组锚点，**不含棋盘格**（§6 禁止项：战斗 UI 不绘制
## 格线/格底，格子仅为模型站位逻辑位置）。
## 几何实现：cell(cc,r) = center + R(-45°)·((cc-1.5)·dx, (r-1)·dy)
##   → x'=(gx+gy)·cos45, y'=(-gx+gy)·cos45；dy=dx×0.9（行距略紧凑）。
## 纯静态函数，无 class_name（headless --script 无缓存可跑，惯例）。
## =============================================================

const COS45 := 0.7071067811865475  # cos(45°)=sin(45°)

## 生成 4×3 斜向阵型锚点（列 0/2/3 三组，第二列空白不产出）
##   viewport_size: 视口尺寸（默认 1152×648 设计高，spacing 按此自适应）
##   row/col: 网格行列（§9 固定 4×3，参数保留便于断言/扩展）
##   arena_rect_center: 阵型区域中心（屏幕中间偏右上，默认自动算）
##   spacing: 格间距（<=0 按视口高×0.09 自适应，648→58）
## 返回 {"ally":[Vector2×3], "enemy_front":[Vector2×3], "enemy_back":[Vector2×3]}
static func take_param(viewport_size: Vector2 = Vector2(1152, 648),
		row: int = 3, col: int = 4,
		arena_rect_center: Vector2 = Vector2.ZERO,
		spacing: float = 0.0) -> Dictionary:
	var center := arena_rect_center
	if center == Vector2.ZERO:
		# 屏幕中间偏右上：我方第一列自然落于中间左下、敌方三四列落于中间右上
		center = Vector2(viewport_size.x * 0.55, viewport_size.y * 0.47)
	var sp := spacing if spacing > 0.0 else viewport_size.y * 0.09
	var dx := sp
	var dy := sp * 0.9
	var ally: Array = []
	var front: Array = []
	var back: Array = []
	for r in range(row):
		ally.append(_cell_at(center, dx, dy, 0, r, row, col))   # 第一列：我方
		front.append(_cell_at(center, dx, dy, 2, r, row, col))  # 第三列：敌方前列（靠我方）
		back.append(_cell_at(center, dx, dy, 3, r, row, col))   # 第四列：敌方后列
	return {"ally": ally, "enemy_front": front, "enemy_back": back}

## 单格锚点：网格坐标绕阵型中心旋转 -45°
static func _cell_at(center: Vector2, dx: float, dy: float,
		cc: int, r: int, row: int, col: int) -> Vector2:
	var gx := (float(cc) - float(col - 1) * 0.5) * dx
	var gy := (float(r) - float(row - 1) * 0.5) * dy
	return center + Vector2((gx + gy) * COS45, (-gx + gy) * COS45)
