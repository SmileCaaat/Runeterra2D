# 符文大陆：城邦旅团

《符文大陆：城邦旅团》是一个使用 Godot 4.7 制作的 3D 横版动作游戏学习原型。角色本体使用带骨骼动画的 GLB；战斗在 3D 场景中完成 X/Z 平面移动、纵深命中、连击、硬直、击退、霸体、技能和 Buff 结算。仍在使用的 2D 序列帧仅用于独立技能与命中特效。

当前训练原型包含 Rogue Admiral Garen 与 Rune Mage Ryze 两名英雄，以及可配置的友方/敌方木桩和中立迅捷蟹。英雄和训练单位本体使用带骨骼动画的 GLB 状态机；技能、命中与场景特效仍按需要使用独立的 SpriteFrames、粒子和音效。战斗数值由 CSV 配置并构建为类型化数据库。

训练场 HUD 展示当前英雄的生命/资源、Q/W/E/R/T 技能图标与实时冷却，并提供编队和战斗统计调试面板。英雄 HUD 头像由 CommunityDragon 开发期同步到本地资源；游戏运行时不访问外网。同步来源、锁文件和使用方法见 [CommunityDragon 资源同步](docs/assets/communitydragon-sync.md)。本项目仍是持续验证中的学习原型，不代表最终美术或平衡版本。

## 设计方向

- 参考成熟 MOBA 的英雄属性、技能、Buff 和公式语义。
- 使用 DNF 式横版动作的攻击帧、取消窗口、hitstop、hitstun、削韧、击退和纵深规则。
- 优先实现或简化参考英雄原本的身份机制，再考虑原创扩展。
- 所有参考数据、换算和项目自有公式保持可追溯。

详细规则见 [战斗规则文档](docs/combat/README.md)。

角色 3D 表现、状态机映射、Toon 光照、阵营识别和剩余 2D VFX 边界见 [3D 角色表现管线](docs/combat/3d-character-presentation.md)。

## 初次运行

本项目使用 Git LFS 保存大型图片、音频和 3D 模型资产（包括 `.glb`）。克隆后先安装 Git LFS 并拉取资源，再生成战斗数据库：

```powershell
git lfs install
git lfs pull
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://scripts/tools/build_combat_database.gd
```

随后使用 Godot 4.7 打开 `project.godot`，运行主场景即可。

## 当前状态

已接入英雄手动接管 MVP：开局全员 AI，F1–F5 / TAB / 点击槽位切换焦点，方向键移动、X 普攻、QWERT 施法并自动接管当前英雄，反引号切换 AUTO/MANUAL。切换英雄后旧英雄恢复 AI；瑞兹 R 需要同时按方向键。操作与后续英雄接入契约见 [手动接管 MVP](docs/combat/manual-takeover.md)。

这是非商业学习原型，仍在持续验证角色、战斗配表和资产生产工作流。项目与 Riot Games、腾讯、Neople 或 Nexon 没有关联；第三方名称、商标和参考内容归各自权利人所有。
