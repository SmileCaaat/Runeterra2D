# Garen 参考与改编档案

## 来源快照

- 目标：League of Legends PC Garen。
- 最近核对：2026-08-23。
- 项目形态：Rogue Admiral Garen，本地学习原型。
- 属性来源：[Template:Data Garen](https://wiki.leagueoflegends.com/en-us/Template:Data_Garen)。
- 属性语义：[Champion statistics](https://wiki.leagueoflegends.com/en-us/Category:Champion_statistics)。
- 通用字段契约：[Module:ChampionData/data](https://wiki.leagueoflegends.com/en-us/Module:ChampionData/data)。该页作为字段/派生规则参考，不作为独立的 Garen 数值快照。

## 等级与字段迁移状态

- `skills.csv` 记录“P/Q/W/E/R/T”的来源槽位、身份映射和最大等级：P 为被动，Q/W/E 为 5 级，R 为 3 级；七海霸权占用项目扩展位 T，保持原创单级。
- 技能等级与英雄等级分离。英雄开局为 1 级，P 按英雄等级成长；Q/W/E/R 的技能等级默认也为 1，之后如何加点属于独立的升级系统。Q、E 与 R 已使用 `skill_ranks.csv` 与 `skill_effect_ranks.csv` 登记参考等级数值；W 仍是原型固定值，待逐技能来源快照完成后替换。
- `missile_speed`、攻击施放/总时长、攻击距离/移速成长及基础/修正暴击伤害已在 `unit_stats.csv` 分列。它们是来源追踪和后续基本攻击系统的输入；当前运行时尚未用攻击时序字段替代 `attack_windup`。
- 硬直、霸体值、霸体恢复、韧性、减速抗性与击退抗性属于 Gemheart 横版动作规则，权威定义仍在 `stats.csv`、`hit_profiles.csv`、`combat_rules.csv`，不从 LoL 的 ChampionData 直接推导。
- 技能入口：[Garen](https://wiki.leagueoflegends.com/en-us/Garen)。

外部数据会随补丁更新。继续调整技能前必须重新访问以上页面和对应技能模板，不得把本快照当作永久最新版。

## 身份摘要

参考 Garen 的核心身份是：无施法资源的近战重装战士；通过脱战恢复获得续航，以加速强化攻击接近并沉默目标，使用短时防御窗口承受伤害，在移动中持续旋转输出，最后按目标已损失生命完成处决。

Rogue Admiral 主题可以改变名称、美术和额外技能，但不能让这些身份机制在无说明的情况下消失。

## 当前基础属性

## 实例模板绑定

- 盖伦的 `units.csv.instance_template_id=hero`，运行时继承 `HeroInstance`。该模板统一接入伤害数字和英雄受伤展示入口；盖伦专有的 AI、序列帧状态机、P/Q/W/E/R/T 仍保留在派生脚本。
- 训练假人和峡谷迅捷蟹使用 `instance_template_id=monster`，继承同一怪物模板；因此物理、魔法、真实伤害和 `MISS` 的数字显示不再由各怪物重复创建。

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
| Perseverance 被动 | P · 坚忍 | `simplified` | 8 秒受伤抑制后，按最大生命百分比持续回复；1/6/13/30 级分别为 1.5%/2.5%/8.1%/14.9% 每 5 秒 | 当前将所有有效入伤视为抑制事件，且连续结算而非离散跳血；图标已登记，UI 待实现 |
| Decisive Strike Q | 破舰 | `adapted` | 清除减速、35% 加速、4.5 秒内强化下一击、沉默；Q 的 5 个技能等级分别提供 1.4/1.95/2.5/3.05/3.6 秒加速与 `30/60/90/120/150 + 50% AD` 额外物理伤害 | 普攻本体可暴击，Q 额外伤害不能暴击；横版动作中，距目标 `1.75–2.4m` 时于 0.12 秒冲至距目标 0.85m 再挥砍。未实现通用 on-hit、吸血、建筑/不可选中等边界规则 |
| Courage W | 黑帆 | `adapted` | 被动护甲/魔抗、主动减伤和控制缩减 | 固定 20% 被动和 30% 主动；当前没有真正的护盾吸收层或参考击杀叠层 |
| Judgment E | 翻江倒海 | `adapted` | 3 秒移动施法、每转物理伤害可暴击、最近目标增伤；六段命中施加 25% 破甲 6 秒 | 五级冷却与每转 AD 公式已入表；当前无装备额外攻速所以固定 7 转，且未实现手动提前结束。施放期间启用霸体规则（免击退、免打断） |
| Demacian Justice R | 暴君审判 | `adapted` | 单体锁定、基于目标已损失生命提高伤害、终结演出 | 三级 `125/200/275 + 25/30/35%×目标缺失生命` 真实伤害；冷却 `120/100/80s`、施法 `0.435s`、射程 400 换算为 `4.0m`，图标登记为 `garen_demacian_justice_icon`。普通护盾可吸收真实伤害；揭露语义因尚无隐身/视野系统登记为 deferred |
| T | 七海霸权 | `original_legacy` | 大范围地面技能、眩晕、朗姆酒延迟伤害 | 项目扩展技能位；不作为参考技能完成度的替代品 |

技能数据模板：

- [Perseverance](https://wiki.leagueoflegends.com/en-us/Template:Data_Garen/Perseverance)
- [Decisive Strike](https://wiki.leagueoflegends.com/en-us/Template:Data_Garen/Decisive_Strike)
- [Courage](https://wiki.leagueoflegends.com/en-us/Template:Data_Garen/Courage)
- [Judgment](https://wiki.leagueoflegends.com/en-us/Template:Data_Garen/Judgment)
- [Demacian Justice](https://wiki.leagueoflegends.com/en-us/Template:Data_Garen/Demacian_Justice)

## 横版动作化决策

- 移动与攻击发生在 X/Z 平面，Y 负责高度；所有近战和范围技能均有纵深容差。
- 坚忍在英雄生命未满且 8 秒未受到有效伤害时启动；每帧连续恢复等价于当前等级的“每 5 秒最大生命回复比例”。这保留续航身份，同时避免动作场景的突兀跳血。
- P 处于就绪状态时同步循环两层序列帧，均不受角色或地面遮挡。当前场景节点是权威绑定：`PerseveranceFront` 播放 `hip`，局部位置 `(0.12230945, -0.09625608, 0.08000004)`，缩放 `(1.4105068, 0.95627636, 1)`，不透明度约 35.3%；`PerseveranceHip` 播放 `slow1`，局部位置 `(0.07588625, 0.45039487, 0.120000005)`，缩放 `(1.643449, 1, 1)`，不透明度约 27.5%。两层均采用 `0.015 m/px`。开局或 8 秒受伤抑制结束时 0.3 秒渐显，受伤抑制期间 0.5 秒渐隐。实际生命回复仍仅在生命未满时结算。
- 两个序列帧层以 `6 fps` 缓慢循环（9 帧约 1.5 秒）。`garen_perseverance_motes` 是复用的 `GPUParticles3D`：14 枚低透明度的圆形绿色光点（`0.042 × 0.042m`）、2.6 秒寿命、低速向上漂浮；与 P 就绪状态共同渐显/渐隐，不在每次触发时创建新节点。
- 破舰的强化攻击使用 `spell1`，加速期间使用 `run_spell`。
- Q 的技能等级独立于英雄等级，当前运行时默认 Q=1 级；本次没有实现加点或升级 UI。强化攻击发起时，若目标在普通攻击距离外但不超过 Q 的 `2.4m` 追击阈值，则以 `0.12s` 冲到目标前约 `0.85m`；目标已经贴身时原地攻击。这是保留追击手感、避免横版场地“瞬移”的项目化改编。
- 黑帆表现绑定 Buff 生命周期，Jolly Roger 与 4 秒 Buff 同步。
- 翻江倒海允许移动，效果位于角色前景并以 2.6 米半径持续 3 秒。
- E 的命中改用可复用 `slash` 程序化物理斩击反馈，而非此前偏魔法的 `elemental` 反馈。Buff/Debuff 槽保留给未来 UI；场内破甲不再显示常驻图标。`vajra_break` 六帧特效以 `0.015m/px` 正常播放；其上叠加可复用于 UI 的 `Keyword_Overwhelm_HD` 图标，图标负责中心弹出、左右晃动、回弹和渐隐，并以 3 倍速播放金属冲击音。E 的霸体当前接入公共 `SuperArmorAfterimage`：激活时只显示角色序列帧的上一帧，采用高明度鲜红色；该组件和配表不绑定 E，后续技能或 Buff 只需驱动同一激活状态即可复用。
- 暴君审判锁定目标当前位置并将 Anchor 放在目标处；命中使用白色高速定向斩击火花叠加白色爆发、冲击波的 `true_damage` 程序化反馈。
- 七海霸权快照半径 5.2 米的地面区域，Ghostship 根据区域相对方向翻转，不继续追踪目标；判定直径按当前视觉画布约 10.5 米的横向覆盖对齐。
- 命中停顿、硬直、削韧、击退和粒子来自 `hit_profiles`，不从 Wiki 数值推导。

## 当前音频映射

- 普攻三段分别使用原始 `BasicAttack`、`BasicAttack2` 与 `CritAttack` 挥砍声。
- 命中声音按 `flesh`、`metal`、`stone`、`wood` 材质登记；训练假人使用 `wood`，迅捷蟹使用 `flesh`，暴击自动切换对应材质的 Crit 版本。
- 破舰使用独立发动声，强化攻击的两条 `Q_Attack_OnCast` 作为同帧分层声音播放。
- 黑帆使用 `W_OnCast`；翻江倒海使用 `E_OnCast`，每次命中通过 `E_hit`；暴君审判使用 `R_buffactivate`、`R_OnCast`、`R_OnHit` 三阶段声音。
- `Recouperate1_buffactivate` 已登记为 `garen_passive_recovery_activate`，在 Perseverance 状态机实现前保持不触发。
- 七海霸权使用项目现有 Ghostship 主音轨，并在主音轨开始 `0.15s` 后叠加 `Garen_Original_SFX_R_buffactivate`；船体抵达、AOE 伤害、眩晕与朗姆酒在主音轨 `1.35s` 处同步结算。Ghostship 播放音量为 `+5 dB`，并保留撞击后的自然尾音。
- 七海霸权的伤害命中层使用与盖伦普攻相同的材质命中音色，不再播放旧的合成训练假人音效；木质、肉体、金属与石质目标会解析到对应的普攻命中音频。

## 当前优先补项

按照“参考技能优先”方针，继续增加新技能前应优先评估：

1. 坚忍的伤害来源分类，待英雄/野怪/防御塔/技能来源管线统一后替代“任意有效入伤”。
2. 黑帆的真实护盾层，以及是否继续采用固定 20% 被动简化。
3. 翻江倒海的装备额外攻速接线、手动提前结束，以及未来完整伤害修正层。
4. 黑帆的真实护盾层、多护盾顺序和护盾破裂表现；当前普通护盾已可在所有训练目标上吸收任意伤害类型（包括真实伤害），但尚未形成完整通用 Buff 流水线。
5. 用可追溯来源值替换 W 的原型固定等级行，并实现独立的技能加点流程。

## 验收基线

当前自动验证覆盖：基础/成长属性、单位换算、攻击前摇、五技能规则、翻江倒海移动施法、VFX 层级和 Shader、左右朝向、AI 追击、木桩移动、普通/暴击命中序列帧与音效。新增上述补项时必须添加对应公式和状态测试。
