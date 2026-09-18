技能特效资源
命名规范：<skill_id>_cutscene.*（小技能立绘/终结技动画统一挂此目录）
示例：ji_lu_ult_cutscene.png
要求：战斗演出预留 SkillCutscene 两插槽（PortraitRect 小技能半身立绘、CutsceneAnimation 终结技专属动画）；由 ArtProvider.get_skill_fx(skill_id) 加载。
