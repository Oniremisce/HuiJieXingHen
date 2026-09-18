音频资源（BGM / 音效，AI 生成如 Suno）
命名规范：BGM bgm_<scene>.ogg（44.1kHz/16bit，建议 60~120s 循环段）；音效 sfx_<event>.ogg（1~3s）
示例：bgm_camp.ogg、sfx_battle_win.ogg
由 ArtProvider.get_bgm(scene_id) / get_sfx(event_id) 加载，静音占位后期替换。
