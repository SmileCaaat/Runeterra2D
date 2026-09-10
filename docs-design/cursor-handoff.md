# Cursor 交接：Gemheart / Runeterra2D

交接日期：2026-09-06。先读本文，再读 [文档总入口](../docs/README.md)。本文依据用户最终决定和本次磁盘检查整理；不是全量聊天逐字导出。历史文档中的“已完成”不代表当前视觉验收通过。

## 立即接手的任务

1. 用户最后一个尚未完成的美术指令：用 `D:/1Gameassets_share/SpriteAssets/Skills/Ryze_spell_sheet_json_20260905_135938Z/projectile/` 中的 `spritesheet.png` 和 `spritesheet.json` 替换当前普攻 `basic_attack`。该目录已确认存在；此前对话被打断，不能视为已完成替换。优先比较文件哈希再操作，保留运行时动画名 `basic_attack` 和用户手调 Transform。
2. 按新 JSON 的每个 `frame` 区域重新生成普攻帧资源，检查实际加载的 AtlasTexture、尺寸、帧数与渲染引用。用户截图出现多枚法球同时排列；这说明显示异常，但尚未证明是缓存、未切帧、素材内部布局还是渲染引用错误。不要仅重建后看到测试通过就宣称解决。
3. 脱手法球 / 受击爆炸已改约定：作者 `(0, 0)` = 法球或爆炸中心，与角色脚底同一套枢轴；导入器必须读 `originPixel`，禁止再把画布几何中心当飞行锚点。出手点和命中点只摆实例。W、W_loop、R winddown 仍走脚底地面锚点。瑞兹已验收场面和米制 bias 见 `docs/combat/heroes/ryze.md`，未再验收前不要为对齐新约定改掉。
4. 用户随后进入 `scenes/units/ryze.tscn` 自己调试视觉；保留他修改的 position、scale、rotation、透明度，再同步运行时和 `asset_manifest.csv`，不要用旧聊天参数覆盖现存场景。

## 用户工作偏好

- 引擎内操作大部分通过 Godot AI MCP；保持接通，先读项目插件 README，使用插件生成的客户端配置。禁用代理是明确用户要求。
- 视觉验收由用户亲自做；自动检查负责数据、引用、动作事件、运行时逻辑。不要将 headless 验证当成画面验证。
- 定位问题要给证据，避免反复猜测、盲目改参数。以小范围修改和针对性检查提高迭代速度。
- 不自行提交或推送。大量插件、美术和实现代码尚未提交；保留无关改动，不使用全盘清理/重置。
- 阵营描边已整体取消；霸体效果必须保留。不要重新启用阵营 Outline Glow 或放大染色轮廓。

## 本次核实的工程状态

- 工作目录 `D:/godot_projects/gemheart2d`；最近提交 `a7bdf1a feat: refine Garen combat presentation`。交接时工作树有大量修改及未跟踪文件。
- `addons/godot_ai/plugin.cfg` 版本 `3.2.5`。约定 HTTP 8000、WS 9500；本轮文档整理未启动编辑器，也未验证实时连接。
- 主训练场：`DNF_Style_Prototype.tscn`；瑞兹：`scenes/units/ryze.tscn`；AI/技能：`scripts/characters/ryze_combat_ai.gd`；战斗 HUD：`scripts/ui/battle_hud.gd`（底部 A/B/C + Debug）；训练场编队：`scripts/ui/training_roster_panel.gd`（嵌在 Debug → Training Tools）。
- CSV 源表位于 `data/source/`；构建入口 `scripts/tools/build_combat_database.gd`；产物 `data/generated/combat_database.tres` 不手改。
- 瑞兹代码和配表已经存在，但还不能称为全部表驱动。代码中仍可见 Q/W/E/T/R 冷却的数字字面量，以及被动减冷却 `4.0`，需要按任务范围检查与源表一致性。
- 受击挂点已改为目标 `get_hit_contact_point`；Impact 叠在同一点并带瑞兹补丁 bias。`_update_projectile_facing` 仍只按 X 翻转贴图。
- 角色读取 JSON `originPixel` 对脚。技能导入器尚未履约同一公式；不要删角色脚底定位，也不要再按画布中心解释飞行特效。

## 已确认的瑞兹最终设计（覆盖旧档案冲突处）

基本设计来源：History 第 2 套 P/Q/W/E；历史 Desperate Power 为 T；当前 Realm Warp 为 R。详细数值见 `docs/combat/heroes/ryze.md` 和源表。职业 `mage → battlemage`，体型与盖伦相同，来源距离按 0.01 换算为米。

| 动作 | 发射/生效帧（人类从 1 开始） | 最终规则 |
| --- | --- | --- |
| 普攻 attack1/2/3/crit | 第 6 帧，表内索引 5 | 四段连续动作；射程 5.5m，球速 13m/s，宽 0.85m；接触结算；不可移动释放，可转向；硬直/击退为盖伦普攻 1/3 |
| Q spell1 | 第 4 帧，索引 3 | 方向弹道，首个敌人命中；射程 5.5m、速度 17m/s、宽 1.1m、纵深容差 1.1m；硬直/击退同盖伦普攻 |
| W spell2 | 第 6 帧，索引 5 | 锁定目标，非弹道；直接伤害与禁锢；定身 1/1.1/1.2/1.3/1.4s；无击退，硬直为盖伦普攻 1/4；W_loop 覆盖定身时间 |
| E spell3 | 第 7 帧，索引 6 | 锁定目标，初段与弹射速度 15m/s、弹射半径 3.5m；法球到达才结算，硬直/击退为盖伦普攻 1/3 |

这些帧索引本次已与 `animation_events.csv` 核对。Q/W/E 末尾三帧取消规则已经被用户撤销；正常动作应完整播放后再开始下一动作。不要把“发射帧”和“投射物造成伤害的时点”混为一谈。普攻、Q/W/E 命中都需 impact。

P：施法叠层，刷新 6s，5 层触发；QWE 消耗强化施法次数，R/T 不消耗。护盾 `25–110(level)+8% 最大法力`；强化至多 5 次或按 Q 等级 2.5–5s；强化施法减冷却按已约定 4s。完整触发顺序仍需针对性审计。

E：减抗最多三层，逐层乘算；链路包含主目标，无次级敌人可经瑞兹回弹主目标，同一目标一次链的伤害次数不另设上限，但不能因此产生无限递归弹射。

T：taunt 动画为觉醒；引导期间霸体，结束后 6s T_Buff；完整通用法术吸血机制，保留被动 10/20/30% 冷却缩减；外溢半径 3.5m。Cut-In 用 Ryze_awake.wav 与原画。

R：2s 引导，仅沉默/眩晕/击飞打断，取消返还冷却；传送瑞兹及周围 5.5m 友军，最远 25m，边界钳制；落地播放角色 spell4_winddown 和 Spell4_R_winddown，对周围 5.5m 每个敌人直接三次 E 初段伤害与三层减抗，不生成 E 弹道/弹射。

护盾滤色已被用户取消（曾变成白片），当前 `_ready()` 将 `shield.material_override = null`。不要因为旧档案或遗留 Screen 材质文件存在而启用。护盾和 TBuff 使用用户当前保存的场景参数，旧聊天参数仅是历史。

## Garen、场地及公共功能约束

- Garen E 攻击半径最终要求 3.8m；E 未结束换目标时应保留旋转动作。Q 强化攻击距离最终要求 2.5m；这些是用户决定，不表示本轮重新测试通过。
- 蓝/红双方各预留 5 个出战槽，当前只有盖伦和瑞兹两种英雄。取消出战须停止角色逻辑、技能伤害和声音，不能只隐藏模型；需要验证异步技能和已生成特效的清理。
- 觉醒语音：立绘最先出现的语音先播放；它结束之前出现的其他觉醒不播放语音，不自动理解为后续排队补播。
- 场地经历 BoxMesh 顶面完整贴图、边缘、梯形与 UV 修正；用户删除 GroundEdgeBack/Left/Right，不要擅自重建。以当前场景为准。
- 迅捷蟹冲刺要忽略单位碰撞但保留地面碰撞，可复用幽灵碰撞状态。已有特效大小、颜色以配表/场景为准，旧对话里的多轮倍数不可重复应用。

## 资源和工具定位

- 角色原始资源：`D:/1Gameassets_share/SpriteAssets/Character/Ryze_sheet_json_20260831_033619Z/`。
- 最新技能源目录：`D:/1Gameassets_share/SpriteAssets/Skills/Ryze_spell_sheet_json_20260905_135938Z/`，普攻最新指定子目录为 `projectile`。
- 工程内：`assets/characters/rune_mage_ryze/ryze_sprite_frames.tres`、`assets/vfx/ryze_skills/ryze_skill_vfx_frames.tres`。
- 生成器：`scripts/tools/build_ryze_sprite_frames.gd`、`scripts/tools/build_ryze_skill_vfx.gd`。
- 预览节点：`CastVFXPreview/{BasicProjectile,QProjectile,WEffect,EProjectile,WLoop,RWinddown,Impact}`，以及 `Shield`、`TBuff`。它们的 Transform 与运行时实例化方式需一起检查。
- 配表：`asset_manifest.csv`、`animation_events.csv`、`skills.csv`、`skill_ranks.csv`、`skill_effects.csv`、`skill_effect_ranks.csv`、`hit_profiles.csv`、`buffs.csv`、`buff_modifiers.csv`、`units.csv`、`unit_stats.csv`、`ai_profiles.csv`、`awakening_cutin_profiles.csv`。

## 必须纠正的历史结论

1. 之前助手说普攻切了 16 帧不准确：8×2 是图集容量，当前测试及资源登记是 12 个有效帧；以实际新 JSON 条目数量为准。
2. 新 JSON 的旧元数据曾是 originPixel=(846,1449)，帧尺寸 1439×1653；生成器没有读取此 originPixel。不能据此断言图像内容就在画布中心，也不能断言偏移必是缓存。
3. 曾记录 Windows APPCRASH `c0000005`，Godot 模块偏移 `0x327d10a`。同一时间收到的 LiveKernelEvent 报告引用了数月前的 WATCHDOG 文件，所以“同秒 GPU watchdog 证明此次显卡超时”证据不成立。四图解压约 581 MiB 只能说明资源较大，不能证明显存不足是根因。后续需实际崩溃堆栈/日志或可重复诊断。
4. 曾发现 2026-09-04 遗留的 `verify_training_stage_visuals.gd --headless` 进程。PID 是历史信息，结束进程前重新核对命令行，不随意杀全部 Godot/MCP。
5. 无界面资源测试通过不证明图像切片、原点、材质、动画同步或编辑器稳定性通过。之前的“全部入表/全部应用”也需要按具体字段核实。

## MCP 与验证

阅读 [插件说明快照](../docs/imported/addons/godot_ai/README.md)，实际版本及客户端配置以当前插件为准。优先通过插件 Clients & Tools 为 Cursor 配置连接，不照抄旧 Codex 配置或旧 session id。

手工 HTTP 诊断顺序：initialize → 取得 Mcp-Session-Id → notifications/initialized → tools/list 或 tools/call。端口响应不等于编辑器在线；再检查 sessions/readiness。

可选的针对性验证入口（本次文档整理没有重新运行这些测试）：

```powershell
$godotExe = 'C:/Users/JamLew/Desktop/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe'
& $godotExe --headless --path D:/godot_projects/gemheart2d --script res://tests/verify_ryze_asset_library.gd
& $godotExe --headless --path D:/godot_projects/gemheart2d --script res://tests/verify_ryze_construction.gd
& $godotExe --headless --path D:/godot_projects/gemheart2d --script res://tests/verify_combat_database.gd
```

资产测试当前硬编码角色 501 帧、技能 147 帧、普攻 12 帧。换新资源后应按新 JSON 检查契约，不能机械改预期让测试变绿。旧 `verify_garen_audio_workflow.gd` 曾有失败，需复核，不能宣称全套测试通过。

## 在 Cursor 中开始

把本文件添加到 Cursor 当前对话上下文，提示：

> 先读 docs-design/cursor-handoff.md 和 docs/README.md，再检查当前源表和场景。先完成用户指定的 projectile 替换 basic_attack，保持用户手调参数，通过 Godot MCP 检查编辑器真实引用和切帧。仅做当前任务必要检查，视觉由我验收。此前关于缓存和 GPU 崩溃的结论有未证实部分，不要当作根因。不要提交或推送。

相关 skill 已携带至 `docs/skills/`。这些是可阅读的项目交接资料，复制文件不代表已在 Cursor 自动安装或启用 skill。无需迁移个人密钥、账户配置或 Codex 内部会话数据库。
