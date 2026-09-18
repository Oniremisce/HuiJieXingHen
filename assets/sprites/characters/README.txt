角色地图精灵（Q版占位，AI 美术后期接入）
命名规范：<char_id>_<idle|walk|skill>.png
示例：ji_lu_idle.png
要求：透明底 PNG，等距 2.5D Q 版三头身，统一主光源；由 ArtProvider.get_character_sprite(id) 加载，替换占位色块时业务代码零改动。
