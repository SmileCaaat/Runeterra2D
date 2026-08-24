# 程序化命中特效系统

## 目标与桥接方式

项目使用 3D 横版战斗空间，但程序化命中层使用 `GPUParticles2D`。系统在透明 `SubViewport` 中组合 2D 特效，再以 `ViewportTexture` 绑定到命中点的 `Sprite3D`，从而兼容 3D 摄像机、纵深移动和世界坐标命中点。

黄色普通/暴击序列帧作为主体轮廓保留，程序化层只负责补充瞬时亮度、方向、冲击范围和残留，不替代伤害、硬直、音频或序列帧逻辑。

## 层级

- `Flash`：运行时生成软边径向纹理，快速放大并衰减。
- `Burst`：360 度短寿命能量爆散。
- `Sparks`：围绕攻击方向窄角度高速飞散的条形碎光。
- `Shockwave`：`CanvasItem` 直接绘制双圆环，不依赖贴图。
- `Dust`：低速、受重力影响的软边残留。
- `Debris`：运行时生成方形纹理，模拟短促碎片。

软圆、条形火花和碎片纹理均由 `Image` 与 `ImageTexture` 在首次使用时生成并缓存。颜色使用 `GradientTexture1D`，缩放生命周期使用 `CurveTexture`。

## 对象池

全场共享一个 `HitImpactPool3D`，固定 8 个槽位。每个槽位持有一个 `256×256` 透明 `SubViewport`、一套多层 `GPUParticles2D` 和一个 `Sprite3D`。命中时循环复用槽位并调用 `restart()`，不创建临时粒子节点；空闲槽位使用 `UPDATE_DISABLED`，只在效果生命周期内更新 Viewport。

## Profile 映射

| 命中来源 | 程序化 Profile |
| --- | --- |
| 普通攻击 | `normal` |
| 实际暴击 | `critical` |
| 破舰强化攻击 | `heavy` |
| 翻江倒海 | `elemental` |
| 暴君审判船锚 | `anchor` |
| 七海霸权 | `magic` |

Profile 位于 `assets/vfx/hit/profiles/`，可配置颜色、持续时间、世界缩放、各层粒子数量、速度、扩散角度、冲击波半径、烟尘和碎片重力。普通命中保持在约 `0.26s`，技能类保持在 `0.44–0.68s`。对象池大小、Viewport 尺寸、序列帧尺寸/时长、暴击 Profile 和 `hit_profile → 程序化 Profile` 映射统一配置在 `assets/vfx/hit/hit_impact_system.tres`。
