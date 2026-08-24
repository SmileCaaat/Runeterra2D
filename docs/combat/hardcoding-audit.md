# 战斗系统硬编码审计

审计日期：2026-08-24。范围包括 Garen、训练假人、迅捷蟹、加速法阵、战斗数据库构建器和程序化命中特效。

## 已迁移为单一事实源

- Garen 的技能冷却、持续时间、范围、伤害、Buff、控制、命中配置、动画资产和音频继续分别由 `skills`、`skill_effects`、`buffs`、`buff_modifiers`、`hit_profiles`、`animation_events` 和 `asset_manifest` 管理。
- 破舰残影、技能4/5震荡、Anchor 回弹与尾段、水汽爆炸、命中帧和镜头震动进入 `combat_rules`；碎片与水汽粒子进入 `particle_profiles`。
- 迅捷蟹的战斗/脱战/冲刺速度、两种生命成长和导航脱离距离进入 `unit_stats`；路径容差来自 `ai_profiles`。
- 迅捷蟹刷新、逃跑、归航和死亡渐隐进入 `combat_rules`。
- 加速法阵的持续时间和 30% 移速进入 `buffs`/`buff_modifiers`；作用半径、渐显、呼吸、透明度与旋转周期进入 `combat_rules`。
- 怪物等级端点采用 schema v3 的 `linear` 成长公式，不再由迅捷蟹脚本重复计算。

## 允许保留在代码或场景中的内容

- 状态机分支、目标选择、线段投影、插值公式和对象池生命周期属于可执行逻辑，不是数据值。
- 训练场的路径点、场地原点和允许刷新模式属于关卡几何/场景配置。
- 节点路径、Shader uniform 名称、动画状态名和组名属于资源契约；在没有独立资源绑定 schema 前保留为类型化代码常量。
- Inspector 数值仅作为数据库缺失或资源损坏时的 fallback，不再作为正常运行的权威值。

## 后续 schema 候选

- 程序化 VFX 的通用 profile：震荡波、镜头震动、回弹曲线和 Shader 参数目前使用命名空间化 `combat_rules`，未来可独立成 `vfx_profiles`。
- 场景生成规则：若更多地图拥有不同野怪刷新表，应新增 `encounter_profiles` 或游戏模式表，而不是继续扩充全局规则。
- 阵营描边和受击弹性仍是场景表现参数；当多角色复用后应建立统一 `faction_visual_profiles`。
