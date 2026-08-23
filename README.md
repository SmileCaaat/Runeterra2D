# 符文大陆：城邦旅团

《符文大陆：城邦旅团》是一个使用 Godot 4.7 制作的 3D 横版动作游戏学习原型。角色以 2D 序列帧呈现，在 3D 场景中完成 X/Z 平面移动、纵深命中、连击、硬直、击退、霸体、技能和 Buff 结算。

当前原型包含 Rogue Admiral Garen、移动训练木桩、五个演示技能、粒子与音效反馈，以及由 CSV 构建的类型化战斗数据库。

## 设计方向

- 参考成熟 MOBA 的英雄属性、技能、Buff 和公式语义。
- 使用 DNF 式横版动作的攻击帧、取消窗口、hitstop、hitstun、削韧、击退和纵深规则。
- 优先实现或简化参考英雄原本的身份机制，再考虑原创扩展。
- 所有参考数据、换算和项目自有公式保持可追溯。

详细规则见 [战斗规则文档](docs/combat/README.md)。

## 初次运行

本项目使用 Git LFS 保存大型图片和音频资产。克隆后先安装 Git LFS，再生成战斗数据库：

```powershell
git lfs install
git lfs pull
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://scripts/tools/build_combat_database.gd
```

随后使用 Godot 4.7 打开 `project.godot`，运行主场景即可。

## 当前状态

这是非商业学习原型，仍在持续验证角色、战斗配表和资产生产工作流。项目与 Riot Games、腾讯、Neople 或 Nexon 没有关联；第三方名称、商标和参考内容归各自权利人所有。
