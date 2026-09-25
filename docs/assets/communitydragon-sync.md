# CommunityDragon 英雄资源同步

CommunityDragon 用作开发期外部资源源站。同步脚本读取英雄 JSON 来解析皮肤和图片路径，再把明确配置的文件下载到项目内；游戏运行时只加载 `asset_manifest.csv` 指向的本地资源，不访问外网。

## 当前范围

- Garen（CommunityDragon champion ID `86`）：按皮肤名选择 `Rogue Admiral Garen`，用于 HUD 英雄头像。
- Ryze（champion ID `13`）：选择基础皮肤，用于 HUD 英雄头像。
- 暂不同步技能图标、Buff/Debuff 图标、皮肤选择界面资源或 Awakening Cut-in 插画。脚本只实现当前明确启用的 HUD portrait 类型；扩展类型前先明确各自的数据消费端。

英雄/皮肤配置在 `data/external/communitydragon_sources.json`，同步锁在 `data/external/communitydragon.lock.json`，文件保存在 `assets/external/communitydragon/champions/<unit_id>/` 并由 Git LFS 管理。锁记录解析出的 champion/skin、源路径、URL、本地路径、文件大小和 SHA-256。

## 使用

从仓库根目录使用 Python 3.10+：

```powershell
# 仅解析远端 champion JSON 并预览下载计划，不改文件
py scripts/tools/sync_communitydragon_assets.py --dry-run

# 同步 sources 配置中的全部英雄；可重复执行
py scripts/tools/sync_communitydragon_assets.py

# 只同步指定英雄
py scripts/tools/sync_communitydragon_assets.py --hero garen

# 离线检查锁定文件是否存在且大小和 SHA-256 匹配
py scripts/tools/sync_communitydragon_assets.py --verify
```

默认同步使用原子替换：下载到临时文件，成功且非空后才替换目标；请求失败不会覆盖旧文件。皮肤名必须唯一匹配，champion ID 和 alias 也会核对，任何歧义或不支持的路径/扩展名都会中止，不会猜测图片路径。同步成功后脚本更新 portrait manifest 行和 lock；若上游改了图片扩展名，旧文件会保留为孤立文件以避免破坏现有工作，确认不再引用后可手动清理。

游戏侧绑定链为 `UnitDefinition.portrait_profile_id` → `CombatDatabase.get_asset_profile()` → `AssetProfileDefinition.resource_file`。英雄必须配置 portrait profile，且引用的资源类型必须是 `hero_portrait`。HUD 从单位定义读取头像，因此添加英雄不需要在 HUD 脚本里增加英雄专用分支；技能图标仍走各技能定义里的 icon profile。

## 上游路径规则与许可

CommunityDragon 的资产文档说明，客户端逻辑路径 `/lol-game-data/assets/<path>` 对应其 raw 资源树下 `plugins/rcp-be-lol-game-data/global/default/<path>`；本同步器将资源路径转为小写再请求。实际图片路径不硬编码，而是从 champion JSON 的皮肤记录读取。参考：[CommunityDragon Assets 文档](https://communitydragon.org/documentation/assets)。

下载的图片属于第三方游戏资产。同步工具只负责本地开发资源管理，不授予再分发或商业使用权；使用和分发前应自行确认适用的 Riot/第三方条款。
