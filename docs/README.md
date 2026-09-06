# 项目文档总入口

整理日期：2026-09-06。Cursor 接手先读 [cursor-handoff.md](../docs-design/cursor-handoff.md)，其中记录最终决定、未完成事项和已知历史误判。

## 工程文档

- [战斗文档入口](combat/README.md)：规则、公式、配表、英雄档案。
- [Garen](combat/heroes/garen.md)、[Ryze](combat/heroes/ryze.md)。`ryze.md` 是瑞兹唯一档案。
- [公式](combat/formula-reference.md)、[数据契约](combat/data-contracts.md)、[英雄设计规则](combat/hero-design-rules.md)。
- [硬编码审计](combat/hardcoding-audit.md)、[Champion 数据审计](combat/champion-data-contract-audit.md)：属于各自日期的报告，不能代替当前代码检查。
- [命中特效](combat/vfx/hit-impact-system.md)、[舞台美术契约](stages/stage-art-contract.md)、[训练场贴图规范](stages/training-ground-image-generation-spec.md)。
- [版本管理](version-control.md)。
- [项目 README 快照](imported/README.md)、[数据构建工作流快照](imported/data/README.md)。快照里的相对链接沿用原文，必要时回到工程源文件位置查找。
- [觉醒设计](imported/docs-design/AwakeningCutIn%20系统设计方案（16_9%20动态漫画分镜版）.md)。
- [Godot AI MCP 说明](imported/addons/godot_ai/README.md)、[VFX Library 文档](imported/assets/GODOT-VFX-LIBRARY/README.md)。

## Skill 资料

- [godot-ui](skills/godot-ui/SKILL.md)：项目已安装，用于训练场英雄选择等 UI 工作，来源 zate/cc-godot；安装锁定信息见项目 skills-lock.json。
- [gemheart-hero-workflow](skills/gemheart-hero-workflow/SKILL.md)：项目英雄参考、配表和行为实现流程，附带模板。是接手相关的本地指导，不声称历史每个回合都执行过。
- [openai-docs](skills/openai-docs/SKILL.md)：本对话询问 Codex/迁移时读取过的工具文档技能；已包含其本地参考文件。它不是 Godot 项目的运行依赖。

仅收录本任务使用或与本项目接手直接相关的 skill；不把账户下 Canva、金融、宠物等无关技能混入项目。skill 文档中的 Codex 专属工具在 Cursor 中需使用当地可用工具实现，不能假定自动存在。

## 收录范围和维护

原有 docs 文档保留原位。工程内其余发现的 Markdown 文档按原相对路径复制到 docs/imported，包括插件和 VFX 第三方文档；原文件保留，避免破坏原来的工具入口。docs-design/cursor-handoff.md 是指定交接入口，docs 中也有快照。

[archive-manifest.json](archive-manifest.json) 记录文档/skill 来源、目标和 SHA-256；复制后的文件已经逐一核对哈希。清单是本次时间点的快照，后续更新优先修改原始权威文件并同步快照。文档链接无法携带尚在工程外的全部美术文件，外部资源路径见交接文档。

本轮未修改战斗代码、场景和美术，未执行提交或推送。完整逐字聊天和个人配置不在本次文档包内。
