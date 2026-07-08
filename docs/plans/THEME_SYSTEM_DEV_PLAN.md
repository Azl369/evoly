# Evoly HUD 主题系统实现记录

更新日期：2026-07-05

## Summary

Evoly 的主题系统已经从第一版 Material seed 主题，升级为全局 HUD 设计语言：

- 保留 Material 3 作为组件基础。
- 保留 `ThemeMode.system/light/dark`。
- 保留旧主题 preset id，避免设置迁移。
- 将视觉重点从普通实底卡片改为 HUD 渐变背景、半透明 glass surface、细边框、高光、轻阴影和清晰状态色。
- Windows full app、Windows HUD 迷你面板、Android/mobile 主界面共用同一套设计 token。

这不是主题商店，也不是自由换肤。目标是让 Evoly 在桌面和移动端都保持克制、清晰、轻量，同时让 Windows 端具备更接近桌面小组件/HUD 的质感。

## 当前主题预设

持久化 id 不变，显示名称和色彩已更新：

| id | 显示名 | 主色 | 辅色 | 第三色 |
| --- | --- | --- | --- | --- |
| `orbitBlue` | 星轨蓝 | `#6EA8FF` | `#28D8C0` | `#9C7CFF` |
| `forestGreen` | 极光绿 | `#37C98B` | `#66D9E8` | `#E5B454` |
| `sunriseCoral` | 暮光橙 | `#FF8A5B` | `#35C2A6` | `#7DA8FF` |
| `graphiteFocus` | 石墨 HUD | `#8AA0B8` | `#5EEAD4` | `#C084FC` |

兼容原则：

- `settings.theme_preset` 仍保存旧 id。
- 未知 id 仍回退到 `orbitBlue`。
- 不做数据库迁移。
- 设置页显示新名称和 HUD 样张预览。

## Token 模型

`EvolyDesignTokens` 保留旧字段以兼容已有组件，并新增 HUD 语义字段：

```text
backgroundGradient
glassSurface
glassSurfaceSubtle
glassSurfaceRaised
glassBorder
glassBorderStrong
glassHighlight
glassShadow
hudAccent
hudAccentStrong
metricAccent
glassBlurSigma
```

旧字段映射策略：

- `pageBackground`：作为 HUD 背景底色。
- `surface`：映射到基础 glass surface。
- `surfaceSubtle`：映射到弱 glass surface。
- `surfaceRaised`：映射到强调 glass surface。
- `outlineSubtle`：继续作为弱边线兼容字段。
- `shadowSoft`：映射到 glass shadow。

这样旧页面不会立即失效，新组件则优先使用 HUD token。

## 组件落地

已新增 `AppGlassSurface`：

- 统一承载半透明面、边框、高光、hover、selected 和轻阴影。
- `AppSurfaceCard` 已委托到 `AppGlassSurface`。
- `AppListCard`、`AppMetricCard`、`AppMetaPill` 已开始使用 HUD surface。
- `EvolyNavigationRail` 已改为 glass sidebar。
- `SettingsPage` 主题选项已改为 HUD 样张预览。
- Windows full app 的临时 `_fullGlassTokens/_fullGlassTheme` 已移除，改用全局 token。
- `CompactReminderPanel` 的私有 `_CompactGlassSkin` 已从全局 token 派生。

## 平台策略

Windows：

- 完整模式保留 Acrylic/BackdropFilter 的模糊感，但内容不做全透明。
- 标题栏、侧边栏、正文卡片使用同一套 HUD glass token。
- 迷你面板保持透明 native stage + Flutter glass panel，避免白边、黑底和脏背板。
- 可置顶显示在别的应用之上。

Android/mobile：

- 使用同一套 HUD 色彩、渐变和 glass surface 语义。
- 不使用系统级窗口透明或 Acrylic。
- 保持可读性和性能优先。

## 文案原则

主题和 HUD 改造不引入情绪化提示词。保留：

- 状态：下一条提醒、未完成、已到时、高优先级。
- 动作：完成、延后、打开、隐藏、重置位置。
- 必要错误反馈：加载失败、任务不存在、同步失败。

避免：

- 鼓励式口号。
- 人格化提醒。
- “保持前进”“别让目标躺平”这类会增加噪音的句子。

## 验证状态

最近一次已通过：

```powershell
flutter analyze
flutter test
flutter build windows
flutter build apk --debug
```

已补充测试：

- 旧 preset id 兼容。
- HUD token light/dark 可用。
- `EvolyDesignTokens.copyWith/lerp` 覆盖新增字段。
- 迷你面板折叠/展开、hover、拖动反馈和收起 overflow 回归。

## 后续打磨

- 扫描页面中仍直接使用 `surfaceContainerHighest`、`Colors.*`、硬编码 `Color(0x...)` 的局部 UI。
- 将 Today、Goals、Documents、Settings 中的局部卡片继续收敛到 `AppGlassSurface`。
- 对深色主题做对比度巡检，避免边框过亮或文字发灰。
- 对浅色主题做干净度巡检，避免大面积脏灰和过度透明。
- 通过真实 Windows 截图验收标题栏、左侧栏、正文卡片、迷你面板是否统一。
