# 3D 角色表现管线

## 当前决策

训练场验证确认：带骨骼动画的 GLB 已替代盖伦、瑞兹、迅捷蟹和木桩假人的**角色本体**序列帧，并在正交 3D 战斗空间中保持移动、纵深、受击、技能状态机、命中事件与阵营识别。四类角色旧本体序列帧及生成/优化工具已清理；独立技能、命中、UI 与场景表现使用的 SpriteFrames 不在清理范围内，继续保留。

## 边界与所有权

| 层 | 当前实现 | 迁移状态 |
| --- | --- | --- |
| 角色本体 | GLB + `AnimationPlayer` + 语义状态机 | 已用于 Rogue Admiral Garen、训练木桩、迅捷蟹与 Rune Mage Ryze |
| 战斗时序 | `animation_events.csv` 的 `normalized` / `seconds` 事件 | 保持数据驱动；不将伤害事件绑定到 GLB 原始动画名 |
| 阵营识别 | 低透明度脚底阵营环 + Toon Shader 弱阵营 Fresnel | 友军、敌军使用柔和青蓝/暖红提示；中立单位使用柔和黄色提示 |
| 交互高亮 | `MeshOutlineHighlight3D` 倒壳描边 | 默认关闭；仅被选中、当前目标或特殊强调时显示 |
| 2D 技能与命中 | SpriteFrames、Sprite3D、SubViewport/粒子 | 继续使用，不属于本体迁移清理范围 |
| 旧角色本体序列帧 | 盖伦、瑞兹、迅捷蟹与木桩假人的源图集、SpriteFrames 与生成工具 | 已完成无引用审计并清理；技能与 VFX 序列帧独立保留 |

## 角色状态机契约

状态机对上层只暴露项目语义名，例如 `idle1`、`run`、`attack1`、`spell1`、`death`。每个角色自己的 animator 负责将它们翻译成 GLB 内的动画名；战斗 AI、伤害和事件表只读取语义名。这样更换美术模型、改 GLB 动画命名或为角色设置独立播放倍率时，不会改变技能 ID、伤害结算或命中 Profile。

所有角色继续以 X/Z 平面作为游戏逻辑。模型可以根据目标的 Z 差加入有限视觉偏航，但偏航不得参与攻击范围、碰撞、索敌、伤害方向或左右逻辑面向。

## 光照、Toon 与描边

- `Camera3D.projection = orthogonal` 本身不会禁用 Toon 或真实 3D 光照；但角色左右朝向会改变法线相对方向主光的夹角。本项目当前优先保证亮度稳定，因此角色暂用 `unshaded`。
- `character_toon_3d.gdshader` 使用 `unshaded`，让模型亮度不随 ±X 朝向和场景方向光变化；保留纹理色与弱 team Fresnel，暂不追求 Toon 明暗分段。角色 shader 不得写入透明 `ALPHA`；否则本体会进入透明队列并与外扩描边发生深度闪烁。
- `UnitReadabilityLayers` 在地面绘制低透明度椭圆队伍环，并按碰撞半径计算尺寸；脚环参与深度测试，帮助表达角色在场景中的 Z 轴位置。
- `character_toon_3d.gdshader` 通过视线与法线 Fresnel 叠加弱 team rim。环颜色、透明度、尺寸、Rim 色和强度均可配置。
- `MeshOutlineHighlight3D` 与阵营无关，复制本体网格并沿法线外扩，沿用骨骼路径。`set_selected(bool)`、`set_targeted(bool)` 和 `set_highlighted(bool)` 按优先级切换细描边；默认状态隐藏外扩网格。
- Buff、Debuff、霸体和护盾不使用交互描边表达，应使用残影、护盾壳、身体粒子或局部状态特效。

## 已验收的盖伦普攻校准

Rogue Admiral Garen 的 GLB `Attack1`、`Attack2` 与 `Crit` 原始时长均为 `2.00s`；`GarenModel.semantic_speed_scales` 将三段普攻设为 `2.5`，使完整动作约为 `0.80s`，55% 归一化命中事件约在 `0.44s` 触发。这只改变视觉播放速率：命中事件、伤害、音频、取消窗口与 attack profile 保持原有语义。

## 验证与后续迁移

历史回归包括 `verify_combat_workflow.gd`、`verify_garen_skill_rules.gd`、`verify_target_dummy_workflow.gd` 与 `test_scuttle_crab.gd`。新角色迁移至少应验证：GLB 成功导入、语义动画都存在、左右面向/视觉偏航、命中与音频时机、队伍环和交互高亮、Toon 受光、死亡/复活与原有技能 VFX。

本体序列帧清理已完成：场景、脚本、配表与测试不再依赖四类角色本体图集。瑞兹的原始帧时序已转换为秒制事件；技能与命中 VFX 图集仍独立使用 SpriteFrames，不随本次清理删除。
