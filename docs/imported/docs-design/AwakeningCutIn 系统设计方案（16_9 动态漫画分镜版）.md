# AwakeningCutIn 系统设计方案（16:9 动态漫画分镜版）

## 设计目标

`AwakeningCutIn` 是一个独立于技能逻辑之外的战斗演出覆盖层系统，用于在角色释放觉醒技能时，同步展示角色立绘演出。它不打断技能、不暂停动画、不冻结场景、不接管镜头，而是在技能正常释放的同时，以一种具有动态漫画分镜感的方式，将角色立绘、职业主题色和切割式 UI 演出叠加到战斗画面之上。

这一系统的核心目标不是做成传统的大招过场，而是做成一种 **并行演出层**。玩家在看到觉醒立绘切入的同时，仍然能持续观察角色动作、特效释放与战场变化。对于同屏多个角色同时释放觉醒的情况，系统应自动将多个立绘整合为一组 **斜切分镜阵列**，形成连续切开的漫画格，而不是多个全屏弹窗彼此竞争。

系统最终追求的观感应接近：

- 有强烈的动态漫画分镜感
- 多角色同时释放时能够自动编排
- 立绘演出具备职业主题色和个体辨识度
- 视觉存在感明确，但不压死战斗主体
- 屏幕中央始终尽量保留战斗可视安全区

---

## 系统定位

`AwakeningCutIn` 的职责只有三项：

- 在技能释放时同步展示角色觉醒立绘
- 用斜切遮罩、主题底板、扫光和条纹等方式构建立绘演出
- 在极短时间内自动进入、停留、退出，并支持多人同屏编排

它不负责：

- 技能动画播放
- 技能判定与伤害逻辑
- 战斗暂停或时间冻结
- 镜头逻辑接管
- 角色状态切换

因此推荐的调用方式应为：

```text
Skill System
 ├─ 正常播放技能逻辑
 └─ 通知 AwakeningCutInManager 播放 CutIn
```

而不是：

```text
AwakeningCutIn 反向驱动技能
```

---

## 总体表现原则

### 动态漫画感优先

多人同时觉醒时，画面应像被多条斜线切开的漫画分镜。每个角色立绘不是单独弹出，而是被编排到某一个斜切面板之中。随着同时觉醒人数增加，整个画面应从一个大面板，平滑过渡到多个连续排列的斜切分镜。

### 中央战斗安全区优先

觉醒立绘不应遮死画面中央。立绘主要应从左侧、右侧、左上、右下等边缘区域侵入。即使是多人同时觉醒，也应尽量把画面中央保留给技能主体、角色运动、命中特效与敌人位置。

### 面板动，立绘少动

演出的主运动应来自 **斜切遮罩的展开与退出**，而不是整张立绘在屏幕上飞来飞去。立绘本身只做轻微推进、位移和明暗变化即可。

### 多人同时释放时优先编排，不优先叠加

系统要尽量避免“一个全屏立绘还没结束，另一个又硬盖上去”的情况。多角色 CutIn 应先被合并、分组、编排成一组布局，再播放。

---

## 16:9 画面约束

推荐基准分辨率：

```text
1920 × 1080
```

推荐中央战斗安全区可理解为：

```text
约 960 × 600
```

这是一个设计约束，而不是死规则。意思是觉醒 CutIn 尽量避免长时间大面积覆盖屏幕中央的这一区域。面板允许切入中央，但不宜长期停留，也不宜完全遮挡。

对于 16:9 画面，建议 CutIn 面板主要活动区域为：

- 左边缘
- 右边缘
- 左上斜入
- 右下斜入
- 左下斜入
- 右上斜入

不推荐大面积正中居中的纯矩形展示方式。

---

## 系统结构

推荐使用一个独立的 `CanvasLayer` 作为觉醒演出层。

```text
GameRoot
├─ BattleScene
├─ UI
└─ AwakeningCutInLayer (CanvasLayer)
   └─ AwakeningCutInManager
      ├─ Slot_0
      ├─ Slot_1
      ├─ Slot_2
      ├─ Slot_3
      └─ SharedFX
```

### 组成说明

#### `AwakeningCutInManager`
管理全局 CutIn 请求，负责收集、合并、分配、布局、优先级和重排过渡。

#### `Slot_0 ~ Slot_3`
每个 `Slot` 对应一个实际的立绘显示单元。每个单元独立处理自己的立绘、斜切遮罩、底板、扫光、条纹、文字与进入退出动画。

#### `SharedFX`
可选的全屏公共效果层，例如背景压暗、整体白闪、全局速度线等。

---

## 数据驱动设计

建议每个觉醒立绘演出由一个独立 `Profile` 描述，不要将参数散落在代码里。

### `AwakeningCutInProfile`

建议字段：

```text
id
portrait_texture
theme_color
accent_color
name_text
sub_name_text
priority
faction
enter_duration
hold_duration
exit_duration
darken_alpha
panel_slant
panel_feather
panel_edge_glow
panel_shine_enabled
panel_shine_speed
panel_width_ratio
portrait_scale_from
portrait_scale_to
portrait_offset_from
portrait_offset_to
accent_lines_enabled
flash_on_enter
flash_on_exit
layout_weight
```

### 字段含义说明

- `portrait_texture`：立绘资源
- `theme_color`：职业主色，如蓝、红、金、紫
- `accent_color`：强调色，用于扫光、条纹、边缘高亮
- `priority`：用于多人同时觉醒时确定主次
- `faction`：可用于区分我方/敌方切入方向
- `panel_slant`：斜切角度
- `panel_width_ratio`：当前面板占可视宽度比例
- `portrait_scale_from/to`：立绘轻微推进参数
- `portrait_offset_from/to`：立绘轻微位移参数

推荐每个角色或每个觉醒技能维护一份独立 Profile，例如：

```text
AwakeningCutInProfiles/
├─ hero_01_awaken_1.tres
├─ hero_01_awaken_2.tres
├─ hero_02_awaken_1.tres
└─ boss_01_awaken.tres
```

---

## 请求机制与合并机制

### 请求入口

角色释放觉醒时，只发送一个播放请求：

```gdscript
AwakeningCutInManager.request_cutin(profile)
```

技能本体照常执行：

```gdscript
func cast_awakening():
    animation_player.play("awakening")
    vfx_player.play("awakening_fx")
    AwakeningCutInManager.request_cutin(awakening_profile)
```

### 批处理窗口

为了支持多人同时觉醒时的统一编排，推荐设置一个短暂的批处理窗口，例如：

```text
batch_window = 0.10 秒
```

这意味着在 100ms 内到达的多个 CutIn 请求，都被视为“同一组同时觉醒”，统一编排。例如：

```text
0.000s A 请求
0.036s B 请求
0.082s C 请求
```

最终会被当作一个三人觉醒组处理，直接进入三分镜布局。

### 为什么需要合并窗口

如果没有这个机制，会出现非常不稳定的 UI 重排：

```text
A 先以单人布局进入
随后 B 到来，画面重排为双人
随后 C 到来，画面又重排为三人
```

这会造成 CutIn 本身显得犹豫、凌乱，失去“同一波爆发”的动态漫画感。引入极短的合并窗口后，可以让布局从一开始就是正确的。

---

## 多人同时觉醒的布局系统

## 总体思路

系统应根据同一批次内的觉醒人数自动选择布局模板。

推荐支持：

- `Layout_SINGLE`
- `Layout_DUAL`
- `Layout_TRIPLE`
- `Layout_QUAD`

每种布局都遵守“动态漫画分镜”原则，而不是简单均分屏幕。

---

## 单人布局 `Layout_SINGLE`

单人时不建议全屏。推荐一个偏左或偏右的大斜切面板，占屏幕宽度约 45%～60%。

推荐构图倾向：

- 面板主要从屏幕一侧切入
- 屏幕另一侧保留战斗主体
- 面板底板和立绘斜向切入
- 立绘本体不必完整显示，可有一定裁切

示意：

```text
┌──────────────────────────────┐
│████████████╲                 │
│████ 角色 ███╲                │
│████ 立绘 ████╲   战斗区域    │
│██████████████╲               │
└──────────────────────────────┘
```

---

## 双人布局 `Layout_DUAL`

双人时不建议简单左右 50/50。更推荐“左上 vs 右下”的对咬式斜切。

示意：

```text
┌──────────────────────────────┐
│████角色A████╲                │
│██████████████╲               │
│              ╲█████████████ │
│               ╲██角色B█████ │
└──────────────────────────────┘
```

表现重点：

- A 面板偏左上
- B 面板偏右下
- 两者切边方向有冲突关系
- 中央仍保留一条窄战斗可视走廊

这会产生很强的联动感，像两格漫画互相咬合。

---

## 三人布局 `Layout_TRIPLE`

三人时最适合做成连续斜切分镜。不是三等分，而是像漫画页上连续向一个方向推进的三格切带。

示意：

```text
┌──────────────────────────────┐
│████ A ███╲                   │
│       █████ B ███╲           │
│              █████ C ███╲    │
│                    战斗区    │
└──────────────────────────────┘
```

表现重点：

- 三个面板像连续切开的分镜带
- 面板可以略有重叠
- 每个面板不需要同等尺寸
- 主角色可占更大比重，次级角色略小

这类布局非常适合表现“多人同时爆发”。

---

## 四人布局 `Layout_QUAD`

四人时不建议继续做单向连续切带，会过碎。更适合做成“2×2 的斜切矩阵”，但每个单元仍保留斜边语言。

示意：

```text
┌──────────────────────────────┐
│████ A ███╲  ╱████ B ████    │
│████████████\/████████████    │
│            /\                │
│████ C ███╱  ╲████ D ████    │
└──────────────────────────────┘
```

表现重点：

- 四个面板像一张被交叉切开的分镜网格
- 仍然保留中部部分可视区域
- 每个面板的切向可以稍有变化
- 要尽量避免过多文本，防止画面密度过高

---

## 优先级与主次关系

多人同时觉醒时，建议引入 `Primary` 与 `Secondary` 的概念。

### Primary CutIn
优先级最高，通常是：

- 玩家当前操控角色
- 队伍中的主角
- 权重最高的觉醒
- 剧情关键角色
- Boss 角色

### Secondary CutIn
其余同组角色。

### 表现差异

推荐表现：

- Primary 面板面积略大
- Primary 立绘亮度更高
- Primary 底板更完整
- Secondary 略小、略弱，不抢占视觉中心

这样即使同时三人觉醒，画面也有主次，不会三张图彼此争抢。

---

## Slot 结构设计

每个 `AwakeningCutInSlot` 都可以是一个可复用组件。

推荐节点结构：

```text
AwakeningCutInSlot
├─ PanelMaskRoot
│  ├─ PanelBack
│  ├─ Portrait
│  ├─ Shine
│  ├─ AccentLines
│  └─ EdgeGlow
├─ NameText
├─ SubNameText
└─ FlashOverlay
```

### 说明

#### `PanelBack`
主题底板，可用纯色、渐变、斜向色块。

#### `Portrait`
角色立绘，核心显示层，通过 Shader 参与斜切遮罩裁切。

#### `Shine`
扫光层，可叠加在立绘之上，也可由同一 Shader 直接生成。

#### `AccentLines`
细条纹、速度线、能量纹，可用很低透明度辅助强化漫画感。

#### `EdgeGlow`
面板边缘高亮，可与 `Portrait` 统一通过 Shader 生成，也可拆层。

#### `NameText`
角色名或技能名。建议弱化，作为辅助，而不是视觉中心。

---

## Slot 生命周期

每个 Slot 应具备独立的状态机：

```text
IDLE
ENTER
HOLD
EXIT
```

### `IDLE`
隐藏，等待分配。

### `ENTER`
面板切入、立绘显现、压暗建立、扫光启动。

### `HOLD`
短暂停留。立绘轻微缓动，扫光完成，条纹维持。

### `EXIT`
面板收束或滑离，透明度降低，最终隐藏。

推荐单个 CutIn 总时长：

```text
0.45s ~ 0.80s
```

推荐时长分配：

```text
ENTER 0.12s ~ 0.20s
HOLD  0.20s ~ 0.45s
EXIT  0.10s ~ 0.18s
```

---

## 重排与布局过渡

如果已有一个或多个 CutIn 正在播放，又有新的请求到达，不应生硬替换，而应进行一次短促的布局过渡。

例如：

- 原本是 `Layout_SINGLE`
- 新角色加入后切换为 `Layout_DUAL`

推荐过渡时间：

```text
0.10s ~ 0.15s
```

过渡行为应包括：

- 旧面板位置与尺寸平滑缩放
- 新面板从目标区域快速展开
- 背景压暗总量不突变
- 不要重新播放整套大白闪，只播放新角色自身的切入效果

这样布局变化看起来就像漫画页被继续切开，而不是界面重新排版。

---

## 阵营与切入方向语法

推荐给不同阵营定义不同的默认切入方向。

例如：

- 我方：从左侧或左上斜入
- 敌方：从右侧或右下斜入

这样即使不看名字，只看方向，玩家也能快速知道当前觉醒是谁发起的。

同理，若同一阵营多人同时觉醒，可以让切向统一；若敌我对撞，则让切向相对，增强冲突感。

---

## 斜切遮罩设计

这个系统的灵魂是 `Slanted Panel Mask`。推荐直接用 `CanvasItem Shader` 实现，不建议纯用矩形裁切，也不建议只用 Polygon 做硬裁。

### 设计目标

遮罩应具备：

- 可参数化的斜切角度
- 可控制的面板宽度
- 平滑的边缘羽化
- 可选的边缘高亮
- 可选的扫光带
- 可选的条纹叠加
- 可控制的进入、保持、退出进度

### 基本思路

遮罩不是一张图片，而是由数学定义的斜带区域。对于某个像素，若其位于两条平行斜线之间，则可见；否则透明。

可将 UV 空间中的斜向值定义为：

```text
d = UV.x + slant * UV.y
```

这表示一条具有斜率的投影坐标。

如果定义：

```text
left_edge  = progress - panel_width
right_edge = progress
```

则满足：

```text
left_edge <= d <= right_edge
```

的区域，就是当前可见的斜切面板。

### 为什么推荐这种方式

它天然适合：

- 做进入动画：`progress` 从小到大
- 做退出动画：`progress` 继续推进或反向收束
- 做羽化：边缘用 `smoothstep`
- 做边缘亮线：根据像素距离边缘的距离计算
- 做扫光：在 `d` 方向叠加窄亮带

---

## 遮罩视觉结构建议

一个完整的斜切面板建议由以下几部分组成：

- 面板主体可视区域
- 面板边缘羽化
- 面板边缘高亮
- 面板内部立绘显示
- 面板内部低透明条纹 / 速度线
- 面板表面扫光带

### 视觉建议

#### 主体区域
主要显示立绘和职业底板，整体清晰，边界斜切。

#### 羽化边缘
边缘不应硬切，否则像廉价 UI 截图。应至少有 4px～16px 左右的视觉羽化，实际值取决于分辨率。

#### 边缘高亮
斜切边缘可带一层细的明亮色，例如白色、浅金色、主题色高亮，增强“刀切开”的感觉。

#### 扫光
一条沿着切面方向移动的亮带，宽度不宜太大。扫过时立绘局部会更亮，模拟能量掠过。

#### 条纹
可叠加极低透明度的平行条纹、速度线或能量条纹，形成漫画页与职业氛围感。

---

## 建议的 Shader 参数

建议统一为如下参数：

```text
progress
panel_width
slant
feather
edge_glow_strength
theme_color
accent_color
shine_enabled
shine_progress
shine_width
shine_strength
portrait_scale
portrait_offset
stripe_enabled
stripe_density
stripe_speed
stripe_strength
global_alpha
```

### 参数说明

- `progress`：面板展开进度
- `panel_width`：面板宽度
- `slant`：斜率
- `feather`：边缘羽化宽度
- `edge_glow_strength`：边缘高亮强度
- `shine_progress`：扫光位置
- `shine_width`：扫光宽度
- `portrait_scale`：立绘缩放
- `portrait_offset`：立绘偏移
- `stripe_*`：条纹相关参数
- `global_alpha`：整体透明度

---

## Shader 逻辑建议

建议逻辑分为五步：

### 1. 计算斜向投影值

```text
d = UV.x + slant * UV.y
```

### 2. 计算面板区域 Mask

根据 `progress` 和 `panel_width` 计算当前像素是否位于面板中，并用 `smoothstep` 做边缘过渡。

### 3. 采样立绘

对立绘进行轻微的偏移和缩放采样，不要夸张移动。

### 4. 叠加边缘高亮与扫光

边缘高亮沿左右边缘分别计算；扫光以一条窄亮带形式沿 `d` 方向移动。

### 5. 输出颜色与透明度

面板区域内显示立绘和底板叠加结果，外部输出透明。

---

## Shader 伪代码示意

以下为概念性伪代码，用于明确视觉逻辑，不是最终可直接运行代码。

```glsl
shader_type canvas_item;

uniform float progress = 0.0;
uniform float panel_width = 0.45;
uniform float slant = 0.35;
uniform float feather = 0.02;

uniform float edge_glow_strength = 0.6;

uniform bool shine_enabled = true;
uniform float shine_progress = 0.0;
uniform float shine_width = 0.08;
uniform float shine_strength = 0.5;

uniform bool stripe_enabled = true;
uniform float stripe_density = 24.0;
uniform float stripe_speed = 1.0;
uniform float stripe_strength = 0.12;

uniform vec4 theme_color : source_color = vec4(0.2, 0.4, 1.0, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float portrait_scale = 1.0;
uniform vec2 portrait_offset = vec2(0.0, 0.0);
uniform float global_alpha = 1.0;

void fragment() {
    vec2 uv = UV;
    float d = uv.x + slant * uv.y;

    float left_edge = progress - panel_width;
    float right_edge = progress;

    float left_mask = smoothstep(left_edge - feather, left_edge + feather, d);
    float right_mask = 1.0 - smoothstep(right_edge - feather, right_edge + feather, d);
    float panel_mask = left_mask * right_mask;

    vec2 portrait_uv = (uv - 0.5) / portrait_scale + 0.5 + portrait_offset;
    vec4 portrait = texture(TEXTURE, portrait_uv);

    float left_dist = abs(d - left_edge);
    float right_dist = abs(d - right_edge);
    float edge_factor = max(
        1.0 - smoothstep(0.0, feather * 2.0, left_dist),
        1.0 - smoothstep(0.0, feather * 2.0, right_dist)
    );
    vec3 edge_glow = accent_color.rgb * edge_factor * edge_glow_strength;

    float shine = 0.0;
    if (shine_enabled) {
        float shine_center = mix(left_edge, right_edge, shine_progress);
        shine = 1.0 - smoothstep(0.0, shine_width, abs(d - shine_center));
        shine *= shine_strength;
    }

    float stripes = 0.0;
    if (stripe_enabled) {
        float stripe_coord = (uv.x - uv.y * slant) * stripe_density + TIME * stripe_speed;
        stripes = step(0.5, fract(stripe_coord)) * stripe_strength;
    }

    vec3 base_color = mix(theme_color.rgb, portrait.rgb, portrait.a);
    base_color += edge_glow;
    base_color += accent_color.rgb * shine;
    base_color += accent_color.rgb * stripes * 0.25;

    float final_alpha = panel_mask * max(portrait.a, 0.85) * global_alpha;
    COLOR = vec4(base_color, final_alpha);
}
```

---

## 面板进入与退出建议

遮罩动画的主角是 `progress`，而不是整张图大幅飞行。

### 进入时

- `progress` 从较小值迅速推进
- `global_alpha` 从 0 上升
- `portrait_scale` 从 1.05～1.08 缓到 1.00
- `portrait_offset` 从一个轻微偏移缓到 0
- `shine_progress` 在进入后半段快速扫过一次

### 保持时

- 立绘轻微稳定
- 条纹低强度持续存在
- 可允许第二次极弱扫光，但通常一次即可

### 退出时

有两种推荐方式：

#### 方式 A：继续推进
让 `progress` 沿原方向继续前进，面板像被继续推离屏幕。

#### 方式 B：缩窄收束
保持面板位置不大变，减小 `panel_width`，像分镜正在合拢。

推荐优先用方式 A，因为更符合“切开的漫画页继续翻走”的感觉。

---

## 背景压暗设计

建议使用一个全屏 `ColorRect` 放在最底层，用于压暗战场。

推荐参数：

```text
alpha = 0.25 ~ 0.45
```

不要太重。这个系统不是过场，不应把战斗完全压黑。压暗只用于稍微衬托立绘。

### 多个 CutIn 同时出现时

背景压暗不是叠加到越来越黑，而应保持一个合理上限。例如：

```text
max_darken_alpha = 0.45
```

如果三人同时觉醒，也不要比单人暗太多。

---

## 文本设计

文本不是必须，但可以保留。

推荐文本类型：

- 角色名
- 技能名
- 职业称号（可选）

### 原则

- 文字是辅助，不是主视觉
- 大多数情况下技能名比角色名更有意义
- 文本最好沿着面板方向排布，形成分镜一致性
- 多人同时出现时，尽量简化文本量，避免 UI 过密

若画面已经足够复杂，完全可以不显示文字，仅用职业色和立绘表达。

---

## 节奏建议

觉醒 CutIn 的存在感应明确，但不应过长。推荐一组普适时长：

```text
单人：
0.15s Enter
0.35s Hold
0.12s Exit
总计 ≈ 0.62s

双人/三人/四人：
0.14s Enter
0.28s Hold
0.12s Exit
总计 ≈ 0.54s
```

人数越多，建议停留越短，因为多人分镜本身已经提高了画面密度。

---

## 推荐的开发阶段

## 第一阶段：先跑通系统骨架

先实现：

- `AwakeningCutInManager`
- `AwakeningCutInSlot`
- 单人布局
- 双人布局
- 斜切遮罩基础版
- 背景压暗
- 立绘进入、停留、退出

先不要做太多花哨辅助效果。

## 第二阶段：补齐多人布局

增加：

- 三人布局
- 四人布局
- 批处理窗口
- 优先级系统
- 布局重排过渡

## 第三阶段：增强表现层

增加：

- 扫光
- 条纹 / 速度线
- 面板边缘高亮
- 文本可选支持
- 阵营切向语法
- 主次面板差异化

---

## 推荐的管理器职责划分

### `AwakeningCutInManager`
负责：

- 接收 `request_cutin(profile)`
- 批处理收集
- 确定本批次布局模板
- 按优先级分配 Slot
- 处理旧布局向新布局的重排过渡
- 控制共享层效果，如背景压暗

### `AwakeningCutInSlot`
负责：

- 加载 profile 内容
- 显示立绘
- 驱动本地状态机
- 播放进入/保持/退出
- 处理本地 Shader 参数动画
- 自主汇报完成状态

---

## 最终系统定义

`AwakeningCutIn` 应被定义为一个 **独立的战斗演出覆盖层系统**。它在技能正常释放期间同步展示角色觉醒立绘，不中断战斗逻辑。系统采用 `Manager + Slots + Profile + Shader Mask` 的架构，基于 16:9 画面使用动态漫画分镜式布局，根据同批次内的觉醒人数自动选择单人、双人、三人或四人布局，并通过斜切遮罩、主题色底板、扫光和条纹等元素建立具有职业识别度与战斗节奏感的立绘演出。

其核心表现语言应是：

**不是弹窗，而是动态漫画分镜；不是全屏过场，而是战斗上层的同步切入。**

---

## 给实现层的简短结论

如果只保留一组最关键的实现原则，应当是：

- CutIn 与技能逻辑完全解耦，只做同步演出
- 多人同时觉醒必须统一编排，而不是叠盖
- 16:9 画面中，中央应尽量保留战斗安全区
- 斜切遮罩是核心视觉语言
- 运动主体是遮罩，不是立绘大幅滑动
- 动态漫画感优先于传统 UI 整齐感
- 允许面板较小，但不允许失去节奏与分镜张力

---