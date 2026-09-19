## =============================================================
## 《汇界星痕》T2.3 ArtProvider（美术统一出口，Autoload 单例）
## -------------------------------------------------------------
## 架构 §五 / 推进表 §5.1 接口表：业务外观一律走此入口，
## 美术资源落盘后零改动替换（真实路径存在则优先加载，否则色块占位）。
## 占位策略：
##   - 已知 id（三名觉醒者）在 _ready 预热用 SubViewport 渲染「色块+名字」纹理；
##   - 其余 id 返回同步纯色块（Image 填充，无文字）；
##   - 音频占位 = 1s 静音 AudioStreamWAV（消费方可直接播放，无声）。
## 依赖：DataManager（体系色查 characters.csv system 列），
##   Autoload 注册位置在其后（本工程：…→Party→ArtProvider）。
## 下游消费：T2.6 美术接入演练、T3.6 战斗演出、T4.x 对话立绘、T6.4 抽卡 CG。
## =============================================================
extends Node

## 体系三色（T1.6 已定：机律青 / 秘法紫 / 玄门玉绿）
const SYSTEM_COLORS := {
	"机律": Color("00BFFF"),
	"秘法": Color("9370DB"),
	"玄门": Color("3CB371"),
}

var _tex_cache: Dictionary = {}
var _silent_stream: AudioStreamWAV = null


func _ready() -> void:
	_prewarm_placeholders()


## ------------------------------------------------------------
## 接口表（推进表 §5.1 · 架构 §4.4）
## ------------------------------------------------------------

## 地图角色外观：真实帧条路径存在则加载，否则「体系色色块+名字」占位
## T2.6 裁决①：哨兵改 _idle_e.png（首方向，与动画命名 `<state>_<dir>` 一致，
## 消除与南向帧条 _idle_s.png 同名冲突风险）
func get_character_sprite(id: String) -> Texture2D:
	var real := "res://assets/sprites/characters/%s_idle_e.png" % id
	if ResourceLoader.exists(real):
		return load(real)
	if _tex_cache.has("sprite_" + id):
		return _tex_cache["sprite_" + id]
	return _solid_block(get_system_color(id), Vector2i(64, 96))


## T2.6 帧条接入辅助：按角色 id 构建完整 SpriteFrames（8 方向 × idle/walk）
## 帧规格（美术01 T2.6 基线）：每方向独立横条——idle 192×48=4 帧、walk 384×48=8 帧，
## 单帧 48×48；动画名 "<state>_<dir>"（如 idle_e / walk_ne）。
## 返回 null 表示资源不齐备（哨兵都不存在则不尝试）。
func build_sprite_frames_for(character_id: String) -> SpriteFrames:
	var sf := SpriteFrames.new()
	var frame_px := Vector2i(48, 48)
	var directions := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
	var added := 0
	for d in directions:
		for state in ["idle", "walk"]:
			var path := "res://assets/sprites/characters/%s_%s_%s.png" % [character_id, state, d]
			if not ResourceLoader.exists(path):
				continue
			var strip: Texture2D = load(path)
			var img := strip.get_image()
			if img == null:
				continue
			var tex_size := img.get_size()
			var cols := int(tex_size.x / frame_px.x)
			var anim_name := "%s_%s" % [state, d]
			sf.add_animation(anim_name)
			for c in range(cols):
				var atlas := AtlasTexture.new()
				atlas.atlas = strip
				atlas.region = Rect2(c * frame_px.x, 0, frame_px.x, frame_px.y)
				sf.add_frame(anim_name, atlas)
				added += 1
			sf.set_animation_speed(anim_name, 12.0 if state == "walk" else 6.0)
	print("[ArtProvider] build_sprite_frames_for(%s) 完成：%d 帧 / %d 动画" % [character_id, added, sf.get_animation_names().size()])
	return sf


## 对话/战斗立绘：真实路径 assets/portraits/<id>_<emotion>.png 优先
func get_portrait(id: String, emotion: String = "normal") -> Texture2D:
	var real := "res://assets/portraits/%s_%s.png" % [id, emotion]
	if ResourceLoader.exists(real):
		return load(real)
	if _tex_cache.has("portrait_" + id + "_" + emotion):
		return _tex_cache["portrait_" + id + "_" + emotion]
	return _solid_block(get_system_color(id), Vector2i(160, 220))


## 等距砖块：占位纯色（真实砖由 TileSet .tres 承载，本接口留作 UI 缩略/预览出口）
func get_tile_texture(map_id: String, layer: String = "ground") -> Texture2D:
	var real := "res://assets/maps/tilesets/%s.png" % map_id
	if ResourceLoader.exists(real):
		return load(real)
	var key := "tile_" + map_id + "_" + layer
	if _tex_cache.has(key):
		return _tex_cache[key]
	var tex := _solid_block(Color(0.55, 0.72, 0.45), Vector2i(64, 32))
	_tex_cache[key] = tex
	return tex


## 星痕绘卷 CG：真实路径 assets/cg/<id>.png 优先，否则色块占位
func get_cg(id: String) -> Texture2D:
	var real := "res://assets/cg/%s.png" % id
	if ResourceLoader.exists(real):
		return load(real)
	if _tex_cache.has("cg_" + id):
		return _tex_cache["cg_" + id]
	return _solid_block(Color(0.45, 0.36, 0.58), Vector2i(320, 180))


## 战斗特效占位：真实路径 assets/skills/<id>_fx.png 优先，否则色块
func get_skill_fx(skill_id: String) -> Texture2D:
	var real := "res://assets/skills/%s_fx.png" % skill_id
	if ResourceLoader.exists(real):
		return load(real)
	var key := "fx_" + skill_id
	if _tex_cache.has(key):
		return _tex_cache[key]
	var tex := _solid_block(Color(0.98, 0.85, 0.35), Vector2i(64, 64))
	_tex_cache[key] = tex
	return tex


## UI 图标：真实路径 assets/ui/icons/<id>.png 优先，否则纯色方块
func get_ui_icon(id: String) -> Texture2D:
	var real := "res://assets/ui/icons/%s.png" % id
	if ResourceLoader.exists(real):
		return load(real)
	var key := "icon_" + id
	if _tex_cache.has(key):
		return _tex_cache[key]
	var tex := _solid_block(Color(0.7, 0.72, 0.78), Vector2i(24, 24))
	_tex_cache[key] = tex
	return tex


## BGM 静音占位（真实路径 assets/audio/bgm_<scene>.ogg，T6 后接音频岗）
func get_bgm(scene_id: String) -> AudioStream:
	print("[ArtProvider] get_bgm(%s) -> 静音占位" % scene_id)
	return _get_silent_stream()


## 音效静音占位（真实路径 assets/audio/sfx_<event>.ogg）
func get_sfx(event_id: String) -> AudioStream:
	print("[ArtProvider] get_sfx(%s) -> 静音占位" % event_id)
	return _get_silent_stream()


## 体系色查询（编队头像/地图标注共用；未知角色返回中性灰）
func get_system_color(id: String) -> Color:
	var dm := get_node("/root/DataManager")
	var ch: Variant = dm.get_character(id)
	if ch == null:
		return Color(0.6, 0.6, 0.6)
	return SYSTEM_COLORS.get(ch.system, Color(0.6, 0.6, 0.6))


# ---------------------------------------------------------------
# 内部：占位纹理生成
# ---------------------------------------------------------------

## 预热已知角色（CSV 三名觉醒者）的「色块+名字」纹理；失败不影响主流程
func _prewarm_placeholders() -> void:
	await get_tree().process_frame
	var dm := get_node("/root/DataManager")
	for id in ["awakened_mech_01", "awakened_arcane_01", "awakened_xian_01"]:
		var ch: Variant = dm.get_character(id)
		if ch == null:
			continue
		var col: Color = get_system_color(id)
		_tex_cache["sprite_" + id] = await _render_text_block(str(ch.name), col, Vector2i(64, 96))
		_tex_cache["portrait_" + id + "_normal"] = await _render_text_block("%s 立绘" % ch.name, col, Vector2i(160, 220))
	print("[ArtProvider] ready: 占位预热 %d 项（色块+名字）" % _tex_cache.size())


## 同步纯色块（未知 id 兜底，无文字）
func _solid_block(color: Color, sz: Vector2i) -> Texture2D:
	var img := Image.create(sz.x, sz.y, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


## SubViewport 渲染「色块+文字」纹理（需 await 一帧，仅预热期使用）
func _render_text_block(text: String, color: Color, sz: Vector2i) -> Texture2D:
	var vp := SubViewport.new()
	vp.size = sz
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var bg := ColorRect.new()
	bg.color = color
	bg.size = Vector2(sz)
	vp.add_child(bg)
	var lb := Label.new()
	lb.text = text
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.size = Vector2(sz)
	vp.add_child(lb)
	await RenderingServer.frame_post_draw
	var vptex: Texture2D = vp.get_texture()  # ViewportTexture 即纹理本身，但随视口释放失效
	var img: Image = vptex.get_image()       # 读回像素 → 转独立 ImageTexture 再缓存
	vp.queue_free()
	return ImageTexture.create_from_image(img)


func _get_silent_stream() -> AudioStreamWAV:
	if _silent_stream == null:
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_8_BITS
		wav.mix_rate = 22050
		var bytes := PackedByteArray()
		bytes.resize(22050)
		bytes.fill(128)  # 8bit 静音 = 中点电平
		wav.data = bytes
		_silent_stream = wav
	return _silent_stream
