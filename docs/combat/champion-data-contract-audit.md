# ChampionData 通用字段审计

## 审计范围

- 参考：League of Legends PC 的 ChampionData 通用字段定义。
- 页面：[Module:ChampionData/data](https://wiki.leagueoflegends.com/en-us/Module:ChampionData/data)
- 辅助检索：[Template:Data Garen/Basic Attack](https://wiki.leagueoflegends.com/en-us/Template:Data_Garen/Basic_Attack)
- 当前审计日期：2026-08-25。
- 项目边界：Gemheart 的 3D 横版动作原型，不复制 LoL 的模式、商店或完整数值系统。

ChampionData 同时包含三种性质的数据：英雄身份元数据、可结算的基础属性、以及用于描述普通攻击时序的源字段。Gemheart 目前已经覆盖了大量基础属性和动作字段，但不应把“有一个 stat ID”误认为“运行时已经支持该语义”。

你提供的官方 Lua 模板进一步确认了一个重要边界：它本身是“数据访问与展示包装器”，通过 `statsdata` 将 Riot 数据字段（例如 `hp`、`hpperlevel`、`attackspeedperlevel`）映射成 Wiki 的标准字段，并把 `windup`、模式修正和技能列表组合到输出中；它不是某一个英雄的永久数值快照。因此我们应参考它的字段契约和派生规则，而不是把整段 Lua 或展示字段直接搬进 Godot。

## 当前映射

| ChampionData 语义 | 当前归属 | 状态 | 结论 |
| --- | --- | --- | --- |
| `hp_base/hp_lvl`、`hp5_base/hp5_lvl` | `unit_stats.csv` | 已覆盖 | 保留 `source_key` 和 `conversion_scale`。 |
| `mp_base/mp_lvl`、`mp5_base/mp5_lvl` | `unit_stats.csv` 的资源字段 | 已覆盖 | `none` 成长仍需保留，不能假定所有英雄有资源。 |
| `arm/mr/dam/as/ms/range` | `unit_stats.csv` | 已覆盖 | 运行时使用规范化值，来源值单独保存。 |
| `as_ratio`、`windup_modifier`、`attack_delay_offset` | `unit_stats.csv` | 已扩展 | `attack_speed_ratio`、`attack_cast_time`、`attack_total_time`、`missile_speed` 均已分列；时序字段尚未替代当前动作前摇。 |
| `acquisition_radius`、`selection_radius`、`selection_height`、`gameplay_radius`、`pathing_radius` | `unit_stats.csv` | 已覆盖 | 这些字段与横版寻路/纵深规则兼容。 |
| `crit_base/crit_mod` | `critical_damage_base` + `critical_damage_modifier` | 已扩展 | 保留原 `critical_damage` 兼容现有运行时；新字段尚未接入最终伤害解析。 |
| `aram/nb/ofa/urf/usb/ar` 模式修正 | `unit_mode_modifiers.csv` | 已建模 | 表与验证已存在；训练场尚无修正行，通用模式聚合器待接入。 |
| `id/apiname/title/date/patch/changes` | `garen.md` 部分记录 | 文档覆盖 | 这是来源与身份元数据，不应强行变成战斗运行时字段。 |
| `role/positions/adaptivetype` | `units.csv` 的 `role/range_type` | 部分覆盖 | 当前 `role` 是战斗定位，不等价于来源的多角色/位置列表。 |
| `skill_i/skill_q/skill_w/skill_e/skill_r` | `units.skill_ids` | 部分覆盖 | 当前只列可施放技能，未显式表达被动与普通攻击。 |
| Basic Attack | `animation_events.csv` + 角色脚本 | 部分覆盖 | 命中帧已有，但伤害、目标和基础攻击生命周期还没有完整的 `skills/skill_effects` 契约。 |
| 被动技能 | `garen.md` 标记 missing | 未覆盖 | Perseverance 必须先进入技能/状态机映射，不能由原创 R 技能替代。 |
| 技能等级数据 | `skill_ranks.csv` / `skill_effect_ranks.csv` | 已扩展 | 类型化表、资源、构建校验和查询接口已完成；盖伦 Q 已接入参考五级数据，其他技能仍含明确标记的原型固定值迁移。 |

官方模板还明确区分了 `crit_base` 与 `crit_mod`，并把 `windup` 作为由 `attack_cast_time / attack_total_time` 或 `0.3 + attack_delay_offset` 得到的派生字段；这正是项目不能继续只保存一个手工 `attack_windup` 的原因。

## 需要完善的四个契约

### 1. 普通攻击和被动纳入技能身份

`units.skill_ids` 现在只表达主动技能，导致 ChampionData 的 `skills` 顺序与项目技能列表不完全对应。建议保留现有 `slot` 兼容性，并为 `skills.csv` 增加：

- `ability_kind`：`basic_attack`、`passive`、`active`；
- `source_slot`：`basic`、`p`、`q`、`w`、`e`、`r`、`t`；其中 `p` 是被动、`t` 是项目扩展技能位；
- `identity_status`：`faithful`、`simplified`、`adapted`、`original`、`missing`。

普通攻击应拥有自己的 `skill_effects` 和 `hit_profile`，动画事件只负责把命中窗口绑定到它；被动则应能引用 Buff 或状态机。这样盖伦的基础攻击和 Perseverance 才能与装备系统共享同一套结算入口。

### 2. 技能等级数据从单标量升级为类型化分表

当前 `base_value=115` 这类标量无法表达 1–5 级技能，也不应把 `30|60|90` 填进一个浮点单元格。建议新增两张源表：

```text
skill_ranks.csv
skill_id,rank,cooldown,cast_time,recovery_time,cast_range,radius,duration,tick_interval,resource_cost

skill_effect_ranks.csv
effect_id,rank,base_value,scaling_coefficient,target_missing_health_coefficient,delay,interval,control_duration
```

规则：

- `rank` 为整数，范围由 `progression.skill_rank_cap` 控制；
- 没有等级成长的技能可以只有一行 `rank=1`；
- 公式仍然放在类型化代码中，表格只保存数值和引用；
- 运行时按技能等级选择行，再叠加属性、Buff 和动作命中规则；
- Garen 的被动与 Q/W/E/R/T 应先迁移到该契约，再处理 AD 系数、攻速转数和 R 的终结公式。

### 3. 补齐普通攻击时序源字段

ChampionData 将 `windup` 视为派生值，来源可以是 `attack_cast_time / attack_total_time`，或 `0.3 + attack_delay_offset`。项目目前直接填 `attack_windup`，这会丢失来源时序，影响不同英雄的基础攻击帧适配。

建议新增 stat ID：

- `missile_speed`；
- `attack_cast_time`；
- `attack_total_time`；
- `attack_range_growth`；
- `move_speed_growth`；
- `critical_damage_base`；
- `critical_damage_modifier`。

其中 `attack_windup` 继续保留为派生/项目动作值；若来源时序为空，则显式使用项目动作值并在 `notes` 标记 `project_fallback`，不能静默混用。

### 4. 预留模式修正，但暂不接入训练场

ChampionData 的模式修正包括输出伤害、承伤、治疗、护盾、总攻速、移速、韧性和技能急速。它们不应扩展成 `aram_damage_taken` 这类大量 stat ID，也不应污染英雄基础属性。

未来建议：

```text
unit_mode_modifiers.csv
unit_id,mode,stat_id,operation,value,source_key,notes
```

第一阶段只实现 `default`/`training`，等 PVP 场景真正需要时再加入 `aram`、`arena` 等模式。这样装备系统和场景规则可以复用同一套 modifier 聚合器。

## 当前优先级判断

在修改盖伦技能内核前，优先级应为：

1. 新增普通攻击/被动的身份字段，但先不破坏现有主动技能 ID。
2. 完成 `skill_ranks` 和 `skill_effect_ranks` 的类型化 schema 与数据库验证。
3. 补齐基础攻击时序字段，明确 `windup` 的 reference/derived/project 来源。
4. 为属性解析器增加“基础值 → 等级成长 → Buff → 装备”的聚合入口。
5. 再迁移盖伦被动与 Q/W/E/R/T 的技能公式和等级数据。
6. 最后实现装备系统；装备只提供 modifier，不直接改技能控制器或角色脚本。

## 暂不引入的字段

ChampionData 中的客户端难度评分、商店价格、图标名、第三方位置统计和 lore 元数据暂时留在英雄档案，不进入战斗数据库。只有当选择界面、图鉴或 UI 真正消费它们时，才新增独立的展示元数据表。

## 结论

现有战斗表的职责划分可以保留；技能身份、技能等级、普通攻击时序和模式修正的契约已经扩展为 16 张源表。剩余关键阻塞项是：把基础攻击/被动真正迁入统一技能入口、用可追溯的逐级来源值替换盖伦的原型固定行，以及实现模式与装备的通用聚合器。
