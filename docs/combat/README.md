# Gemheart 战斗规则文档

本目录定义“参考外部英雄并将其转化为 DNF 式 3D 横版动作角色”时的项目规则。它解释设计意图、来源和配表契约；`data/source/*.csv` 是运行时数值的唯一事实源，`data/generated/combat_database.tres` 只是构建产物。

## 文档入口

- [英雄参考与改编原则](hero-design-rules.md)：先复刻、再简化、最后扩展的设计方针，以及来源、审计和验收流程。
- [公式与来源索引](formula-reference.md)：当前已实现公式、项目自定义公式、未实现语义和 Wiki 网址。
- [战斗配表契约](data-contracts.md)：13 张源表的边界、引用、单位、生命周期和修改顺序。
- [Garen 参考档案](heroes/garen.md)：当前 Garen 与参考英雄之间的逐技能映射、差异和待补项。
- [Combat Data 工作流](../../data/README.md)：数据库构建、生成和自动测试命令。

## 权威性和同步规则

发生冲突时按以下顺序判断：

1. 用户对当前任务的明确要求。
2. `docs/combat/` 中的项目设计与数据契约。
3. `data/source/*.csv` 中的当前运行时配置。
4. 类型化 Resource 与公式实现代码。
5. 场景或 Inspector 中的兼容回退值。

CSV 和代码必须一致。文档中的示例值不能覆盖 CSV；Inspector 回退值也不能成为隐藏的第二套平衡数据。

每次新增英雄、改变公式语义或改变表结构时，必须同步更新相应英雄档案、公式索引、配表契约和自动测试。结构性改动还必须递增 `schema.version`。
