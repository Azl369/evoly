# Evoly 图标改版概念稿

> 本轮先做方向探索，不直接替换现有 Android 图标。候选稿均为 SVG，位于 `design/icons/evoly/`，后续选定方向后再输出 Android mipmap / adaptive icon / foreground icon。

---

## 品牌关键词

- **成长**：追踪个人成长，不只是待办清单。
- **推进**：帮助用户把目标拆成可行动的下一步。
- **温和督促**：Coach 是提醒和陪跑，不是制造压力。
- **清爽高效**：移动端图标需要一眼识别，不能太复杂。

主色建议沿用当前产品色：

- Evoly Blue：`#5B6CFF`
- Soft Blue：`#8EA0FF`
- Growth Green：`#2EE6A6` / `#7CF7C6`
- Deep Ink：`#101828`

---

## 方案 A：Growth Leaf / 成长叶芽

文件：`design/icons/evoly/evoly-icon-concept-a-growth-leaf.svg`

### 核心表达

用叶芽表达个人成长，用中间的生长脉络表达“每天推进一点点”。整体更偏温和、长期主义。

### 优点

- 很贴合 Evoly 的“个人成长追踪”定位。
- 比传统待办清单更有产品格调。
- 颜色柔和，适合长期陪伴型 App。

### 风险

- 和泛健康、习惯养成、冥想类 App 有轻微重叠。
- 如果想强调“任务管理效率”，这个方向会稍微柔一点。

### 适合定位

成长记录、目标陪跑、个人提升。

---

## 方案 B：Trajectory / 上升轨迹

文件：`design/icons/evoly/evoly-icon-concept-b-trajectory.svg`

状态：**已选定并落地为 Evoly 当前 App 图标方向**。

落地资源：

- 源图：`design/icons/evoly/generated/evoly-app-icon-trajectory-1024.png`
- Android：`android/app/src/main/res/mipmap-*/ic_launcher.png`
- Windows：`windows/runner/resources/app_icon.ico`
- 生成脚本：`scripts/generate_evoly_app_icons.py`

### 核心表达

用上升轨迹和箭头表达目标推进、状态变好、持续进步。中间的勾选代表任务完成。

### 优点

- 目标感最强，容易理解为“进步”和“增长”。
- 远距离识别度不错。
- 比单纯 checklist 更有动态感。

### 风险

- 箭头图形稍偏商业/增长工具，温度感略弱。
- 需要精修线条比例，避免显得像数据分析 App。

### 适合定位

目标推进、效率提升、成长曲线。

---

## 方案 C：Compass / 成长指南针

文件：`design/icons/evoly/evoly-icon-concept-c-compass.svg`

### 核心表达

用指南针表达方向感和自我校准：Evoly 不只是记任务，而是帮助用户知道下一步往哪里走。

### 优点

- “Coach / 引导 / 决策”意味最强。
- 深色底更高级，和普通待办 App 区分度高。
- 适合后续 Evoly Coach 能力增强。

### 风险

- 指南针比“任务”更抽象，新用户可能需要一点理解成本。
- 小尺寸下需要保证指针形状清晰。

### 适合定位

个人成长 Coach、目标方向管理、长期规划。

---

## 方案 D：Task Card / 日程勾选

文件：`design/icons/evoly/evoly-icon-concept-d-task-card.svg`

### 核心表达

用卡片、日程、勾选表达最直接的任务管理。是最稳妥、最容易识别的方向。

### 优点

- 一眼能看懂是任务/计划 App。
- 和当前产品已有今日页、目标页功能匹配。
- 商店里搜索任务管理时，用户理解成本低。

### 风险

- 和大量 ToDo / Planner App 接近，独特性弱。
- “个人成长”气质不如 A/C/E 明显。

### 适合定位

V0.x 原型期、任务计划、提醒工具。

---

## 方案 E：Coach Star / Coach 星芒

文件：`design/icons/evoly/evoly-icon-concept-e-coach-star.svg`

### 核心表达

用星芒表达提醒、启发和 Coach 建议。外圈弧线表达持续循环和成长反馈。

### 优点

- 更有 Evoly Coach 的未来感。
- 在一堆 checklist 图标里更容易跳出来。
- 适合后续加入智能建议、复盘、成长洞察。

### 风险

- 星形可能被理解为收藏、灵感、AI 工具。
- 如果当前版本仍以任务管理为主，需要搭配产品名强化理解。

### 适合定位

Coach Lite、成长建议、复盘洞察、未来 AI 助手。

---

## 我的推荐

### 当前阶段最推荐：方案 C + 方案 A 融合

理由：

- Evoly 的长期定位不是普通 ToDo，而是“个人成长与目标驱动”。
- 方案 C 的指南针能表达“方向”和“Coach”。
- 方案 A 的叶芽能表达“成长”和“温和陪伴”。

后续可以融合为：

```text
外形：指南针/圆形方向感
内部：叶芽或向上生长轨迹
颜色：Evoly Blue + Growth Green
气质：清爽、智能、陪跑
```

### 如果要短期上线：方案 D

理由：

- 识别成本最低。
- 最接近当前 V0.x 功能。
- 适合快速换掉默认 Flutter 图标。

### 如果要做品牌差异化：方案 C 或 E

理由：

- 更不像普通待办。
- 更能承接 Evoly Coach 的后续方向。

---

## 下一步建议

1. 先从 A/B/C/D/E 中选 1–2 个方向。
2. 对选中方向做第二轮精修：
   - 去掉多余细节。
   - 测试 48px / 72px / 96px 小尺寸识别度。
   - 输出浅色/深色背景版本。
3. 生成 Android adaptive icon：
   - foreground：透明 PNG / SVG 源稿
   - background：纯色或渐变
   - mipmap：mdpi 到 xxxhdpi
4. 替换 Android 图标资源并真机查看桌面效果。
