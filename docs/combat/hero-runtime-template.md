# Hero Runtime Template (Jinx 准入基线)

本页冻结 Garen/Ryze 已验证的运行时边界，供 Jinx、Braum、Karma 复用。它是接口与施工顺序契约，不要求为了目录美观立即搬迁现有文件。当前实现位于 `scripts/characters/`、`scripts/ai/kits/`、`scripts/actors/` 与 `scripts/combat/`；新英雄可按 `<hero>_actor.gd`、`<hero>_skill_controller.gd`、`<hero>_model_animator.gd`、`<hero>_ai_kit.gd` 组织，但职责比路径更重要。

## 四层职责

| 层 | 拥有 | 不拥有 |
| --- | --- | --- |
| Actor (`HeroInstance` 子类) | 生命周期、阵营与目标、移动/朝向、死亡/复活、控制权、Player/AI 请求适配、AIContext、场景组件接线 | 通用 AI 评分、HUD 战斗规则 |
| SkillController（场景固定子节点） | 普攻和技能、CD/资源、技能状态、投射物/AoE、伤害与状态效果 | 输入来源、AI Utility 排序 |
| ModelAnimator（场景固定子节点） | 语义动画、动画速率、视觉朝向与纯表现变换 | 命中/数值裁决 |
| HeroAIKit | 英雄专属候选、Utility、技能状态变化描述 | 最终动作合法性、通用候选筛选 |

Garen 与 Ryze 都已采用 Actor + 场景内 SkillController + ModelAnimator + HeroAIKit。现存 Actor 的一些 HUD/VFX 兼容转发接口仍保留；它们不是新英雄把技能逻辑写回 Actor 的先例。短生命周期战斗实体应使用 `PackedScene`、Resource 或对象池；固定碰撞、锚点、音频、持续 VFX 和 HUD 布局写在场景里。

## 动作请求与唯一执行门

`HeroActionRequest` 是 Player/AI 共用的运行时意图，字段为 `source`、`action_id`、`skill_slot`、`target`、`direction`、`ground_position`、`has_ground_position`。它不包含 Utility 分数或决策生命周期。Player 输入直接构造请求；AI 的 `HeroAIDecision` 仅在 Actor 适配层转换为请求。两者都必须通过该英雄的 `can_execute_action(request)`，由 `execute_action(request)` 再次校验后进入同一攻击/技能实现。不能让 Player 构造 `HeroAIDecision`，也不能绕开 CD、沉默、Root、action lock 和技能特殊规则。AI 执行失败后立即重新评估，不能把失败候选当作已施放。

## 目标与手动施法语义

`SkillDefinition.target_type` 决定动作需要哪类输入：`self`/`self_area` 不需要单位目标；`direction` 使用持久玩家朝向并允许打空；`unit` 必须满足 `target_relation` 和施法距离；`ground_area` 要合法地面落点而不是单位目标。`target_relation` 由技能数据定义，`CombatTargetQuery` 统一处理 targetable、阵营、X/Z 平面距离、直线首命中与面向弧形命中。AI 可围绕目标决策，但 Player 的朝向不能被最近 AI 目标替换。命中和伤害仍由技能运行时结算，不由 HUD 或输入协调器复制。

## 数据、AI 与异步边界

Gameplay 数值只来自 `data/source/*.csv` 构建的 `CombatDatabase`。必需数据、场景和 VFX 模板缺失时 `push_error()` 并停止受影响行为；Inspector 只可调表现或预览。`HeroBrain` 只负责通用候选过滤、排序和决策滞后；英雄 action ID 和技能评分留在 HeroAIKit。`HeroAIContext.extras` 暂存英雄专属特征，仅对应 Kit 可读取；被多个英雄、archetype 或通用评估器使用的特征升级为 typed field（现有 `move_speed`、`recent_damage_ratio` 即如此）。

`ShortHorizonOutcomeEvaluator` 只比较普通走位 baseline 与某动作在短时域内的候选未来状态；权重来自 archetype，动作状态变化与资源成本来自 Kit，最终合法性仍在 Actor/SkillController。不要在此轮加入树搜索、连招搜索、Monte Carlo、TeamBrain、多人预测或英雄特例。异步动画事件、弹道、R 引导/落地必须先确认 Actor/目标仍有效，且技能完成、死亡和控制权变化不得遗留锁定状态。

## 新英雄开发及验收顺序

1. 定义 CSV 数据与技能目标语义，重建数据库并验证引用。
2. 建立场景、模型、动画器、固定锚点和 SkillController。
3. 实现共享 Runtime Action Gate 与所有手动技能，先验证无目标空放、方向命中、状态限制和死亡中断。
4. 通过手动运行时测试后，再接 HeroAIKit 与 AI 回归。
5. 完成队伍集成、HUD 只读展示、英雄档案和完整战斗回归。

每个结构阶段先跑定向测试、再跑完整战斗回归；结构改动与行为调整分开提交。自动化通过仅证明代码与无界面场景回归，不代替实际画面的视觉与手感验收。
