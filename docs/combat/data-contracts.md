# 战斗配表契约

## 单一事实源

源表位于 `data/source/`，构建器将其验证并生成 `data/generated/combat_database.tres`。禁止手工编辑生成资源。运行时状态，例如当前生命、冷却计时、Buff 层数和当前目标，不得写入共享 Resource。

## 16 张源表

| 表 | 主键 | 职责与关键约束 |
| --- | --- | --- |
| `combat_rules.csv` | `rule_id` | 全局常数和策略；改变结构时递增 `schema.version`；单元格不能执行表达式 |
| `stats.csv` | `stat_id` | 属性语义、单位、默认运算、上下限；只定义属性，不存英雄值 |
| `units.csv` | `unit_id` | 单位身份、角色定位、资源/射程类型、等级、技能和 AI 引用 |
| `unit_stats.csv` | `unit_id + stat_id` | 1 级值、成长值、成长公式、来源值和单位换算 |
| `skills.csv` | `skill_id` | 目标、施法类型、冷却、范围、持续时间、移动/朝向策略和表现引用 |
| `skill_effects.csv` | `effect_id` | 有序触发效果：伤害、Buff、控制、净化、延迟伤害和护盾 |
| `skill_ranks.csv` | `skill_id + rank` | 每级技能外壳数值：冷却、施放/恢复、范围、半径、持续与资源 |
| `skill_effect_ranks.csv` | `effect_id + rank` | 每级效果数值：基础值、系数、延迟、间隔与控制持续 |
| `unit_mode_modifiers.csv` | `unit_id + mode + stat_id` | 可选模式修正；明确操作和来源，不替代 Buff |
| `buffs.csv` | `buff_id` | 持续、层数、刷新、驱散、非致死和 VFX 生命周期 |
| `buff_modifiers.csv` | `modifier_id` | Buff 对属性的运算、阶段和优先级 |
| `hit_profiles.csv` | `profile_id` | 命中形状、尺寸、纵深、有效帧、停顿、硬直、削韧和击退 |
| `animation_events.csv` | `event_id` | 动画中的命中、音效、VFX、位移、取消和无敌事件 |
| `asset_manifest.csv` | `asset_id` | SpriteFrames、VFX、音频、Shader、缩放、局部三维位置、逐层不透明度、层级、朝向和生命周期 |
| `particle_profiles.csv` | `profile_id` | 粒子数量、寿命、速度、颜色、重力和尺寸 |
| `ai_profiles.csv` | `profile_id` | AI 行为、竞技场范围、技能序列和可复现随机种子 |

## ID、类型和单位

- ID 使用稳定的英文小写 `snake_case`；显示名不参与引用。
- 多个引用用 `|` 分隔，但只有字段本身声明为 ID 列表时才能使用。
- 百分比统一存为比例；`35%` 写作 `0.35`。
- 时间统一为秒；动画时序可用 `frame`、`normalized` 或 `seconds`，不可混写。
- X/Z 平面距离、速度和半径使用 Godot 世界米；Y 表示高度。
- 外部游戏单位必须保留来源值，并通过 `conversion_scale` 得到运行时值。
- 数值单元格只保存数值或枚举，不保存任意脚本表达式。

## 来源字段

`unit_stats.csv` 同时保存运行时和参考来源：

- `base_value`、`growth_value`：运行时规范化值。
- `growth_formula`：`none`、`primary` 或 `attack_speed`。
- `source_base_value`、`source_growth_value`：按项目比例约定规范化后的来源值。
- `conversion_scale`：来源单位到运行时单位的换算。
- `source_key`：Wiki 模板字段，例如 `hp_base|hp_lvl`。
- `notes`：模式、百分比规范化或项目自定义说明。

网址和查阅日期记录在 `docs/combat/heroes/<hero_id>.md`，并通过 `source_key` 与配表行对应。当前 schema 尚无通用 `source_id` 外键，因此缺少英雄档案时不得声称该数据可追溯。

## 技能和效果拆分

`skills.csv` 描述一次施法的外壳；`skill_effects.csv` 描述施法期间按 `order` 执行的效果。一个技能可以有多个效果，不得为了减少行数把伤害、控制和 Buff 塞进标签文本。

单位成长公式允许 `none`、`linear`、`primary` 和 `attack_speed`。`linear` 用于按等级等距成长的怪物数据；英雄的 LoL 式非线性成长继续使用 `primary`，不得混用。

`skills.csv` 的 `ability_kind`、`source_slot`、`identity_status` 和 `max_rank` 将英雄身份与参考槽位显式保存。当前单值字段仍是原型默认值；正式的分级值必须写入 `skill_ranks.csv` 与 `skill_effect_ranks.csv`，而非在单元格内编码数组。

项目统一技能记法为“P/Q/W/E/R/T”：P 是被动技能位，Q/W/E/R 是基础主动技能位，T 是项目扩展技能位。`source_slot` 只允许 `basic`、`p`、`q`、`w`、`e`、`r`、`t`；T 不代表参考游戏存在第五主动技能，其参考/原创身份仍由 `identity_status` 表达。

原型阶段可用重复的每级值表达“当前固定简化值”，但必须在 `notes` 标为待导入，不能伪装成来源数值。

禁止把 `30|60|90` 填入期望浮点数的字段来绕过 schema。

## Buff 修正规则

- `flat`：加固定值。
- `add_percent`：同一加法百分比层累加。
- `multiply`：独立乘区。
- `override`：按优先级覆盖。

预期聚合顺序为 `flat -> add_percent -> multiply -> override`。当前部分 Garen Buff 由控制器显式读取，完整通用聚合器仍属于待实现能力。

Buff 绑定的表现必须拥有兼容生命周期。`lifecycle=buff` 的 VFX/音频持续时间必须与 Buff 一致；动画型表现跟随序列帧结束；手动生命周期必须由控制器明确关闭。

## 动作与打击规则

命中数据不能只存在于动画观感中。每次攻击至少明确：

- 命中形状、尺寸、原点偏移和纵深容差。
- 有效起止时刻与对应动画事件。
- hitstop、hitstun、poise damage、knockback、decay 和 launch。
- 是否可暴击、伤害类型和目标选择器。
- 是否允许移动、转向、取消或重复命中同一目标。

角色水平翻转时只改变视觉朝向和依赖朝向的偏移；世界位置、攻击范围和逻辑原点不能漂移。

## 表间引用

- `units.skill_ids -> skills.skill_id`
- `units.ai_profile_id -> ai_profiles.profile_id`
- `units.instance_template_id -> hero | monster`；实例模板负责公共单位表现与伤害入口，具体 AI/移动/死亡状态机仍由派生角色脚本实现。
- `unit_stats.unit_id -> units.unit_id`
- `unit_stats.stat_id -> stats.stat_id`
- `skills.owner_id -> units.unit_id`
- `skills.vfx/audio_profile_id -> asset_manifest.asset_id`
- `skill_effects.skill_id -> skills.skill_id`
- `skill_ranks.skill_id -> skills.skill_id`，且 `rank <= skills.max_rank`
- `skill_effect_ranks.effect_id -> skill_effects.effect_id`
- `unit_mode_modifiers.unit_id -> units.unit_id`
- `unit_mode_modifiers.stat_id -> stats.stat_id`
- `skill_effects.buff_id -> buffs.buff_id`
- `skill_effects.hit_profile_id -> hit_profiles.profile_id`
- `buff_modifiers.buff_id -> buffs.buff_id`
- `buff_modifiers.stat_id -> stats.stat_id`
- `animation_events.payload_id ->` 与事件类型匹配的命中或资产 ID

构建器负责拒绝未知引用、重复主键、非法枚举、缺失资产、无效动画名、错误有效帧和不一致生命周期。

## 修改顺序

新增或调整英雄时建议按依赖顺序修改：

1. `stats` 与 `combat_rules`
2. `units` 与 `unit_stats`
3. `skills`、`skill_effects` 与等级表
4. `buffs` 与 `buff_modifiers`
5. `hit_profiles` 与 `animation_events`
6. `asset_manifest`、`particle_profiles` 与 `ai_profiles`
7. 角色档案、公式文档和自动测试

## 构建与验证

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path D:\godot_projects\gemheart2d --script res://scripts/tools/build_combat_database.gd
Godot_v4.7-stable_win64_console.exe --headless --path D:\godot_projects\gemheart2d --script res://tests/verify_combat_database.gd
Godot_v4.7-stable_win64_console.exe --headless --path D:\godot_projects\gemheart2d --script res://tests/verify_garen_skill_rules.gd
Godot_v4.7-stable_win64_console.exe --headless --path D:\godot_projects\gemheart2d --script res://tests/verify_combat_workflow.gd
```

构建成功只证明结构合法。英雄仍必须通过公式断言、机制断言和完整场景回归。
