角色立绘（对话/战斗演出，情绪差分）
命名规范：<char_id>_<normal|happy|sad|angry>.png
示例：ji_lu_happy.png
要求：透明底 PNG；由 ArtProvider.get_portrait(id, emotion) 加载；Dialogic 立绘占位替换时在 Dialogic 内换资源即可，timeline 与 CSV 不动。
