# Evoly Windows 双形态与 HUD UI 实现记录

更新日期：2026-07-05

## Summary

Windows 端已经从“移动端放大窗口”推进到双形态桌面体验：

- 完整模式：用于今日计划、目标、文档、统计和设置等完整编辑工作。
- HUD 迷你面板：常驻右上角，用于下一条提醒、高优先级任务和快速处理。
- 托盘模式：后台待命，保留提醒能力，并提供打开完整模式、显示迷你面板、暂停提醒和退出入口。

当前 UI 方向已调整为 Evoly HUD 玻璃语言。Windows 端使用 Acrylic/透明窗口能力和 Flutter glass surface 绘制；Android/mobile 使用同一套 HUD 主题 token，但不做系统级窗口透明。

## 已实现能力

- Windows 窗口控制：
  - 完整/迷你/隐藏模式切换。
  - 托盘图标与右键菜单。
  - 关闭行为可配置：隐藏到托盘、切到迷你面板、退出应用。
  - 托盘点击行为可配置：显示迷你面板、打开完整模式。
  - 迷你面板置顶开关、拖动位置保存、位置重置。
  - 完整工作台恢复普通桌面应用逻辑，不再强制置顶；迷你面板继续按设置置顶。
  - 迷你面板使用透明原生背景并关闭系统阴影，避免白边、黑底和脏背板。
  - 快速连续切换使用 revision 防抖，避免旧异步窗口操作覆盖新状态。

- 双形态切换动画：
  - full/compact 切换不再动画 Flutter 内容层，不使用会压扁界面的 stage 级 `Opacity`、`Transform` 或形变过渡。
  - 切换改为 Windows 原生窗口透明度时间线：80ms 淡出、在完全透明时应用窗口尺寸/背景/effect/mode、等待一帧布局后 120ms 淡入。
  - compact 展开/收起仍是固定窗口尺寸与内容稳定过渡，不触发整窗淡入淡出。
  - 若 opacity 能力在系统组合下失败，会回退为可见的即时切换，避免窗口永久停在透明状态。

- HUD 迷你面板：
  - 折叠态 `360 x 184`，展开态 `360 x 360`。
  - 显示下一条提醒、未完成数、已到时数和高优先级 Top 3。
  - 支持 hover 后显示刷新、打开完整模式、隐藏窗口等次级操作。
  - 支持任务行 hover 后完成/延后。
  - 支持点击任务回到完整模式并打开对应任务编辑面板。
  - 外层边框已移除；hover/拖动时背景更实，鼠标离开约 3.5 秒后回到更轻的透明状态。
  - 避免 `Tooltip`、`IconButton.tooltip`、`InkWell` 等曾触发 Overlay/referenceBox 问题的交互组件。

- 完整模式闭环：
  - `DesktopWindowController.enterFullMode(taskId:)` 可以携带待打开任务。
  - `MainShellPage` 收到待打开任务后切回今日页。
  - `TodayPage` 在任务加载完成后只消费一次 pending task id，并打开任务编辑面板。
  - 任务不存在时显示轻量提示并清掉 pending id。

- HUD 主题系统：
  - 保留旧主题 preset id，避免设置迁移。
  - 当前四套主题：星轨蓝、极光绿、暮光橙、石墨 HUD。
  - `EvolyDesignTokens` 新增 `backgroundGradient`、`glassSurface*`、`glassBorder*`、`glassHighlight`、`hudAccent*`、`metricAccent` 和 `glassBlurSigma`。
  - 新增 `AppGlassSurface`，通用卡片、列表卡、指标卡、pill、导航栏逐步统一到玻璃材质。
  - Windows full app 的临时 glass override 已收回到全局 token 体系。
  - 迷你面板 `_CompactGlassSkin` 已改为从全局 token 派生。

- 文档库与 UI 质感：
  - 文档库呈现已从散乱文件列表改为更清晰的目标档案夹结构。
  - 设置页主题预览已从色块升级为 HUD 样张。
  - Win 端标题栏、左侧导航栏和正文卡片已统一到 HUD glass 风格。
  - 继续删除或替换鼓励式提示词，保留状态与动作文案。

## 关键代码结构

```text
lib/features/desktop_window/
  domain/
    desktop_window_mode.dart
    compact_reminder_snapshot.dart
  application/
    desktop_window_host.dart
    desktop_window_controller.dart
    compact_reminder_service.dart
  presentation/
    compact_reminder_panel.dart
```

核心职责：

- `DesktopWindowHost`：封装 `window_manager`、`tray_manager`、`screen_retriever`、`flutter_acrylic` 的平台调用，便于测试 fake。
- `DesktopWindowController`：管理完整/迷你/隐藏模式、窗口尺寸位置、置顶、托盘行为和 pending task id。
- `CompactReminderService`：从任务与提醒仓库生成迷你面板快照。
- `CompactReminderPanel`：纯 UI 层，负责 HUD 面板渲染、hover 操作、拖动反馈和快捷操作。
- `EvolyDesignTokens` + `AppGlassSurface`：全局 HUD 主题与玻璃组件底座。

## 验证状态

最近一次已通过：

```powershell
flutter analyze
flutter test
flutter build windows
```

已知非阻塞提示：

- `flutter test` 中 sqflite default factory warning，属于测试环境已知提示。
- 依赖解析会提示部分包有更新版本或已停止维护，和本次改动无关。

## 手动验收清单

- 完整模式 -> 迷你模式 -> 展开 -> 收起 -> 打开完整模式，无异常和 overflow。
- 迷你面板点击下一条提醒或高优先级任务，回到完整模式并打开对应任务编辑面板。
- 完成/延后迷你面板任务后，面板和今日页数据刷新一致。
- 拖动迷你面板后隐藏/恢复/展开/收起，位置不丢。
- 重置迷你面板位置后，下次显示回到主屏右上角。
- 关闭窗口按设置进入托盘、迷你面板或退出。
- 托盘左键按设置显示迷你面板或打开完整模式。
- 托盘右键菜单可打开完整模式、显示迷你面板、暂停提醒和退出。
- 浅色/深色以及四套 HUD 主题下，完整模式和迷你面板文字可读。
- Windows 透明窗口四角无白底/黑底，完整模式和迷你模式来回切换后背景恢复正常。
- Android 端主题切换后不出现系统级透明副作用。

## 下一步

- 对 Today、Goals、Documents、Settings 中仍有硬编码色值的局部组件继续 token 化。
- 对 Windows full app 做一次真实截图巡检，重点看标题栏、左侧导航和正文卡片的统一感。
- 对迷你面板补充更多视觉回归测试：长标题、空状态、错误状态、暂停提醒状态。
- 等当前 HUD 语言稳定后，再评估开机自启、真实系统级 Acrylic 增强和多显示器吸附策略。
