# Astryx-to-Evoly UI 重构计划

更新日期：2026-07-06

## Summary

本计划将 Meta 开源设计系统 Astryx 作为设计参考，对 Evoly 的 Flutter UI 体系进行渐进式重构。

Astryx 本身是 React 19 + StyleX + CSS custom properties 的 Web 设计系统，不作为 Evoly 的运行时依赖，也不直接搬运 TSX 组件。Evoly 只吸收其设计系统方法：

- 清晰的 token 分层。
- light/dark 成对主题值。
- 可组合组件契约。
- 页面模板和常见工作流模式。
- 可访问性、状态、密度和文档规范。
- 面向人和 AI 协作的组件说明方式。

重构目标不是把 Evoly 改成 Astryx，而是让 Evoly 的现有 HUD / glass 视觉语言变得更稳定、更可维护，并让普通工作台页面更克制、更适合长期使用。

## 非目标

- 不把 `facebook/astryx` 作为 git submodule 加进主仓。
- 不在 `pubspec.yaml` 中引入任何 Astryx 包。
- 不把 React、StyleX、pnpm 或 Node 工具链引入 Flutter App 构建链路。
- 不直接复制 Astryx 的 React 组件源码。
- 不做一次性全量换皮。
- 不改动任务、提醒、同步、数据库等业务逻辑，除非某个 UI 迁移明确需要。

## 参考源状态

本地参考副本位于：

```text
D:\dev\tmp\astryx
```

当前参考 commit：

```text
a18ca6b7f9824bff77a457051d5456218b37117a
2026-07-05 01:30:51 +0000 fix(cli): strip astryx- prefix for theme override keys (#3527)
```

公开 npm 包版本：

```text
@astryxdesign/core          0.1.3
@astryxdesign/theme-neutral 0.1.3
@astryxdesign/cli           0.1.3
```

许可证为 MIT。若后续复制了 substantial token 表、文档片段或源码结构，需要保留对应版权和许可证说明。

## 当前 Evoly UI 基线

相关入口：

```text
lib/app/theme.dart
lib/app/theme_preset.dart
lib/shared/ui/tokens/evoly_design_tokens.dart
lib/shared/ui/tokens/app_spacing.dart
lib/shared/ui/tokens/app_radii.dart
lib/shared/ui/motion/motion_tokens.dart
lib/shared/ui/components/
lib/shared/ui/bottom_sheets/
```

当前视觉语言：

- Material 3 作为组件基础。
- `ColorScheme.fromSeed` 生成主题主干。
- `EvolyDesignTokens` 承载 HUD / glass 语义。
- Windows full app、Windows HUD 迷你面板、Android 主界面共用一套 token。
- 部分页面仍直接使用 `Card`、`TextField`、`FilledButton`、`ChoiceChip` 等 Material 组件，组件契约和页面模式还没有完全收敛。

## 设计原则

### 1. Evoly 优先

Evoly 是目标推进、提醒和复盘工具。主界面应该安静、可扫描、效率优先；HUD 和提醒面板可以保留更强的品牌质感。

### 2. Astryx 作方法，不作外观模板

吸收 Astryx 的 token、组件和模板方法，但不照搬 Web 视觉或 React 组件。

### 3. 语义 token 优先

页面和组件不直接消费随意颜色。新增或整理 token 时优先使用语义名，例如：

```text
bodyBackground
surface
surfaceRaised
surfaceMuted
popoverSurface
borderSubtle
borderEmphasized
textPrimary
textSecondary
statusSuccess
statusWarning
statusError
priorityHigh
priorityMedium
priorityLow
```

### 4. 工作台克制，HUD 保留特色

普通页面减少装饰性渐变、过重 glass、过大圆角和过多阴影。桌面迷你提醒面板、Nobi/HUD 相关界面可以继续使用更明显的 glass 表现。

### 5. 渐进迁移

每次只迁移一层或一个页面簇，确保 `flutter analyze`、`flutter test` 和 Android debug build 可持续通过。

## Astryx 到 Evoly 的映射

| Astryx 思路 | Evoly 落点 | 备注 |
| --- | --- | --- |
| `--color-background-body` | `pageBackground` / `bodyBackground` | 主画布，工作台页面更克制 |
| `--color-background-surface` | `surface` | 输入、选择器、基础控件表面 |
| `--color-background-card` | `surfaceRaised` / `cardSurface` | 卡片和列表项 |
| `--color-background-popover` | `popoverSurface` | Dialog、BottomSheet、Menu |
| `--color-text-primary` | `ThemeData.textTheme` / `textPrimary` | 主要文本 |
| `--color-text-secondary` | `textSecondary` | 说明和 meta 文本 |
| `--color-border` | `outlineSubtle` / `borderSubtle` | 默认边线 |
| `--color-border-emphasized` | `borderEmphasized` | focus、selected、重要边线 |
| `--color-success/error/warning` | `statusSuccess/Error/Warning` | 状态和反馈 |
| categorical palette | `chartPalette` / 标签色 | 图表、文档类型、分类 |
| `--radius-inner/element/container/page` | `AppRadii` 语义别名 | 避免到处手写数字 |
| `--shadow-low/med/high` | `BoxShadow` token | 统一 elevation |
| component docs | `docs/ui/` | Flutter 组件说明 |
| page templates | Flutter layout widgets | Today、Goal Detail、Settings 等 |

## 分阶段计划

### Phase 0：设计审计与映射文档

目标：建立 Astryx-to-Evoly 的明确转换表，避免后续凭感觉改 UI。

任务：

- 梳理当前 `EvolyDesignTokens` 字段用途。
- 标注哪些字段是 legacy 兼容，哪些字段是未来主语义。
- 从 Astryx Neutral theme 提取可参考的 surface/text/status/radius/shadow/motion 模型。
- 为主页面和 HUD 页面定义不同视觉密度策略。
- 形成 token 映射表和页面迁移顺序。

产出：

- 本文档持续更新。
- 可选新增 `docs/ui/token-mapping.md`。

验收：

- 不改运行时代码。
- 明确 Phase 1 的 token 目标字段。

### Phase 1：主题和 token 基础层

目标：先让 token 体系完整，再迁移页面。

任务：

- 在 `EvolyDesignTokens` 中补充更明确的语义字段：
  - `bodyBackground`
  - `cardSurface`
  - `popoverSurface`
  - `surfaceMuted`
  - `borderSubtle`
  - `borderEmphasized`
  - `textPrimary`
  - `textSecondary`
  - `shadowLow`
  - `shadowMedium`
  - `shadowHigh`
- 保留现有字段，避免旧页面立即失效。
- 在 `AppRadii` 增加语义别名：
  - `inner`
  - `element`
  - `container`
  - `page`
- 在 `MotionTokens` 中明确 fast/medium/slow 对应 UI 场景。
- 可选新增主题预设：
  - `EvolyThemePreset.focusNeutral`
  - 或 `EvolyThemePreset.astryxNeutral`

迁移策略：

- 先让新增 token 从现有 HUD token 派生。
- 再引入 neutral preset 做视觉对照。
- 不立刻大规模替换页面。

验收：

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

### Phase 2：共享组件层

目标：把页面直接写 Material 组件的模式，逐步收敛到 Evoly 自己的组件契约。

优先组件：

#### `AppSurface`

替代散落的 `Card` / `AppGlassSurface` / 手写 `Container` 装饰。

建议 API：

```dart
enum AppSurfaceVariant {
  plain,
  raised,
  muted,
  glass,
  selected,
  warning,
}
```

能力：

- 统一背景、边线、圆角、阴影。
- 支持 hover、selected、disabled。
- 支持普通工作台风格和 HUD glass 风格。

#### `AppSection`

统一 section header、subtitle、trailing action、content spacing。

适用：

- Today 今日任务分组。
- Goal Detail 子任务区、文档区。
- Settings 分组。
- Stats 指标区。

#### `AppField`

统一输入控件外壳、label、helper、error、required 状态。

适用：

- 任务创建/编辑。
- 目标创建/编辑。
- 设置页表单。

#### `AppActionButton`

统一按钮尺寸、图标、loading、danger、primary/secondary。

适用：

- BottomSheet 提交按钮。
- 页面 header action。
- 空状态 action。

#### `AppStatusBadge`

统一状态展示。

适用：

- 任务状态。
- 优先级。
- 同步状态。
- 提醒状态。
- 文档类型。

验收：

- 新组件具备 widget test。
- 旧组件可继续存在，逐步委托到新组件。

### Phase 3：页面模板层

目标：建立 Flutter 版页面模式，而不是每个页面单独布局。

#### `WorkbenchPageLayout`

适用：

- Today
- Goals
- Documents
- Stats

能力：

- 移动端单列。
- 桌面端主内容 + 侧栏。
- 统一页面 padding、section spacing、刷新区域。

#### `DetailPageLayout`

适用：

- Goal Detail
- Document Edit

能力：

- header title + actions。
- meta 区。
- 主内容 section。
- linked content / side panel。

#### `SettingsPageLayout`

适用：

- SettingsPage

能力：

- setting group。
- setting row。
- inline description。
- danger zone。

#### `BottomSheetFormLayout`

适用：

- 新建目标。
- 新建子任务。
- 编辑目标。
- 编辑任务。

能力：

- 标题、保存状态、字段区、底部动作统一。
- 统一 keyboard avoidance。
- 支持 compact spacing。

#### `CompactHudLayout`

适用：

- Windows 迷你提醒面板。

能力：

- 保留 glass/HUD。
- 统一折叠/展开尺寸、hover action、状态指标。

### Phase 4：页面迁移顺序

#### 1. 任务和目标 BottomSheet

优先级最高。

原因：

- 范围小。
- 用户高频使用。
- 最近已有创建/编辑/提醒相关改动，顺手统一体验。

涉及文件：

```text
lib/features/tasks/presentation/widgets/task_create_sheet.dart
lib/features/tasks/presentation/widgets/task_edit_sheet.dart
lib/features/goals/presentation/widgets/goal_edit_sheet.dart
lib/shared/ui/bottom_sheets/
```

#### 2. Goal Detail

原因：

- 结构明显：目标 header、进度、文档、子任务列表。
- 很适合验证 `DetailPageLayout` 和 `AppSection`。

涉及文件：

```text
lib/features/goals/presentation/goal_detail_page.dart
lib/features/tasks/presentation/widgets/task_card.dart
```

#### 3. Today Page

原因：

- 是主工作台。
- 需要更强的信息密度和扫描效率。

涉及文件：

```text
lib/features/today/presentation/today_page.dart
lib/features/tasks/presentation/widgets/task_card.dart
```

#### 4. Settings

原因：

- 低风险。
- 非常适合沉淀 settings pattern。

涉及文件：

```text
lib/features/settings/presentation/settings_page.dart
```

#### 5. Documents / Stats

原因：

- 可借鉴 Astryx 的 documentation、table、dashboard template 思路。
- 但不应抢在核心任务链路之前。

#### 6. Compact Reminder HUD

原因：

- 它是 Evoly 品牌感最强的界面。
- 不应过度 Astryx neutral 化。
- 等主 token 稳定后，只做 token 化和边界测试加强。

涉及文件：

```text
lib/features/desktop_window/presentation/compact_reminder_panel.dart
lib/features/desktop_window/domain/compact_reminder_snapshot.dart
```

## 视觉策略

### 普通工作台页面

目标：

- 更安静。
- 更可扫描。
- 更少装饰。
- 更稳定的层级。

倾向：

- 低饱和背景。
- 明确 surface 分层。
- 较少使用强 glass blur。
- 卡片圆角收敛到 8-12px。
- 阴影轻量，更多依赖边线和背景层次。

### HUD / 迷你提醒面板

目标：

- 保留 Evoly 桌面小组件气质。
- 更精致，但不花。

倾向：

- 继续使用 glass surface。
- 继续使用轻 blur。
- 保留 HUD accent。
- 强化尺寸、hover、展开/收起边界稳定性。

### 表单和弹层

目标：

- 信息集中。
- 键盘弹出不跳。
- 主动作明确。

倾向：

- compact spacing。
- 明确 label/helper/error。
- 底部动作固定或稳定靠下。
- 避免大面积装饰卡片嵌套。

## 可访问性标准

- 触控目标不小于 `AppSpacing.minTouchTarget`。
- 文本不靠 viewport 缩放。
- 颜色不能只用 hue 表达状态，重要状态需要文字或图标。
- 所有 icon-only button 提供 tooltip 或 semantic label。
- BottomSheet 和 Dialog 保持清晰 focus order。
- 深色模式下 status/text contrast 需要人工检查。

## 验证清单

每个阶段至少运行：

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

涉及 Windows HUD 或桌面窗口后追加：

```powershell
flutter build windows
```

人工截图检查：

- Android 竖屏。
- Android 键盘弹出。
- Windows 普通窗口。
- Windows 迷你提醒面板折叠/展开。
- 深色模式。
- 长标题。
- 空状态。
- 错误状态。
- 同步/提醒状态。

## 风险与应对

### 风险：Evoly 品牌感被冲淡

应对：

- Astryx neutral 只用于工作台秩序，不覆盖 HUD 和品牌元素。
- 保留 Evoly 的 HUD accent、Nobi/提醒角色、桌面小组件气质。

### 风险：重构范围失控

应对：

- 每阶段限制文件范围。
- 优先迁移共享组件，再迁移页面。
- 不在 UI 重构中夹带业务逻辑变更。

### 风险：移动端信息密度过高

应对：

- Workbench layout 桌面和移动分离。
- 移动端保留清晰 section spacing。
- 只在桌面端提高密度。

### 风险：暗色模式 regressions

应对：

- token 成对定义。
- 每个页面迁移都检查 light/dark。
- 避免只用 alpha 叠加推导关键文本色。

## 建议 PR / 变更批次

### Batch 1：文档

```text
docs: add Astryx-to-Evoly UI refactor plan
```

只新增/更新计划文档。

### Batch 2：Token 基础

```text
theme: add semantic surface, text, radius, and shadow tokens
```

新增 token，不迁移页面。

### Batch 3：共享组件

```text
ui: introduce AppSurface, AppSection, AppField, and AppStatusBadge
```

新增组件和测试，旧组件开始委托。

### Batch 4：BottomSheet 表单

```text
tasks: migrate task and goal sheets to shared form layout
```

迁移任务/目标创建编辑弹层。

### Batch 5：Goal Detail

```text
goals: migrate detail page to section-based layout
```

迁移目标详情页。

### Batch 6：Today Workbench

```text
today: migrate today page to workbench layout
```

迁移今日页。

### Batch 7：Settings / Documents / Stats

```text
settings: migrate settings page to grouped settings layout
documents: align document surfaces with shared components
stats: align metric and chart surfaces with shared components
```

分页面推进。

### Batch 8：HUD polish

```text
desktop: align compact reminder HUD with semantic tokens
```

最后处理桌面迷你面板。

## 下一步

建议下一步从 Batch 2 开始：

1. 为 `EvolyDesignTokens` 增加语义 surface/text/border/shadow 字段。
2. 为 `AppRadii` 增加 Astryx 风格的语义别名。
3. 让现有字段继续兼容旧页面。
4. 不迁移页面，只跑验证。

