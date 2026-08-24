# Garen 参考与改编档案

## 来源快照

- 目标：League of Legends PC Garen。
- 最近核对：2026-08-23。
- 项目形态：Rogue Admiral Garen，本地学习原型。
- 属性来源：[Template:Data Garen](https://wiki.leagueoflegends.com/en-us/Template:Data_Garen)。
- 属性语义：[Champion statistics](https://wiki.leagueoflegends.com/en-us/Category:Champion_statistics)。
- 技能入口：[Garen](https://wiki.leagueoflegends.com/en-us/Garen)。

外部数据会随补丁更新。继续调整技能前必须重新访问以上页面和对应技能模板，不得把本快照当作永久最新版。

## 身份摘要

参考 Garen 的核心身份是：无施法资源的近战重装战士；通过脱战恢复获得续航，以加速强化攻击接近并沉默目标，使用短时防御窗口承受伤害，在移动中持续旋转输出，最后按目标已损失生命完成处决。

Rogue Admiral 主题可以改变名称、美术和额外技能，但不能让这些身份机制在无说明的情况下消失。

## 当前基础属性

| 属性 | 1 级值 | 成长 | 运行时换算 | 来源字段 |
| --- | ---: | ---: | ---: | --- |
| 最大生命 | 690 | 98 | 690 | `hp_base|hp_lvl` |
| 生命回复/5秒 | 8 | 0.5 | 8 | `hp5_base|hp5_lvl` |
| 攻击力 | 69 | 4.5 | 69 | `dam_base|dam_lvl` |
| 攻击速度 | 0.625 | 3.65% | 0.625 / 0.0365 | `as_base|as_lvl` |
| 攻速倍率 | 0.625 | 0 | 0.625 | `as_ratio` |
| 护甲 | 38 | 4.2 | 38 | `arm_base|arm_lvl` |
| 魔抗 | 32 | 1.55 | 32 | `mr_base|mr_lvl` |
| 移动速度 | 340 | 0 | 3.4 m/s | `ms` |
| 攻击距离 | 175 | 0 | 1.75 m | `range` |

选取、玩法、寻路、索敌半径和基础攻击前摇也保存在 `unit_stats.csv`。霸体、纵深、加速度和击退抗性是 Gemheart 项目值，不属于 Wiki 原始属性。

## 技能映射

| 参考技能 | 项目技能 | 等级 | 已保留 | 明确差异 |
| --- | --- | --- | --- | --- |
| Perseverance 被动 | 暂无独立技能 | `missing` | 普通生命回复属性已建模 | 尚无“受到特定伤害后暂停、脱战后按最大生命回复”的状态机 |
| Decisive Strike Q | 破舰 | `simplified` | 清除减速、35% 加速、4.5 秒内强化下一击、沉默、可暴击物理攻击 | 当前为固定 115 伤害；未实现技能等级、AD 系数和突进修正 |
| Courage W | 黑帆 | `adapted` | 被动护甲/魔抗、主动减伤和控制缩减 | 固定 20% 被动和 30% 主动；当前没有真正的护盾吸收层或参考击杀叠层 |
| Judgment E | 翻江倒海 | `simplified` | 3 秒自身范围旋转、移动施法、周期物理伤害、可暴击 | 固定 6 次×48；未实现攻速转数、AD 系数、最近目标增伤、破甲和提前结束 |
| Demacian Justice R | 暴君审判 | `adapted` | 单体锁定、基于目标已损失生命提高伤害、终结演出 | 当前为魔法伤害 `130 + 260×missing_ratio`；参考技能的真实伤害和技能等级结构未保留 |
| 无 | 七海霸权 | `original_legacy` | 大范围地面技能、眩晕、朗姆酒延迟伤害 | 原创第五技能；在新规则下不作为参考技能完成度的替代品 |

技能数据模板：

- [Perseverance](https://wiki.leagueoflegends.com/en-us/Template:Data_Garen/Perseverance)
- [Decisive Strike](https://wiki.leagueoflegends.com/en-us/Template:Data_Garen/Decisive_Strike)
- [Courage](https://wiki.leagueoflegends.com/en-us/Template:Data_Garen/Courage)
- [Judgment](https://wiki.leagueoflegends.com/en-us/Template:Data_Garen/Judgment)
- [Demacian Justice](https://wiki.leagueoflegends.com/en-us/Template:Data_Garen/Demacian_Justice)

## 横版动作化决策

- 移动与攻击发生在 X/Z 平面，Y 负责高度；所有近战和范围技能均有纵深容差。
- 破舰的强化攻击使用 `spell1`，加速期间使用 `run_spell`。
- 黑帆表现绑定 Buff 生命周期，Jolly Roger 与 4 秒 Buff 同步。
- 翻江倒海允许移动，效果位于角色前景并以 2.6 米半径持续 3 秒。
- 暴君审判锁定目标当前位置并将 Anchor 放在目标处。
- 七海霸权快照半径 5.2 米的地面区域，Ghostship 根据区域相对方向翻转，不继续追踪目标；判定直径按当前视觉画布约 10.5 米的横向覆盖对齐。
- 命中停顿、硬直、削韧、击退和粒子来自 `hit_profiles`，不从 Wiki 数值推导。

## 当前优先补项

按照“参考技能优先”方针，继续增加新技能前应优先评估：

1. Perseverance 的脱战判定和最大生命回复状态机。
2. 黑帆的真实护盾层，以及是否继续采用固定 20% 被动简化。
3. 翻江倒海的 AD 系数、攻速转数和破甲是否值得进入当前动作原型。
4. 暴君审判是否继续保留魔法伤害主题改写，还是切换到参考的真实伤害结构。
5. 技能等级数据是否需要独立 schema，而不是继续使用单一固定值。

## 验收基线

当前自动验证覆盖：基础/成长属性、单位换算、攻击前摇、五技能规则、翻江倒海移动施法、VFX 层级和 Shader、左右朝向、AI 追击、木桩移动、命中粒子与音效。新增上述补项时必须添加对应公式和状态测试。
