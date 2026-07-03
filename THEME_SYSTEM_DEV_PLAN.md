# Evoly 主题系统开发计划

## 1. 背景

Evoly 当前已经有统一的 `AppTheme`，并通过 Material 3 `ColorScheme.fromSeed` 生成浅色和深色主题：

```text
AppTheme.light()
AppTheme.dark()
themeMode: ThemeMode.system
```

现状适合作为第一版基础主题，但还不能支持用户在 App 内选择不同的视觉风格。设置页中的“主题”目前也只是静态占位，没有真实状态、持久化或全局刷新能力。

本计划的目标是为 Evoly 增加一个轻量但可扩展的主题系统，让用户可以在不影响核心目标管理体验的前提下，选择更适合自己使用场景的视觉氛围。

---

## 2. 设计目标

主题系统不是简单“换皮肤”。它应该服务 Evoly 的产品气质：

```text
长期目标推进
每日行动聚焦
本地优先、安静可靠
少干扰、可持续使用
```

因此主题设计要满足：

- 主题有明确情绪，但不能抢内容的视觉优先级。
- 不使用大面积渐变、强装饰背景或过度营销感的配色。
- 保持目标、任务、文档、统计等页面的阅读清晰度。
- 支持浅色、深色和跟随系统。
- 用户切换后立即生效，并持久保存。
- 后续新增主题不需要大规模改页面代码。

---

## 3. 产品方案

### 3.1 两层主题模型

主题需要拆成两层：

```text
主题模式 ThemeMode
  - 跟随系统
  - 浅色
  - 深色

主题风格 ThemePreset
  - 默认蓝
  - 森林绿
  - 日出暖橙
  - 墨灰专注
```

这样用户可以自由组合：

```text
默认蓝 + 跟随系统
森林绿 + 深色
日出暖橙 + 浅色
墨灰专注 + 跟随系统
```

不要把“颜色风格”和“明暗模式”绑死，否则用户无法表达真实偏好。

### 3.2 第一批主题

第一版建议先做 4 套主题，避免选项过多导致维护和测试成本上升。

| ID | 名称 | 气质 | 使用场景 |
| --- | --- | --- | --- |
| `orbitBlue` | 默认蓝 | 清醒、理性、效率感 | 默认主题，延续当前 Evoly 识别度 |
| `forestGreen` | 森林绿 | 安静、恢复、长期主义 | 习惯养成、长期目标、低压力使用 |
| `sunriseCoral` | 日出暖橙 | 积极、温暖、行动感 | 今日行动、完成反馈、晨间计划 |
| `graphiteFocus` | 墨灰专注 | 克制、低干扰、专注 | 夜间、工作场景、深色偏好 |

主题不能只是替换 `primary`。每套主题至少要稳定定义：

- `primary`
- `secondary`
- `tertiary`
- `error` 保持语义一致
- surface / container 由 Material 3 scheme 推导
- 任务优先级、目标状态尽量从 `ColorScheme` 派生

---

## 4. 当前代码现状

### 4.1 已有基础

- `lib/app/theme.dart` 已集中定义主题。
- App 大部分 UI 使用 `Theme.of(context).colorScheme`。
- `MaterialApp` 已接入 `theme`、`darkTheme`、`themeMode`。
- 设置模块已有 `SettingsController` 和 `SettingsRepository` 抽象。

### 4.2 当前缺口

- `themeMode` 仍硬编码为 `ThemeMode.system`。
- `AppTheme.light()` / `AppTheme.dark()` 不能接收主题风格参数。
- `AppSettings` 没有主题字段。
- `SettingsRepository` 只有抽象，没有实际持久化实现。
- `SettingsController` 没有注入 `AppDependencies`。
- 设置页“主题”只是静态文案，没有交互。
- 需要扫描并收敛硬编码颜色，避免主题切换后局部 UI 不跟随。

---

## 5. 技术方案

### 5.1 新增主题预设模型

建议新增：

```text
lib/app/theme_preset.dart
```

定义：

```dart
enum EvolyThemePreset {
  orbitBlue,
  forestGreen,
  sunriseCoral,
  graphiteFocus,
}
```

每个 preset 提供：

```text
id
label
description
seedColor
secondarySeedColor
tertiarySeedColor
previewSwatches
```

第一版可以继续使用 `ColorScheme.fromSeed`，但预留 secondary / tertiary 的扩展点。后续如果 Material 3 seed 推导不够稳定，再切换到手写 `ColorScheme`。

### 5.2 改造 AppTheme

当前：

```dart
AppTheme.light()
AppTheme.dark()
```

目标：

```dart
AppTheme.light(EvolyThemePreset preset)
AppTheme.dark(EvolyThemePreset preset)
```

内部仍然复用 `_base(colorScheme)`，保证字体、卡片、输入框、导航栏等组件样式不重复。

### 5.3 扩展 AppSettings

当前：

```dart
class AppSettings {
  final bool dailyReportEnabled;
  final int defaultReminderHour;
  final int defaultReminderMinute;
}
```

目标：

```dart
class AppSettings {
  final bool dailyReportEnabled;
  final int defaultReminderHour;
  final int defaultReminderMinute;
  final ThemeMode themeMode;
  final EvolyThemePreset themePreset;
}
```

需要提供：

- 默认值：`ThemeMode.system`
- 默认 preset：`EvolyThemePreset.orbitBlue`
- `copyWith`
- 字符串编码和解析方法，避免持久化时直接依赖 enum index

### 5.4 设置持久化

当前 `SettingsRepository` 只有接口，需要补一个可用实现。

推荐优先做 SQLite / key-value 式本地设置：

```text
settings
  key TEXT PRIMARY KEY
  value TEXT NOT NULL
```

也可以先用现有 `StorageService` 抽象，但当前只有 `InMemoryStorageService`，无法跨启动保存。为了真实可用，推荐落到 SQLite。

### 5.5 全局注入和启动加载

`AppDependencies` 需要提供：

```text
SettingsRepository
SettingsController
```

`EvolyApp` 需要监听 `SettingsController`：

```dart
final settings = context.watch<SettingsController>().settings;

MaterialApp(
  theme: AppTheme.light(settings.themePreset),
  darkTheme: AppTheme.dark(settings.themePreset),
  themeMode: settings.themeMode,
)
```

启动时要保证：

- 设置能尽早加载。
- 未加载完成时使用默认主题。
- 加载完成后平滑刷新，不阻塞 App 首屏。

---

## 6. 设置页交互设计

### 6.1 入口

设置页中的主题项改为真实入口：

```text
主题
跟随系统 · 默认蓝
```

点击打开底部弹层。

### 6.2 底部弹层结构

底部弹层建议分两块：

```text
主题模式
[跟随系统] [浅色] [深色]

主题风格
默认蓝    色板预览
森林绿    色板预览
日出暖橙  色板预览
墨灰专注  色板预览
```

交互原则：

- 模式用 segmented control。
- 风格用色板列表或紧凑网格。
- 选中项有轻微凸起、描边和勾选图标。
- 选择后立即应用，不需要额外保存按钮。
- 不在弹层里放大段说明文字，避免设置页变成说明书。

### 6.3 色板预览

每个主题显示 3 个小色块：

```text
primary / secondary / tertiary
```

再加一个极小背景块表示 surface。用户不需要读说明，也能快速识别主题气质。

---

## 7. 页面适配原则

主题系统落地后，需要重点检查以下页面：

| 页面 | 检查点 |
| --- | --- |
| 今日页 | Coach、Top 3、任务卡、完成反馈颜色 |
| 目标列表 | 优先级点、目标状态、筛选 chip、编辑弹层 |
| 目标详情 | 文档区、任务行、进度条 |
| 文档库 | 文件夹、文档类型、Markdown 编辑页 |
| 统计页 | 图表色、卡片背景、数值强调 |
| 设置页 | 主题选择器自身在不同主题下可读 |

重点规则：

- 不用硬编码背景色。
- 错误、警告、完成、优先级等语义色保持稳定。
- 深色主题下边框和阴影要降低突兀感。
- 浅色主题下高饱和色不要大面积铺开。

---

## 8. 实施步骤

### 阶段 1：主题模型

- 新增 `EvolyThemePreset`。
- 为 4 套主题定义 label、seed、preview swatches。
- 改造 `AppTheme.light/dark` 接收 preset。
- 保持现有默认蓝视觉尽量不变。

### 阶段 2：设置状态

- 扩展 `AppSettings`。
- 增加 `themeMode` 和 `themePreset` 默认值。
- 增加 `copyWith`。
- 实现 enum 与 string 的稳定转换。

### 阶段 3：持久化

- 实现 `SettingsRepository` 的 SQLite 版本。
- 增加 settings key-value 表或复用可扩展配置表。
- App 启动时加载设置。
- 设置变化时立即保存。

### 阶段 4：全局接入

- 在 `AppDependencies` 注入 `SettingsRepository` 和 `SettingsController`。
- `EvolyApp` 监听设置并生成对应 `theme/darkTheme/themeMode`。
- 保证系统状态栏和导航栏颜色继续跟随 `colorScheme.surface`。

### 阶段 5：设置页 UI

- 替换静态主题 `ListTile`。
- 新增主题选择 bottom sheet。
- 增加模式 segmented control。
- 增加主题风格色板选择。
- 选择后即时应用并保存。

### 阶段 6：页面巡检

- 扫描 `Colors.` 和 `Color(0x...)`。
- 只保留必要品牌色、语义色或图标资产色。
- 重点检查 Android 真机浅色/深色下的状态栏、导航栏、输入框、bottom sheet。

---

## 9. 验证清单

### 9.1 功能验证

- 默认启动仍为跟随系统 + 默认蓝。
- 设置页能显示当前主题。
- 切换主题风格后 App 立即刷新。
- 切换浅色/深色/跟随系统后 App 立即刷新。
- 重启 App 后保留主题选择。
- 深色系统下跟随系统能进入深色。
- 浅色系统下跟随系统能进入浅色。

### 9.2 视觉验证

- 4 套主题下今日页可读。
- 4 套主题下目标列表可读。
- 4 套主题下目标编辑弹层不刺眼。
- 4 套主题下任务优先级颜色仍能区分。
- 深色主题下卡片边框不过亮。
- 浅色主题下主色不过度占据屏幕。

### 9.3 技术验证

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

Android 真机建议额外验证：

```powershell
flutter run -d <device-id>
```

重点观察：

- 状态栏图标颜色。
- 系统导航栏颜色。
- BottomSheet 与键盘同时出现时是否仍然稳定。
- 主题切换时是否出现明显闪屏。

---

## 10. 风险与处理

### 10.1 风险：主题切换后局部 UI 不跟随

原因通常是硬编码颜色。

处理：

- 扫描 `Colors.`、`Color(0x...)`。
- 优先改为 `Theme.of(context).colorScheme`。
- 对确实需要固定的语义色集中封装。

### 10.2 风险：主题过多导致维护成本上升

处理：

- 第一版只做 4 套。
- 每套主题必须过完整页面巡检。
- 后续新增主题要复用同一套 preset 结构。

### 10.3 风险：设置加载导致首屏闪动

处理：

- 默认主题与持久化默认值保持一致。
- 启动时先显示默认主题。
- 设置加载完成后只在用户确实选择了非默认主题时刷新。

### 10.4 风险：深色主题下阴影不可见或边框刺眼

处理：

- 深色模式减少阴影依赖。
- 增加 outline / surfaceContainer 的层级差。
- 对 bottom sheet、悬浮选项、chip 单独检查。

---

## 11. 推荐验收标准

主题系统完成后，应满足：

```text
用户可以在设置页选择主题模式和主题风格
选择立即生效
重启后选择不丢失
主要页面在 4 套主题、浅色/深色下都可读
没有明显硬编码颜色破坏主题一致性
Android 状态栏和导航栏跟随主题
```

第一版不需要追求主题商店、用户自定义色、动态取色或云同步主题设置。先把本地主题体验做扎实。
