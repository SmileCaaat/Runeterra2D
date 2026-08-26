# 公式与来源索引

本文记录当前 schema v10 中实际使用的公式。外部页面会随补丁更新，以下网址是语义入口而不是永久不变的数值快照；具体英雄数值以对应英雄档案的查阅日期为准。

## 记号

- `L`：英雄等级，当前规则限制为 1–30。
- `n = L - 1`。
- `B`：基础值，`G`：成长系数。
- `AD`、`AP`：攻击力和法术强度。
- `Hcur`、`Hmax`：目标当前和最大生命。
- 比例统一存为小数，例如 35% 存为 `0.35`。

## 来源入口

| 来源 ID | 用途 | 网址 | 最近核对 |
| --- | --- | --- | --- |
| `LOL-CHAMPION-STATS` | 英雄属性分类与成长公式 | [Champion statistics](https://wiki.leagueoflegends.com/en-us/Category:Champion_statistics) / [Champion statistic](https://wiki.leagueoflegends.com/en-us/Champion_statistic) | 2026-08-23 |
| `LOL-GAREN-DATA` | Garen 基础属性与数据字段 | [Template:Data Garen](https://wiki.leagueoflegends.com/en-us/Template:Data_Garen) | 2026-08-23 |
| `LOL-ARMOR` | 正负护甲语义 | [Armor](https://wiki.leagueoflegends.com/en-us/Armor) | 使用前重新核对 |
| `LOL-MR` | 正负魔抗语义 | [Magic resistance](https://wiki.leagueoflegends.com/en-us/Magic_resistance) | 使用前重新核对 |
| `LOL-HASTE` | 技能急速语义 | [Ability haste](https://wiki.leagueoflegends.com/en-us/Ability_haste) | 使用前重新核对 |
| `LOL-TENACITY` | 韧性与控制缩减语义 | [Tenacity](https://wiki.leagueoflegends.com/en-us/Tenacity) | 使用前重新核对 |
| `LOL-CRIT` | 暴击概率和暴击伤害语义 | [Critical strike](https://wiki.leagueoflegends.com/en-us/Critical_strike) | 使用前重新核对 |
| `LOL-GAREN-PASSIVE` | Perseverance 的回复比例和受伤抑制语义 | [Perseverance](https://wiki.leagueoflegends.com/en-us/Template:Data_Garen/Perseverance) | 2026-08-25，数值由用户提供的当前模板截图核对 |
| `LOL-GAREN-Q` | Decisive Strike 的 5 级持续、额外伤害、沉默与强化普攻语义 | [Decisive Strike](https://wiki.leagueoflegends.com/en-us/Template:Data_Garen/Decisive_Strike) | 2026-08-25，数值由用户提供的当前模板截图核对 |
| `LOL-GAREN-E` | Judgment 的五级冷却、每转物理伤害、攻速转数、最近目标增伤与破甲语义 | [Judgment](https://wiki.leagueoflegends.com/en-us/Template:Data_Garen/Judgment) | 2026-08-25，数值由用户提供的当前模板截图核对 |
| `LOL-GAREN-R` | Demacian Justice 的三级冷却、施法时间、真伤与缺失生命值系数 | [Demacian Justice](https://wiki.leagueoflegends.com/en-us/Template:Data_Garen/Demacian_Justice) | 2026-08-26，数值由用户提供的当前模板截图核对 |

## 已实现的通用公式

### 主属性成长

来源类型：`reference`，来源 `LOL-CHAMPION-STATS`。

```text
growth_factor(L) = n × (0.7025 + 0.0175 × n)
stat(L) = B + G × growth_factor(L)
```

`0.7025`、`0.0175` 和等级上限位于 `combat_rules.csv`。运行位置是 `CombatDatabase.get_unit_stat_value()`；生命、生命回复、攻击力、护甲和魔抗等成长属性使用 `growth_formula=primary`。

### 攻击速度成长

来源类型：`reference`，来源 `LOL-CHAMPION-STATS` 和英雄数据模板。

```text
AS(L) = ASbase + (bonus_AS + ASgrowth × growth_factor(L)) × ASratio
```

当前单位初始值计算时 `bonus_AS=0`。Wiki 显示的百分比成长先规范化为比例，例如 `3.65% -> 0.0365`。

### 怪物线性成长

来源类型：`project/reference adaptation`。外部资料提供怪物在 1–18 级的端点值，Gemheart 使用 `growth_formula=linear` 保存等距插值，不套用英雄的非线性成长曲线。

```text
stat(L) = B + G × (L - 1)
```

当前迅捷蟹首次刷新生命为 `1007.5 + 142.235294 × (L - 1)`，普通形态为 `1550 + 218.823529 × (L - 1)`；运行位置为 `CombatDatabase.get_unit_stat_value()`。

### 正负抗性

来源类型：`reference`，语义参考 `LOL-ARMOR` 与 `LOL-MR`；曲线常数 `C=100` 为当前 `combat_rules`。

```text
R >= 0: damage_after_resist = raw × C / (C + R)
R < 0 : damage_after_resist = raw × (2 - C / (C - R))
```

物理伤害使用护甲，魔法伤害使用魔抗，真实伤害不进入此公式。当前穿透属性已经建模，但尚未接入最终伤害流水线；文档和测试不得宣称其已经生效。

### 技能急速

来源类型：`reference`，语义参考 `LOL-HASTE`；最低冷却是 Gemheart 项目限制。

```text
cooldown = max(minimum_cooldown, base_cooldown × 100 / (100 + ability_haste))
```

### 韧性

来源类型：`adapted`，比例结构参考 `LOL-TENACITY`，80% 上限和 0.1 秒下限来自 Gemheart `combat_rules`。

```text
resolved_duration = max(0.1, base_duration × (1 - clamp(tenacity, 0, 0.8)))
```

仅允许缩减的控制才能使用该公式；击飞、固定演出或未来定义为不可缩减的控制必须在控制类型规则中明确排除。

### 暴击与当前伤害顺序

来源类型：暴击语义为 `reference`，最低伤害与结算顺序为 `project`。

```text
raw = configured_damage × (critical_damage if critical else 1)
resisted = resistance_formula(raw)
final = max(minimum_damage, resisted)
```

只有 `can_crit=true` 的攻击才进行暴击判定。当前训练木桩结算顺序是“暴击 -> 抗性（真实伤害跳过）-> 最低伤害 -> 普通护盾 -> 扣生命”。普通护盾可吸收任意伤害类型，包括真实伤害；当前以各训练目标的 `normal_shield` 运行时余额实现。穿透、多个护盾的顺序、护盾强度、护盾破裂、吸血和完整伤害修正分层尚未形成通用流水线。

### 通用技能伤害数据契约

来源类型：`project`，用于承载参考英雄的常见公式结构。

```text
missing_ratio = 1 - Hcur / max(Hmax, 1)
raw = base_value
    + scaling_coefficient × scaling_stat
    + target_missing_health_coefficient × missing_ratio
```

当前 `SkillEffectDefinition` 已具有这些字段，但运行时仍有部分技能由角色控制器显式执行。新增英雄不能假定通用效果执行器已经覆盖全部触发器；必须用测试证明实际接线。

### 坚忍（Perseverance）

来源类型：回复比例与 8 秒受伤抑制为 `reference`，连续结算为 `simplified/project`。Garen 在 1–30 级采用用户提供的当前模板分段值：1 级 1.5%、6 级 2.5%、13 级 8.1%、30 级 14.9%，单位均为“每 5 秒最大生命回复比例”。

```text
early = min(max(L - 1, 0), 5)
middle = min(max(L - 6, 0), 7)
late = max(L - 13, 0)
regen_ratio_per_5 = 0.015 + 0.002 × early + 0.008 × middle + 0.004 × late
healing_per_second = Hmax × regen_ratio_per_5 / 5
```

任何有效的入伤都会刷新 `8s` 抑制计时。当前原型尚未区分英雄、史诗野怪、防御塔或技能来源，因此把所有有效敌方入伤视为可抑制事件；这是有意识的简化。回复以连续生命值结算，5 秒总量与参考语义相同，避免横版动作游戏中明显的跳血。

## 当前 Garen 项目公式

| 项目技能 | 当前公式 | 来源类型 | 说明 |
| --- | --- | --- | --- |
| 破舰 | `base_raw = AD × (crit_damage if base_attack_crit else 1)`；`bonus_raw(rank) = [30,60,90,120,150] + 0.50×AD`；`raw = base_raw + bonus_raw` | `adapted/reference` | Q 等级为技能等级（开局 1 级），普攻本体可暴击、Q 额外伤害不可暴击；35% 加速持续 `[1.4,1.95,2.5,3.05,3.6]s` |
| 黑帆 | 承伤 `incoming × 0.70`；控制时长 `duration × 0.70`；被动抗性乘数 `1.20` | `adapted/reference` | 机制参考 W，项目采用固定比例 |
| 翻江倒海 | `per_spin(rank) = [4,7,10,13,16] + [0.40,0.43,0.46,0.49,0.52]×AD`；`spins = 7 + floor(bonus_AS / 0.25)` | `adapted/reference` | 每转物理伤害可暴击；最近目标乘 `1.25`；同一目标第 6 次及后续每第 6 次命中施加 25% 破甲 6 秒 |
| 暴君审判 | `base(rank) + Hmax × missing_ratio × coefficient(rank)`；`base=[125,200,275]`，`coefficient=[0.25,0.30,0.35]`，真实伤害 | `adapted/reference` | 三档冷却 `[120,100,80]s`，施法 `0.435s`，400 来源距离换算为 `4.0m`；真伤绕过抗性，普通护盾在扣生命前吸收它 |
| 七海霸权 | `180` 物理范围伤害并眩晕 `2.0s` | `project` | 原创扩展，没有外部公式来源 |
| 坚忍（被动） | `Hmax × regen_ratio_per_5 / 5`，受伤后抑制 `8s` | `simplified/reference` | 比例沿 1–30 级分段成长；当前任何有效入伤均会重置抑制 |

Garen 技能入口：

- [Perseverance](https://wiki.leagueoflegends.com/en-us/Template:Data_Garen/Perseverance)
- [Decisive Strike](https://wiki.leagueoflegends.com/en-us/Template:Data_Garen/Decisive_Strike)
- [Courage](https://wiki.leagueoflegends.com/en-us/Template:Data_Garen/Courage)
- [Judgment](https://wiki.leagueoflegends.com/en-us/Template:Data_Garen/Judgment)
- [Demacian Justice](https://wiki.leagueoflegends.com/en-us/Template:Data_Garen/Demacian_Justice)

## 项目自有动作公式

以下内容是 Gemheart 的横版动作规则，没有对应 LoL Wiki 公式：

- 命中有效区间：动画归一化时间满足 `active_start <= t <= active_end`。
- 击退：初速度来自 `knockback_speed`，每帧向零衰减 `knockback_decay × delta`。
- 纵深判定：攻击者和目标在 Z 轴或平面距离上必须满足 `depth_tolerance` 与命中形状。
- 朗姆酒延迟伤害：伤害进入 `delayed_damage_pool`，在剩余 Buff 时间内按剩余池比例摊销，生命下限为 `1`；黑帆可令池中伤害乘以 `0.70`。
- hitstop、hitstun、poise damage、launch velocity 和取消窗口均来自命中/动画事件配表，不从 LoL 数值推导。
- 迅捷蟹刷新、逃跑、归航和加速法阵表现参数来自 `combat_rules`；法阵持续时间与 30% 移速来自 `buffs` 和 `buff_modifiers`，移动形态速度来自 `unit_stats`。
- 七海霸权视觉横向覆盖约为 `1166 px × 0.006 m/px × 1.5 = 10.494 m`；项目将圆形伤害直径取为 `10.4 m`，即 `skills.radius=5.2 m`，并同步 `ghostship_hit` 的 X/Z 尺寸与纵深容差。
- 破舰的横版追击是项目动作化规则：强化普攻开始时，目标距离在普通攻击贴身范围外且不超过 `2.4m`，角色在 `0.12s` 内移动至目标前 `0.85m`；规则分别位于 `garen.breaker.lunge_duration` 与 `garen.breaker.lunge_standoff`。这不是 LoL 距离数值的直接换算。

## 尚未完成的公式语义

以下属性已经拥有 stat ID，但尚未形成完整、统一且经过测试的运行时公式：

- 固定/百分比护甲和魔抗穿透的结算顺序。
- 生命偷取、物理吸血、全能吸血与范围技能衰减。
- 治疗/护盾强度、多护盾 FIFO 和护盾破裂。
- 霸体恢复、削韧、击退抗性和击飞抗性的统一结算。
- Buff 的 `flat -> add_percent -> multiply -> override` 完整聚合器。
- 技能等级数组与英雄等级分段公式。

这些条目只能标为“已建模/待实现”，不能在设计说明中写成“系统已支持”。
