# Ryze 参考与改编档案

> 本文是瑞兹的唯一档案。前半有早期设计快照，其中“QWE 全程尾三帧取消”、护盾滤色及“尚未实现/未入表”等表述已过时，以本文后半锁定决策和文末视觉验收为准。已有 CSV、场景和脚本，不要据此从零重做；已有文件也不等于功能验收完成。普攻第 6 帧发球、Q 第 4 帧发球、W 第 6 帧结算、E 第 7 帧发球（表内零基 5/3/5/6）；普攻和 QE 在投射物接触时结算。超负荷改为施法加速 1.8 倍加盖伦 Q 残影；出手后按最短锁解锁，剩余帧可被下一动打断。T 按爆发窗开，R 按开团/切入/逃生折跃。`TBuff` 与 `RWinddown` 以当前 `ryze.tscn` 为准。工程交接见 [cursor-handoff.md](../../../docs-design/cursor-handoff.md)。

## 来源快照

- 目标：League of Legends PC（非 Wild Rift、TFT 或 Arena）。
- 最近核对：2026-09-04。
- 当前数值参考：[Ryze](https://wiki.leagueoflegends.com/en-us/Ryze)。页面语义由 [Data Dragon `16.17.1` 的 Ryze 数据](https://ddragon.leagueoflegends.com/cdn/16.17.1/data/en_US/champion/Ryze.json) 同次核对；将来实际入表前必须再次核对当前 Wiki 数据模板或补丁说明。
- 技能形态参考入口：[Ryze/History](https://wiki.leagueoflegends.com/en-us/Ryze/History)。已选择 History 第 2 套形态用于 P/Q/W/E，并将其 `Desperate Power` 改编为项目觉醒槽 T；该历史快照的精确数值与结构来自用户于 2026-09-04 提供的六张技能截图。R 则保留当前 `Realm Warp` 形态与数值锚点。
- 原画来源（已复制到 `res://assets/vfx/ryze_skills/符文法师 - 原画.jpg`，作为后续觉醒 Cut-In 或角色展示候选）：`D:/1Gameassets_share/SpriteAssets/Skills/Ryze_spell_sheet_json_20260831_033950Z/符文法师 - 原画.jpg`。
- 已知限制：历史页本次无法由自动抓取器读取正文，因此第 2 套形态以用户截图作为本项目的可追溯快照；后续若出现截图未覆盖的历史细节，不得依靠记忆补写。

## 身份摘要

瑞兹是以法力值缩放为核心的短冷却法师：施法叠加奥术精通，满层进入超负荷状态以获得护盾、连续施法与冷却缩减；Q 为直线符文弹，W 为直接定身，E 是叠层减魔抗并在目标群间往返的法球，T 将其基本技能的单点命中扩展为主目标周围的范围伤害，R 保持团队传送门。横版化必须保留“施法叠层 → 短时强化施法窗口 → 用 E 降抗并通过 Q/W/T 兑现伤害”的编织式循环，而不能退化为互不关联的法术按钮。

## 已锁定项目决策

- P 对每一次主动技能施放完成叠加 1 层奥术精通；所有层数统一刷新为 6 秒、最多 5 层。T 引导结束后直接授予满层超负荷（刷新 5 次强化与 2.5 秒窗口并清空奥术层），绝不消耗超负荷次数。
- 满层 P 立即获得来源护盾 `25–110（随英雄等级）+ 0.08 × 最大法力`，并进入超负荷窗口。该窗口只在 Q/W/E 成功施放时消耗次数；R 与 T 不消耗该窗口。窗口双重结束条件为“至多 5 次 Q/W/E”或“按 Q 等级持续 2.5–5 秒”。
- 每次消耗超负荷次数的 Q/W/E 施放完成后，将瑞兹所有正在冷却的技能减少 Overload 的冷却量；本次采用 History 2nd 的 `4s` Overload 冷却量，并钳制至 `0`。这意味着 Q/W/E 消耗次数，但冷却缩减对象仍是“瑞兹所有正在冷却的技能”，包含 R/T；如后续希望排除 R/T，应单独改写此项目规则。
- 满层护盾使用 `Ryze_Shield` 的 32 帧循环表现，并在护盾存在期间跟随瑞兹；其独立材质使用 Screen（滤色）合成。护盾美术不影响护盾数值与生命周期。
- E 的百分比减魔抗逐层乘算：第 n 层作用于前一层后的剩余魔抗，不采用加算。
- R 保留当前传送门意图，但只传送瑞兹及其身边友军。友军选取来源半径为 550（与瑞兹普通攻击来源距离一致）；项目运行时距离、目的地短距离上限与竞技场边界钳制将在场景接线时统一定义，不直接把 LoL 距离当作米。
- T 需要完整、可复用的“技能伤害治疗/法术吸血”流水线；不能用仅瑞兹可见的脚本特例替代通用机制。
- 瑞兹职业采用 `mage → battlemage`。基础轮盘仍是中距离 E 降抗、W 控制、Q 输出；T 与 R 是瑞兹专属决策，不套盖伦式低血觉醒或终结技。
- T（绝望之力）是爆发强化 Buff：只在可兑现连招时开（Q/W/E 至少两个就绪，或奥术 ≥4 层，或已在超负荷）。不按自身残血开。引导 0.8 秒结束后开始 6 秒强化，并同时授予满层超负荷。
- R（曲境折跃）是战场折跃：过近或被围时反向逃生，超出 `5.5m` 且仍在 `25m` 内、手头有技能可兑现时折跃切入/开团。切入落点停在 Battlemage 偏好距离 `3.0m`，不叠进目标碰撞体。开团与逃生落点都必须留在 `GroundMesh` 有效范围内：以地面 AABB 内缩 `0.6m` 后，再和 `ryze_demo` 档案边界取交集。训练场地砖为 `32 × 8`，纵深只有 ±4m，档案不得再写成 ±4.3。
- 战斗站位保持中距离：进入 `5.5m` 后若近于 `3.0m` 则后撤，不贴脸输出。
- E 弹射可以把瑞兹自己当作链路节点，但自身不受 E 伤害、减抗或 Impact。T 溅射只打主目标周围敌人，绝不打自己或同阵营；T 的 15% 吸血不得在瑞兹身上弹出伤害数字。
- 超负荷窗口要让连招更强势：窗口内普攻与 Q/W/E 的施法动画速度为 `ryze.supercharge.cast_speed_scale = 1.8`（绝对值，不与常态 1.35 叠乘），并复用盖伦破舰 Q 的加速残影。图集帧不删；出手后按 `max(出手时刻 + recovery, min_lock)` 解锁，剩余演出可被下一动打断。T、R、受击与跑步不受该加速与解锁影响。
- E 初段与弹射法球外包一层 `ElasticVoxelShell` 符文青体素（数量/尺寸/半径/颜色走 `ryze.e.voxel_*`，颜色含低透明度 `78d9ff59`）。壳跟 `Spell3_E` 作者原点，不跟画布中心，也不叠 `E_LAUNCH_Y_BIAS`。弹射额外做挤压回弹与双正弦弧，只改观感，不改命中距离、速度或伤害。

## 横版动作与表现契约

| 项目技能/动作 | 目标与距离 | 动作、命中与取消 | 表现生命周期 |
| --- | --- | --- | --- |
| 普攻 | 来源距离 `550 → 5.5m`；法球速度 `1300 → 13m/s`；碰撞宽度 `85 → 0.85m` | `attack1 → attack2 → attack3 → crit` 为连续四段；不可移动施放、允许转向；法球接触目标时结算伤害 | 使用 `basic_attack` 的 12 帧法球图集；命中停顿/受击硬直/击退分别为盖伦普攻的 `1/3`：`0.02s / 0.08s / 0.933m/s` |
| Q · Overload | 方向投射物；来源距离 `550 → 5.5m`、宽 `110 → 1.1m`、速度 `1700 → 17m/s`；仅首个命中敌人受击；纵深容差 `1.1m` | 无霸体；伤害有效时点是法球接触目标，而非角色 `spell1` 的某一帧；命中反馈与盖伦普攻相同：停顿 `0.06s`、硬直 `0.24s`、击退初速 `2.8m/s`；普攻与 QWE 常态加速 1.35、超负荷 1.8，出手后按最短锁解锁 | 角色播放 `spell1`；命中时播放 `impact` |
| W · Rune Prison | 锁定目标；来源距离 `550 → 5.5m`；目标指向、必中，非投射物，不做纵深容差判定 | 无霸体；角色 `spell2` 第 5 帧同步结算伤害与 `1 / 1.1 / 1.2 / 1.3 / 1.4s` 定身；无击退，受击硬直为盖伦普攻 `1/4 = 0.06s`；未指定额外命中停顿，暂定 `0s` | 目标处同步播放 `Spell2_W`；命中时播放 `impact`；定身存续期间循环 `W_loop`，结束时立即停止 |
| E · Spell Flux | 锁定目标；来源距离 `550 → 5.5m`；初段投射物速度 `1500 → 15m/s`；弹射半径 `350 → 3.5m`、弹射速度 `1500 → 15m/s`；目标指向，不做纵深容差判定 | 无霸体；初段和每次弹射的伤害有效时点均为法球接触目标；命中反馈为盖伦普攻 `1/3`：停顿 `0.02s`、硬直 `0.08s`、击退初速 `0.933m/s`。链路包含主目标并将其作为后续弹射起点；无次级目标时回弹主目标；同一目标单链受伤次数不设上限。可把瑞兹自己当弹射节点，但自身不受伤害或减抗 | 初段及弹射均用 `Spell3_E`，外包 `ElasticVoxelShell` 体素壳；弹射额外挤压回弹。每次命中播放 `impact`。减抗复用盖伦破甲那套小图标弹出/晃动/回弹，贴图为 `MagicResistanceReduction.png` |
| T · Desperate Power | 自身；基本技能外溢半径 `350 → 3.5m`；来源 `+80` 移速按既定比例换算为 `+0.8m/s` | 播放 `taunt` 后进入 6 秒觉醒强化；引导期间拥有霸体，强化持续期不默认继承霸体；引导结束授予满层超负荷且不消耗次数；保留被动冷却缩减 `10 / 20 / 30%` | 觉醒 Cut-In 使用原画与 `Ryze_awake.wav`；`TBuff` / `Shield` 手调 +X，`TBuffFlip` / `ShieldFlip` 手调 -X，运行时按朝向选用对应节点，不改 Transform。强化 6 秒内循环 `T_Buff`；引导期复用盖伦 `SuperArmorOutline` 黄红黄轮廓。触发外溢的主目标命中叠一层 `Lightning Chain` one-shot（`vfx_library_lightning_chain`） |
| R · Realm Warp | 友军选取来源半径 `550 → 5.5m`；最大传送来源距离 `2500 → 25m`；落点与传送路径钳在 `GroundMesh` 与 `ryze_demo` 交集内 | 2 秒引导仅能被沉默、眩晕、击飞打断；打断/主动取消后全额返还冷却。传送落地后强制进入专属 `spell4_winddown` 出生动作；以落点为中心 `5.5m` 内每个敌人承受 3 次 E 初段伤害并直接获得 3 层 5 秒乘算减魔抗，不生成 E 初段弹道、分裂或回弹 | 角色 `spell4_winddown` 与场景 `RWinddown` 同步；特效用 `ryze.tscn` 手调 Transform，时长等于落地动画，随朝向翻转 X。范围内每个受伤敌人脚底播一次 `VFXZapLightning_01`；T 外溢到的敌人同样各一次。缩放 `ryze.r.zap_scale`，不跟三次 E 重复播放 |

### 超负荷施法加速

- 图集帧完整保留，不删尾帧。出手后不再用整段动画当 `action_lock`。
- 常态普攻与 Q/W/E 的 `speed_scale` 为 `ryze.cast.speed_scale = 1.35`。超负荷窗口内改为 `ryze.supercharge.cast_speed_scale = 1.8`。命中帧序号不变，只是更快到达。
- 解锁时刻为 `max(出手时刻 + ryze.cast.recovery_seconds, min_lock)`。常态最短锁 `0.90s`，超负荷最短锁 `0.70s`。下一动 `play()` 可打断剩余演出。
- 同一窗口内，普攻与 Q/W/E 换帧时留下盖伦破舰 Q 同款残影（数量、寿命、透明度和海洋蓝取 `presentation.breaker_afterimage_*`）。
- T、R、跑步、受击不受该加速、最短锁与残影影响。

### R 落地 Spell Flux 规则

- 对落点 `5.5m` 半径内每名敌人直接结算 3 次 E 初段魔法伤害，并施加 3 层减魔抗；每层持续 5 秒且按既定乘算法则处理。瑞兹自己不吃这次落地效果。
- 此范围效果不生成 E 初段弹道、分裂、弹射或回弹动画；它不选择后续弹射目标。
- 每个实际吃到落地伤害的敌人，在其脚底播一次 `VFXZapLightning_01`（`ryze_r_landing_zap`）。这是命中表现，不是新的伤害段；同一目标只打一记落雷，不跟三次 E 叠三次闪电。
- T 开启时，落地三次 E 会外溢到主目标周围 `3.5m` 敌人。这些外溢目标同样各挨一记落雷；Q/W/E 平时的 T 外溢不劈雷，避免每下普技都落雷。

## 已接入美术资源

- 角色序列帧已复制到 `res://assets/characters/rune_mage_ryze/`，并由 `build_ryze_sprite_frames.gd` 生成 `ryze_sprite_frames.tres`：共 21 个状态、501 帧。`taunt` 是预留给项目 T 槽位的角色动画；它不是对当前 PC 技能组存在 T 技能的声明。
- 技能序列帧、普攻法球、护盾、图标、觉醒语音和原画已复制到 `res://assets/vfx/ryze_skills/`，并由 `build_ryze_skill_vfx.gd` 生成 `ryze_skill_vfx_frames.tres`：`basic_attack`（12 帧）、`Ryze_Shield`（32 帧循环，Screen/滤色材质）、`Spell1_Q`、`Spell2_W`、`Spell3_E`、`Spell4_R_winddown`、`W_loop`、`T_Buff` 与 `impact`。
- `W_loop` 是当前唯一预设循环的技能表现；它仅表达资源播放方式，尚不等价于 W 的最终机制。`Ryze_awake.wav` 与原画保留给后续觉醒 Cut-In profile。
- 瑞兹体型与盖伦相同；角色 `pixel_size`、逻辑脚底锚点与受击高度将复用盖伦的同量级标尺，不能仅按瑞兹图集的像素尺寸自动放大或缩小。
- 普攻动作固定采用 `attack1 → attack2 → attack3 → crit` 四段连续序列；法球使用 `basic_attack`，其射程、速度、碰撞宽度与命中时机仍须通过基础攻击 hit profile 接线。

## 当前基础与成长属性

下表为 PC 当前快照的来源值；运行时已写入 `units.csv` / `unit_stats.csv`，距离与移速按 `0.01` 换算为米。

| 属性 | 1 级来源值 | 成长来源值 | 来源字段 | 状态 |
| --- | ---: | ---: | --- | --- |
| 最大生命 | 620 | 124 | `hp` / `hpperlevel` | 已入表 |
| 法力 | 300 | 70 | `mp` / `mpperlevel` | 已入表 |
| 生命回复 | 8 | 0.8 | `hpregen` / `hpregenperlevel` | 已入表 |
| 法力回复 | 8 | 1 | `mpregen` / `mpregenperlevel` | 已入表 |
| 攻击力 | 55 | 0 | `attackdamage` / `attackdamageperlevel` | 已入表 |
| 攻击速度 | 0.658 | 2.11% | `attackspeed` / `attackspeedperlevel` | 已入表 |
| 护甲 | 22 | 4.2 | `armor` / `armorperlevel` | 已入表 |
| 魔抗 | 32 | 1.3 | `spellblock` / `spellblockperlevel` | 已入表 |
| 移动速度 | 340 | 0 | `movespeed` | 已换算为 `3.4 m/s` |
| 攻击距离 | 550 | 0 | `attackrange` | 已换算为 `5.5m` |

## 当前技能快照

| 槽位 | 采用技能形态 | 等级 | 已锁定结构（概述） | 冷却 | 来源射程 | 项目状态 |
| --- | --- | ---: | --- | --- | ---: | --- |
| P | Arcane Mastery（History 2nd） | — | 每次主动施法获得 1 层、持续 6 秒，最多 5 层；满层后超负荷，获得护盾，并在限定时间或限定 Q/W/E 施法次数内强化基本技能及缩减冷却 | — | — | `adapted` |
| Q | Overload（History 2nd） | 5 | 直线符文冲击，首个目标受魔法伤害；超负荷会延长强化状态持续时间 | 4s | `5.5m`；宽 `1.1m`；速度 `17m/s` | `adapted` |
| W | Rune Prison（History 2nd） | 5 | 单体魔法伤害并直接定身 | 14s | `5.5m`，锁定必中 | `adapted` |
| E | Spell Flux（History 2nd） | 5 | 法球命中后叠加乘算减魔抗 5 秒、最多 3 层；分裂至瑞兹与主目标周围最多 6 名敌人，再由次级法球回弹主目标并造成半额伤害 | 7s | `5.5m`；弹射半径 `3.5m`；速度 `15m/s` | `adapted` |
| R | Realm Warp（Current） | 3 | 提高 Q 对 Flux 的强化收益；引导 2 秒开启传送门，仅瑞兹和身边友军传送至短距离目标地点，并受竞技场边界钳制 | 180/160/140s | 友军选取 `5.5m`；最大传送 `25m` | `adapted` |
| T | Desperate Power（History 2nd） | 3 | 觉醒型自我强化：持续 6 秒，增加法术吸血、移速，并使基本技能对主目标周围敌人造成半额伤害 | 50s | 200 | `adapted` |

## 技能形态选择与改编矩阵

| 当前来源技能 | 项目技能 | 分类 | 当前决定 | 保留/改动 |
| --- | --- | --- | --- | --- |
| Arcane Mastery（History 2nd） | P | `adapted` | 使用统一刷新 6 秒、5 层、超负荷护盾/施法次数/冷却缩减结构；任意主动施法叠层 | 需先接入法力缩放与通用护盾；Q 等级决定超负荷持续时间；Q/W/E 消耗超负荷次数并使所有冷却减少 4 秒 |
| Overload（History 2nd） | Q | `adapted` | 方向首中投射物：`5.5m`、宽 `1.1m`、速度 `17m/s` | 使用 `spell1` 与 `impact`；强化状态只延长持续时间 |
| Rune Prison（History 2nd） | W | `adapted` | `5.5m` 的锁定必中、直接定身 | 目标处 `Spell2_W`，定身期间 `W_loop`；仍需接入通用控制状态 |
| Spell Flux（History 2nd） | E | `adapted` | `5.5m` 锁定；初段/弹射速度 `15m/s`、弹射半径 `3.5m`，保留 3 层乘算减魔抗、6 敌人分裂及半额回弹 | 同目标命中不设上限；无次级目标时回弹主目标 |
| Realm Warp（Current） | R | `adapted` | 使用当前 2 秒引导、Q-Flux 增幅和受边界钳制的 `25m` 短距离友军传送；落地 `5.5m` 直接施加 3 次 E 初段效果及 3 层减抗 | 落地同步角色 `spell4_winddown` 与 `Spell4_R_winddown`；沉默、眩晕、击飞才能打断，打断返还冷却 |
| Desperate Power（History 2nd） | T | `adapted` | 使用 6 秒法术吸血、移速与基本技能半额范围外溢；引导结束授予满层超负荷 | 作为觉醒技能保留且不消耗超负荷次数；法术吸血和范围外溢需扩展当前伤害管线 |

## 公式登记边界

| 公式 ID | 结构 | 来源类型 | 位置 | 状态 |
| --- | --- | --- | --- | --- |
| `RYZE-CURRENT-STATS` | 当前基础值与成长值 | `reference` | `unit_stats.csv` 的 `ryze` 行 | 已入表 |
| `RYZE-HISTORY2-P` | `stacks=5`，每层持续 `6s`；满层超负荷，持续 `2.5s` 或至多 5 次基本施法；护盾 `25–110(level)+0.08×最大法力` | `reference` | `buffs.csv` / `ryze.supercharge.*` / `ryze_p_shield` | 已入表；超负荷时长当前固定 2.5s |
| `RYZE-HISTORY2-Q` | `damage(rank)=60/90/120/150/180 + 0.55×AP + [0.02,0.025,0.03,0.035,0.04]×最大法力` | `reference` | `skill_effect_ranks.csv` 的 `ryze_q_damage` | 已入表；法力系数运行时尚未接通用管线 |
| `RYZE-HISTORY2-W` | `damage(rank)=80/100/120/140/160 + 0.40×AP + 0.025×最大法力`；`root=1/1.1/1.2/1.3/1.4s` | `reference` | `skill_effect_ranks.csv` 的 `ryze_w_damage` | 已入表 |
| `RYZE-HISTORY2-E` | `damage(rank)=36/52/68/84/100 + 0.20×AP + 0.02×最大法力`；减魔抗每层剩余 `0.92`，持续 `5s`，最多 3 层且逐层乘算；回弹伤害为初始伤害 `0.5` | `reference + project` | `ryze_flux` / `ryze_flux_magic_resistance` / `ryze.e.bounce_damage_ratio` | 已入表；运行时读剩余倍率 `0.92`，不再写死 `0.08` |
| `RYZE-HISTORY2-T` | 被动冷却缩减 `0.10/0.20/0.30`；主动 `6s`、法术吸血 `0.15/0.20/0.25`、`+80` 移速，基本技能对主目标周围敌人造成 `0.5` 倍伤害 | `reference` | `ryze_desperate_power` / `ryze.t.spill_damage_ratio` | 已入表；被动急速与通用吸血管线仍待接 |
| `RYZE-CURRENT-R` | Q 对 Flux 目标增伤 `0.50/0.75/1.00`；2 秒引导传送门、R CD `180/160/140s` | `reference` | `skill_ranks.csv` 的 `ryze_realm_warp` | 已入表；Q-Flux 增伤尚未接线 |
| `RYZE-SIDESCROLLER-ACTION` | 普攻 `5.5m/13m/s/0.85m`；Q `5.5m/1.1m/17m/s`；W/E 锁定 `5.5m`；E 弹射 `3.5m/15m/s`；T 引导霸体与 `3.5m` 外溢；R `25m` 传送与落地三段 E 范围效果 | `derived + project` | `hit_profiles` / `animation_events` / `ryze.*` 规则 | 已入表；E 弹射弧/挤压与命中回退高度也在 `ryze.e.*` / `ryze.hit.fallback_height` |

## 横版动作化待决项

- 法力值目前只是属性契约，尚无通用消耗/回复/额外法力缩放运行时管线；P 与 Q/W/E 伤害不能在该能力补齐前假称已完成。
- 普攻 / Q/E 接触结算、W 第 5 帧、hit profile 与 animation_events 已入表。Q 用 `1.1m` 纵深容差，W/E 锁定不做纵深判定。
- R 落点已钳在 `GroundMesh` 与 `ryze_demo` 档案边界；有友军的传送资格仍待有队友的场景验收。
- T 的法术吸血必须以通用“技能伤害治疗”能力实现；不能在瑞兹控制器中硬编码。
- 觉醒 Cut-In 与技能音频已有档案行和资源路径，明天再接线。

## 验收状态

- 已完成：当前 PC 基础属性与 R 来源快照、History 第 2 套 P/Q/W/E/T 数值快照、原画来源登记、P/Q/W/E/R/T 映射矩阵。
- 已完成：瑞兹等同盖伦的体型标尺、普攻四段角色动作约定，以及 Q/W/E/T/R 的横版动作、命中、取消与表现生命周期契约。
- 已完成：`schema.version=19` 下的单位/技能/Buff/命中/动画/资产行，以及 `ryze.*` 运行时常量。脚本冷却、射程、弹速、超负荷窗口、施法最短锁、T 授予超负荷、减抗剩余倍率、T 外溢倍率和 E 弹射/命中高度等表现常量均读表。
- 未完成：通用法力消耗/法力系数伤害、T 法术吸血流水线、觉醒 Cut-In 与技能音频；明天再配。
- 2026-09-06 用户确认战斗表现力可先收口；音频与立绘不在本轮。

## 2026-09-06 普攻 / Q / W / E / Impact 视觉验收

画面由用户亲自验收通过。自动测试只证明引用和逻辑，不能覆盖这份结论。旧交接写的「飞行特效按画布中心锚点」已被本次验收取代，不得再按那条改回去。

权威位置：

- 出手 Transform / 透明度：`scenes/units/ryze.tscn` 的 `CastVFXPreview` 各节点。
- 命中与轴点补偿：`scripts/characters/ryze_combat_ai.gd`。
- `data/source/asset_manifest.csv` 的普攻 / Q / W / E / Impact 行已按 2026-09-06 验收从场景回写。E 出手另加脚本 `E_LAUNCH_Y_BIAS` / `E_HIT_X_BIAS`，不要把表里的本地坐标再叠一层。不能用旧聊天数字覆盖场景。

| 层 | 位置 | 轴点 | 说明 |
| --- | --- | --- | --- |
| 魔法受击粒子 | `victim.get_hit_contact_point(attacker)` | 粒子自身 | 盖伦同款挂点；瑞兹不播黄色物理序列，也不走七海水花 `magic`，改走 `arcane` 蓝电命中 |
| 瑞兹 impact 序列 | 同一挂点 + `IMPACT_CONTACT_Y_BIAS` | 播放时读 JSON `originPixel` | 叠在粒子上，`render_priority = 41` |
| 普攻法球 | 场景出手点 → 接触挂点，提前 0.45m 刹车 | 场景已写 origin offset | 用户手调 scale / 出手点；动画名 `projectile` |
| Q 法球 | 场景出手点高度水平飞到敌人 XZ | 场景已写 origin offset；朝 -X 时 `flip_h` 并取反 `offset.x` | 图集默认朝 +X；只翻 UV 会让弹头离开作者原点 |
| E 法球 | 场景出手点 + `E_LAUNCH_Y_BIAS`，水平飞到敌人；命中 X += `E_HIT_X_BIAS` | 不接 origin（`offset = 0`） | 接 origin 会把整段抬高约 2.5m。体素壳跟 `Spell3_E` 作者原点，不跟节点中心，也不吃 `E_LAUNCH_Y_BIAS`。颜色 `78d9ff59` |
| W / W_loop / R | 受害者或自身 + 模板本地坐标 | 不接飞行 origin | 地面特效，已验收 |

补偿常量（只补产线轴点，不是技能数值；权威在 `combat_rules.csv`）：

```
ryze.impact.contact_y_bias = -0.8
ryze.e.launch_y_bias = 0.8
ryze.e.hit_x_bias = 0.5   # 世界坐标 +X，不随朝向翻转
```

已验收场景 Transform（勿用旧聊天数字覆盖）：

| 节点 | position | scale | offset | modulate.a |
| --- | --- | --- | --- | --- |
| BasicProjectile | (1.055, 1.321, 0) | (2.894, 1.639, 1) | (-126.5, 622.5) | 1 |
| QProjectile | (1.504, -0.626, 0) | (1.263, 1.535, 1) | (-126.5, 622.5) | 0.541 |
| EProjectile | (0.521, 1.696, 0) | (0.874, 0.824, 1) | (0, 0) | 0.573 |
| Impact | 运行时忽略模板 position | (1, 1, 1) | 播放时按 origin 写入 | 1 |
| WEffect | (-0.691, 3.410, -0.168) | (1.198, 1.212, 1) | (0, 0) | 1 |
| WLoop | 同 W 本地坐标 | (1.306, 1.285, 1) | (0, 0) | 0.624 |
| RWinddown | (-1.127, 3.385, 0) | (1.219, 1.150, 1) | (0, 0) | 1 |
| TBuff | (-0.520, 5.239, 1.812) | (1.170, 1.737, 1) | (0, 0) | 0.467 |
| Shield | (-0.043, 0.910, 0) | (1.915, 2.740, 1) | (0, 0) | 0.408 |
| TBuffFlip | (1.280, 5.239, 1.812) | (1.170, 1.737, 1) | (0, 0)，`flip_h` | 0.467 |
| ShieldFlip | (0.746, 0.910, 0) | (1.915, 2.740, 1) | (0, 0)，`flip_h` | 0.408 |

普攻 / Q 的 `offset = (-126.5, 622.5)` 来自 `Vector2(width/2 - originX, originY - height/2)`，画布 `1439×1653`、`originPixel (846, 1449)`。`_ready()` 会按 JSON 重写这两项 offset，不要顺带改 position / scale / 透明度。

`TBuff` / `Shield` 只负责朝 +X。朝 -X 用 2026-09-06 用户手调的 `TBuffFlip (1.280, 5.239, 1.812)` 与 `ShieldFlip (0.746, 0.910, 0)`，不是 +X 的 X 镜像。运行时按 `CharacterFrames.flip_h` 选用，不改节点 Transform，也不写 `originPixel` offset。编辑器里 Flip 节点默认可见。

## 脱手法球约定（取代画布中心锚点）

和三维资产同一套枢轴，不再使用「飞行特效 = 画布几何中心」。

| 环节 | 约定 |
| --- | --- |
| 作者空间 | 一个资产一个 `(0, 0)`。角色脚底、脱手法球中心、受击爆炸中心都在这个点上。不要把「手在角色身上的位置」画进帧。 |
| 导出 | FrameDock 把作者 `(0, 0)` 写成 `originPixel`。那是大画布图像坐标，不是图片左上角。 |
| 导入器 | 必须按角色同一公式写 `AnimatedSprite3D.offset = (width/2 - originX, originY - height/2)`。节点原点 = 作者 `(0, 0)`。禁止默认钉在画布中心。 |
| 出手 | 场景 Cast 节点的 Transform。左右翻转只镜像本地 X。 |
| 飞行 | 节点带着作者 `(0, 0)` 飞。方向弹道沿出手高度走；锁定弹道同样从出手点出发，不要先吸到画布中心再飞。 |
| 命中 | 伤害粒子走目标 `get_hit_contact_point`。Impact 序列的作者 `(0, 0)` 叠在同一挂点上。 |
| 地面特效 | W / W_loop / R 落地仍用脚底 / 地面枢轴，不要改成飞行中心。 |

瑞兹当前已验收的 Transform 和 `ryze.impact.contact_y_bias` / `ryze.e.launch_y_bias` / `ryze.e.hit_x_bias` 是导入器未履约时的补丁，**不是**这条约定的一部分。修导入器或出下一个英雄时，先认 `originPixel`，再摆出手点；不要把这组米制 bias 写成通用标尺。未再验收前，不要为了「对齐新约定」改掉已通过的瑞兹场面。

## 资产生产问题

作者约定本身没问题。缺口在 `build_ryze_skill_vfx.gd`：只切 AtlasTexture，不读 `originPixel`。Godot 默认 `centered + offset=0`，节点钉在画布几何中心。中心相对 origin 差 `(-126.5, 622.5)` 像素，`pixel_size = 0.004` 时约 **X 0.51m / Y 2.49m**。内容已经在作者 `(0, 0)` 上，引擎认错了 0 点，才会出现脚底爆炸、以及后补 origin 和已按画布中心摆过的 E 出手打架。

后续做帧继续把技能中心放在作者 `(0, 0)`。手上释放点只用场景 Transform。
