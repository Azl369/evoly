# Evoly Android 开发日志

> Android 端当前已经从“迁移验证”进入“主力开发与真机体验打磨”阶段。由于 Android 端在通知、真机交互、移动端表单体验上已经超过 Windows 端进度，后续 Android 相关进展单独记录在本文档中。

---

## 2026-06-29：120Hz 真机弹层帧率观感优化

### 背景

用户反馈的重点不是“弹出速度慢”，而是 **动画不够流畅**：在 120Hz 手机上，新建目标/子任务时 BottomSheet 和键盘动画叠加，看起来像刷新率没有跟上屏幕。

这类问题更接近帧 pacing 和动画期布局压力，而不是单纯调短动画时长。

### 本次优化方向

1. **Android 原生侧请求高刷新率**
   - 文件：`android/app/src/main/kotlin/com/evoly/app/MainActivity.kt`
   - 启动时读取设备支持的 display modes。
   - 设置 `preferredDisplayModeId` 为 refresh rate 最高的模式。
   - 目标是在支持 90Hz/120Hz 的设备上，让当前 Activity 更倾向使用高刷新显示模式。

2. **减少键盘动画期间 Flutter 二次动画**
   - 新增共享组件：`lib/shared/ui/bottom_sheets/responsive_bottom_sheet_body.dart`
   - 移除表单弹层内部的 `AnimatedPadding`。
   - 改为直接跟随系统 `viewInsets.bottom` 布局。
   - 避免 Android IME 动画和 Flutter `AnimatedPadding` 同时插值，减少“互相追赶”的不稳定观感。

3. **统一弹层布局容器**
   - 新建目标、新建子任务、编辑目标、编辑任务统一使用 `ResponsiveBottomSheetBody`。
   - 统一处理：
     - `SafeArea(top: false)`
     - 键盘 bottom inset
     - 最大高度约束
     - `SingleChildScrollView`
     - `RepaintBoundary`

### 涉及文件

- `android/app/src/main/kotlin/com/evoly/app/MainActivity.kt`
- `lib/shared/ui/bottom_sheets/responsive_bottom_sheet_body.dart`
- `lib/features/tasks/presentation/widgets/task_create_sheet.dart`
- `lib/features/tasks/presentation/widgets/task_edit_sheet.dart`
- `lib/features/goals/presentation/widgets/goal_edit_sheet.dart`
- `lib/features/goals/presentation/goal_list_page.dart`

### 预期体验

- 120Hz 手机上 Activity 更有机会运行在高刷新显示模式。
- 键盘弹出时不再由 Flutter 再额外做一层 padding 动画。
- BottomSheet 和 IME 动画叠加时，掉帧/抖动感应减少。
- 新建目标、新建子任务、编辑目标、编辑任务的弹层行为更一致。

### 待真机复测

重点复测：

1. 目标页右上角「+」新建目标。
2. 目标详情页「新增」新建子任务。
3. 目标详情页编辑目标。
4. 今日页/目标详情页编辑任务。

观察项：

- 弹层入场是否更稳定。
- 键盘出现时是否还有明显掉帧。
- 120Hz 屏幕上是否还像 60Hz 或更低帧率。
- 如果仍不够顺，下一步考虑自定义 BottomSheet transition，完全减少 Material 默认 sheet 动画与 IME 的叠加。

---

## 2026-06-29：表单弹层与键盘动画优化

### 背景

目标页、目标详情页中的新建目标、新建子任务、编辑目标、编辑子任务都会使用 BottomSheet 表单。Android 真机上，BottomSheet 入场动画和软键盘弹出动画叠在一起时，会出现刷新率偏低、弹层像“顶着键盘慢慢挪”的观感。

参考 Microsoft To Do 这类移动端任务软件的手感，目标是：

- 弹层先快速、稳定地出现。
- 键盘不要和弹层入场动画抢同一段时间。
- 键盘出现时内容位移要短、快、明确。
- 不能再出现 controller 生命周期导致的红屏或底部 overflow。

### 本次优化

- 新增共享焦点工具：`lib/shared/ui/bottom_sheets/bottom_sheet_focus.dart`
  - 统一使用 `requestFocusAfterBottomSheetEntrance(...)`。
  - 表单弹层先完成入场，再延迟请求输入框焦点。
  - 避免 `TextField.autofocus` 和 BottomSheet 入场动画同时触发。
- 新建子任务弹层：
  - 文件：`lib/features/tasks/presentation/widgets/task_create_sheet.dart`
  - 改为自管理 `TextEditingController` 和 `FocusNode`。
  - 使用延迟聚焦，避免键盘和弹层同时抢动画。
- 编辑目标弹层：
  - 文件：`lib/features/goals/presentation/widgets/goal_edit_sheet.dart`
  - 抽成独立 StatefulWidget，自管理 controller、状态和焦点。
  - 目标详情页和目标列表页共用同一套编辑目标弹层。
- 键盘 inset 动画统一加快：
  - `TaskCreateSheet`
  - `TaskEditSheet`
  - `GoalEditSheet`
  - `_CreateGoalSheet`
  - 将响应键盘高度变化的 `AnimatedPadding` 调整为 `MotionTokens.instant` + `MotionTokens.standard`。

### 预期体验

- 点击“新增目标”或“新增子任务”后，BottomSheet 先轻快浮出。
- 短暂停顿后键盘弹出，不再和弹层入场硬叠。
- 键盘弹出时内容位移更快，减少拖泥带水的观感。
- 编辑目标/任务与新建目标/任务手感更一致。

### 已验证

```powershell
flutter analyze
flutter test
```

### 待真机复测

```powershell
$adb='D:\dev\android-sdk\platform-tools\adb.exe'
& $adb connect 192.168.31.14:<当前无线调试端口>
flutter run -d 192.168.31.14:<当前无线调试端口>
```

重点路径：

1. 目标页 → 右上角「+」→ 新建目标。
2. 目标详情页 → 「新增」→ 新建子任务。
3. 目标详情页 → 编辑目标。
4. 今日页/目标详情页 → 编辑任务。

观察项：

- 弹层是否先出现，键盘是否稍后弹出。
- 键盘弹出时是否还有明显卡顿。
- 是否还有 `TextEditingController was used after being disposed`。
- 是否还有 `BOTTOM OVERFLOW` 或 `_dependents.isEmpty`。

---

## 当前 Android 端阶段判断

Android 端已完成：

- Android 工程生成与基础构建。
- 真机无线调试链路。
- SQLite 移动端运行。
- Android 系统状态栏显示修复。
- Android 本地通知基础能力。
- 后台通知测试数据注入脚本。
- 目标/任务主要页面在手机竖屏上的基础可用性。
- 表单弹层 controller 生命周期修复。
- 表单弹层与键盘动画第一轮体验优化。

Android 端下一阶段建议：

1. **真机体验打磨**
   - 表单弹层动画继续微调。
   - 列表滚动、卡片点击、页面切换帧率观察。
   - 大字号/小屏幕兼容。
2. **通知稳定性验收**
   - 前台通知。
   - 后台通知。
   - 锁屏通知。
   - 杀掉应用后的定时通知。
   - 小米/HyperOS 权限引导。
3. **移动端产品形态补齐**
   - 通知点击后的落点页面。
   - 今日任务快捷操作。
   - 目标详情页移动端布局压缩。
4. **Android 发布准备**
   - Release 签名。
   - APK/AAB 打包。
   - 图标、启动页、应用名。
   - 权限说明文案。

---

## 常用调试命令

```powershell
$env:PUB_CACHE='D:\dev\pub-cache'
$env:GRADLE_USER_HOME='D:\dev\gradle'
$adb='D:\dev\android-sdk\platform-tools\adb.exe'

& $adb connect 192.168.31.14:<当前无线调试端口>
& $adb devices -l
flutter devices
flutter run -d 192.168.31.14:<当前无线调试端口>
```

抓取关键日志：

```powershell
$adb='D:\dev\android-sdk\platform-tools\adb.exe'
& $adb -s 192.168.31.14:<当前无线调试端口> logcat -d -v time -t 1200 |
  Select-String -Pattern 'com\.evoly|Flutter|FATAL EXCEPTION|AndroidRuntime|TextEditingController|BOTTOM OVERFLOW|Failed assertion|PlatformException'
```
