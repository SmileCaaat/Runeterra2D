# 战斗英雄手动接管 MVP v0.1

实现日期：2026-09-26。顺序为公共权限与选择接口 → Garen → Ryze → 2v2 回归。
本里程碑固定接管接口与范围，后续三名基础英雄复用该接口；新增功能另开里程碑，仅继续修复影响现有契约的缺陷。

## 操作

| 输入 | 行为 |
| --- | --- |
| F1–F5 / 点击槽位 | 聚焦对应出战英雄，空槽无效 |
| TAB | 循环聚焦友方出战英雄 |
| 方向键 | 首次输入接管，控制 X/Z 移动 |
| X | 首次输入接管，按玩家当前朝向普攻，可空挥 |
| Q/W/E/R/T | 首次输入接管，请求已有技能 |
| 反引号 ` | 当前英雄 AUTO / MANUAL 切换 |
| 瑞兹 R | 沿最后一次玩家朝向折跃；按下方向键可同时改变方向 |

开局全员 AUTO。焦点、选中描边与当前英雄面板只表达选择；MANUAL/AUTO 和槽位 M/A 表达控制权。
最多一个英雄处于 MANUAL。切换焦点立即归还旧英雄，新英雄保留 AUTO；切换时仍按住方向键，需要松开后重新输入才会接管新英雄。
方向键松开会清零移动意图；失去应用焦点、文本输入、死亡、移除或释放节点均不会遗留持续移动。
敌人始终由系统控制。索敌继续使用英雄原有敌对目标刷新，MVP 没有鼠标瞄准或额外锁定操作。

## 接口与责任

- `HeroInstance`：`ControlAuthority`、`control_authority_changed`、移动意图、`supports_player_control()`、`request_player_basic_attack()`、`request_player_skill(slot, direction_input)`。默认 AI、默认不支持接管。
- `BattleControlCoordinator`：场景级节点，监听 HUD 选择，独占战斗输入与软接管，保证正常输入路径至多一个受控英雄。技能为按下事件，忽略键盘 echo；TAB 在 GUI 默认焦点导航前处理。
- `BattleHUD`：`get_selected_hero()`、`get_friendly_heroes()`、`select_hero()`、`select_next_hero()` 和 `selected_hero_changed`。权限徽标由英雄权限信号更新；描边跟随 HUD 焦点。
- 英雄脚本：AI 继续使用原 `_can_execute_ai_decision()` 与目标追踪路径；PLAYER 使用独立手动施法门，并依据 `SkillDefinition.target_type` 决定目标语义。伤害、冷却、动画和效果仍委托给原 SkillController 或英雄异步动作。Coordinator 不计算战斗效果。

## 手动施法语义

`HeroInstance.player_facing_direction` 与瞬时移动输入分离。非零方向输入更新持久朝向，松开方向键不会清除它。手动普攻与技能朝向由玩家输入保留；只有 `unit` 技能在施法时可按目标修正朝向。

| `target_type` | PLAYER 规则 | 当前技能示例 |
| --- | --- | --- |
| `self` / `self_area` | 不要求敌人，不因自动索敌转身 | Garen Q/W、Ryze T；Garen E |
| `direction` | 使用持久玩家朝向；弹道可空放并沿直线寻找首个合法敌人 | Ryze Q 与普攻 |
| `unit` | 需要有效敌方目标并校验施法距离 | Garen R、Ryze W/E |
| `ground_area` | 需要合法落点；当前由玩家朝向和技能距离生成并钳制到场地 | Garen T、Ryze R |

Garen 普攻沿玩家朝向进行前方范围命中，攻击动画的既有命中时点不变；空挥时不会转向自动目标。Garen 的手动技能仍由 `SkillController.begin_skill()` 启动。Ryze 手动普攻/Q 使用新增长度受射程限制的直线弹道与逐段首目标检测；AI 普攻/Q/W/E 继续使用原目标追踪弹道。

接管与归还都会清空旧 AI 意图和移动意图，将 AI 决策计时归零。手动期间不执行 HeroBrain；归还后在当前动作允许的下一个物理帧恢复新决策。
正在进行的攻击、E、Q/W/E 和 R 引导不因权限切换取消、退款或重启动画。Garen E 使用手动移动，W during E 保留；沉默时 Black Sail 的既有例外保留。
禁锢复用 `CombatUnitInstance.is_rooted()`：禁止平面移动和瑞兹 R，非移动技能仍遵守原有规则。沉默、冷却、动作锁和攻击锁通过原执行门验证。
旧 `player_actor` 分组保持场景身份含义，不代表手动权限。HeroBrain 和瑞兹 R 短时结果评估没有修改。

## 配置

键位定义在 `project.godot` 的 `battle_*` InputMap 动作。
`combat_rules.csv` 新增 `ryze.r.manual_warp_distance = 8.0`（米，项目自定义输入规则）。手动 R 使用该距离与技能最大距离的较小值，并执行场地钳制。
R 引导仍读取 `ryze.r.channel_duration = 0.9`；动画速度恢复、友军传送、落地效果和 winddown 复用已有流程，不增加霸体。

## 验证与冻结边界

`tests/verify_player_takeover_runtime.gd` 使用真实训练场景的蓝方 Garen/Ryze 与红方 Garen/Ryze，覆盖权限、F 键/TAB/点击、软接管、移动、Root、Silence、各技能、CD、无敌人时 Garen X/Q/W/E/T 与 R 的目标规则、无敌人时 Ryze X/Q/T/R 与 W/E 的目标规则、朝向保持、直线弹道空放与首个目标命中、Garen E 中 W、8 米 R 与边界、友军传送、动作期间切换、AI 恢复、死亡、队伍移除、HUD 和选中描边。

相关回归：`verify_hero_ai_foundation`、`verify_hero_ai_runtime`、`verify_hero_ai_scene`、`verify_hero_versus_hero`、`verify_training_stage_visuals`、`verify_garen_targeting_and_lifecycle`、`verify_garen_skill_rules`、`verify_ryze_construction`、`verify_combat_database`、`verify_combat_workflow`。
运行命令：`Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/verify_player_takeover_runtime.gd`。

已在渲染中的 2v2 场景通过引擎输入事件检查方向接管、TAB 归还、反引号切换，并检查 HUD 截图。自动化验证不代替玩家对操作手感的最终验收。
后续英雄实现上述基类契约和英雄局部适配器；不继续在此层扩展 TeamBrain、瞄准、输入缓冲、装备或摄像机系统。
