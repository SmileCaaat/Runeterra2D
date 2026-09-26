# 战斗英雄手动接管 MVP v0.1

实现日期：2026-09-26。顺序为公共权限与选择接口 → Garen → Ryze → 2v2 回归。
本里程碑固定接管接口与范围，后续三名基础英雄复用该接口；新增功能另开里程碑，仅继续修复影响现有契约的缺陷。

## 操作

| 输入 | 行为 |
| --- | --- |
| F1–F5 / 点击槽位 | 聚焦对应出战英雄，空槽无效 |
| TAB | 循环聚焦友方出战英雄 |
| 方向键 | 首次输入接管，控制 X/Z 移动 |
| X | 首次输入接管，请求当前目标普攻 |
| Q/W/E/R/T | 首次输入接管，请求已有技能 |
| 反引号 ` | 当前英雄 AUTO / MANUAL 切换 |
| 瑞兹方向键 + R | 沿输入方向折跃，未按方向则拒绝 |

开局全员 AUTO。焦点、选中描边与当前英雄面板只表达选择；MANUAL/AUTO 和槽位 M/A 表达控制权。
最多一个英雄处于 MANUAL。切换焦点立即归还旧英雄，新英雄保留 AUTO；切换时仍按住方向键，需要松开后重新输入才会接管新英雄。
方向键松开会清零移动意图；失去应用焦点、文本输入、死亡、移除或释放节点均不会遗留持续移动。
敌人始终由系统控制。索敌继续使用英雄原有敌对目标刷新，MVP 没有鼠标瞄准或额外锁定操作。

## 接口与责任

- `HeroInstance`：`ControlAuthority`、`control_authority_changed`、移动意图、`supports_player_control()`、`request_player_basic_attack()`、`request_player_skill(slot, direction_input)`。默认 AI、默认不支持接管。
- `BattleControlCoordinator`：场景级节点，监听 HUD 选择，独占战斗输入与软接管，保证正常输入路径至多一个受控英雄。技能为按下事件，忽略键盘 echo；TAB 在 GUI 默认焦点导航前处理。
- `BattleHUD`：`get_selected_hero()`、`get_friendly_heroes()`、`select_hero()`、`select_next_hero()` 和 `selected_hero_changed`。权限徽标由英雄权限信号更新；描边跟随 HUD 焦点。
- 英雄脚本：复用同一运行时执行门和 `_start_combat_action()`。Garen 继续通过 `SkillController.begin_skill()`；Ryze 继续通过原异步动作。Coordinator 不计算伤害、播放动画或写冷却。

接管与归还都会清空旧 AI 意图和移动意图，将 AI 决策计时归零。手动期间不执行 HeroBrain；归还后在当前动作允许的下一个物理帧恢复新决策。
正在进行的攻击、E、Q/W/E 和 R 引导不因权限切换取消、退款或重启动画。Garen E 使用手动移动，W during E 保留；沉默时 Black Sail 的既有例外保留。
禁锢复用 `CombatUnitInstance.is_rooted()`：禁止平面移动和瑞兹 R，非移动技能仍遵守原有规则。沉默、冷却、动作锁和攻击锁通过原执行门验证。
旧 `player_actor` 分组保持场景身份含义，不代表手动权限。HeroBrain 和瑞兹 R 短时结果评估没有修改。

## 配置

键位定义在 `project.godot` 的 `battle_*` InputMap 动作。
`combat_rules.csv` 新增 `ryze.r.manual_warp_distance = 8.0`（米，项目自定义输入规则）。手动 R 使用该距离与技能最大距离的较小值，并执行场地钳制。
R 引导仍读取 `ryze.r.channel_duration = 0.9`；动画速度恢复、友军传送、落地效果和 winddown 复用已有流程，不增加霸体。

## 验证与冻结边界

`tests/verify_player_takeover_runtime.gd` 使用真实训练场景的蓝方 Garen/Ryze 与红方 Garen/Ryze，覆盖权限、F 键/TAB/点击、软接管、移动、Root、Silence、各技能、CD、E 中 W、方向 R、8 米距离与边界、友军传送、动作期间切换、AI 恢复、死亡、队伍移除、直接释放节点、HUD 和选中描边。

相关回归：`verify_hero_ai_foundation`、`verify_hero_ai_runtime`、`verify_hero_ai_scene`、`verify_hero_versus_hero`、`verify_training_stage_visuals`、`verify_garen_targeting_and_lifecycle`、`verify_garen_skill_rules`、`verify_ryze_construction`、`verify_combat_database`、`verify_combat_workflow`。
运行命令：`Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/verify_player_takeover_runtime.gd`。

已在渲染中的 2v2 场景通过引擎输入事件检查方向接管、TAB 归还、反引号切换，并检查 HUD 截图。自动化验证不代替玩家对操作手感的最终验收。
后续英雄实现上述基类契约和英雄局部适配器；不继续在此层扩展 TeamBrain、瞄准、输入缓冲、装备或摄像机系统。
