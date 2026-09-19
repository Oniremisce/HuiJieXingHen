// 《汇界星痕》T2.3 遮挡描边 shader（架构 §1.2 / §五：纯白 1.5~2px 外描边）
// 挂在 OcclusionOutline 镜像节点（CanvasItem.material）上：
// 该节点按 8 向偏移重绘宿主轮廓，本 shader 输出纯白、强度由 strength 驱动，
// 遮挡面积比例 → strength 平滑淡入淡出（OcclusionOutline.gd 计算）。
shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	COLOR = vec4(1.0, 1.0, 1.0, strength);
}
