# Evoly Android 构建与真机调试记录

> 记录 Evoly（`com.evoly.app`，包名 `evoly`，v0.2.0）在 Windows + PowerShell 环境下完成 Android
> 真机构建、缓存迁移、无线调试、运行时 Bug 修复的全过程。供后续构建/排错参考。

---

## 1. 环境与工具路径

| 项目 | 值 |
|------|----|
| 操作系统 | Windows + PowerShell |
| 项目目录 | `D:\time_table` |
| Flutter SDK | `D:\dev\flutter` |
| Android SDK | `D:\dev\android-sdk` |
| adb | `D:\dev\android-sdk\platform-tools\adb.exe`（v37.0.0） |
| NDK | 28.2.13676358（AGP 自动管理） |
| CMake | 3.22.1 |
| 构建链 | Gradle 9.1.0 / AGP 9.0.1 / Kotlin 2.3.20 |

### 缓存目录（已迁至 D 盘，关键）

| 环境变量 | 路径 |
|----------|------|
| `PUB_CACHE` | `D:\dev\pub-cache` |
| `GRADLE_USER_HOME` | `D:\dev\gradle` |

已通过 `[Environment]::SetEnvironmentVariable(..., 'User')` 设为用户级。

---

## 2. 关键陷阱：跨盘符 Kotlin 编译崩溃 ⚠️

**现象**：项目在 D 盘，但 Pub/Gradle 缓存默认在 C 盘，Kotlin 增量编译器
`RelocatableFileToPathConverter` 计算跨盘相对路径时抛异常：

```
IllegalArgumentException: this and base files have different roots:
C:\...\Pub\Cache\...\flutter_timezone\...\FlutterTimezonePlugin.kt
and D:\time_table\android
```

**触发**：任何含 Kotlin 源码的插件（如 `flutter_timezone`）。

**根因**：Kotlin 无法在不同盘符之间计算相对路径。

**根本修复**：**缓存必须与项目同盘**。将 `PUB_CACHE`、`GRADLE_USER_HOME` 迁到 D 盘即可彻底解决。

> ❗ 用户级环境变量**不会**传播到已打开的终端。每个新构建会话需先在终端内联设置：
> ```powershell
> $env:PUB_CACHE='D:\dev\pub-cache'; $env:GRADLE_USER_HOME='D:\dev\gradle'
> ```
> 否则又会下载到 C 盘并重新触发跨盘错误。重启 VS Code 可让用户级变量全局生效。

---

## 3. 缓存迁移操作

- 使用 `robocopy /MOVE /MT:32` 多线程迁移（小文件多，单线程极慢）。
- 迁移量：Pub Cache 约 569MB、Gradle Cache 约 2763MB。
- 迁移后手动清理 C 盘残留目录，确认 `C:\Users\...\.gradle` 与旧 Pub Cache 清空。
- 改缓存位置后先 `flutter clean` 清理旧 `build/`。

---

## 4. 镜像源配置（已完成）

| 用途 | 镜像 | 配置位置 |
|------|------|----------|
| Gradle 发行版 | 腾讯云 | `android/gradle/wrapper/gradle-wrapper.properties` |
| Maven 依赖 | 阿里云（google / public / gradle-plugin） | `android/settings.gradle.kts` + `android/build.gradle.kts` |

阿里云镜像放在 `google()` / `mavenCentral()` / `gradlePluginPortal()` **之前**。

---

## 5. 标准构建命令

```powershell
# 每个新终端会话先设缓存路径
$env:PUB_CACHE='D:\dev\pub-cache'; $env:GRADLE_USER_HOME='D:\dev\gradle'
cd D:\time_table

flutter clean          # 改缓存位置后先清理
flutter pub get
flutter build apk --debug
flutter run -d <deviceId>   # 真机运行
```

构建结果：`flutter build apk --debug` 成功（约 68.9s），产物
`build\app\outputs\flutter-apk\app-debug.apk`。

---

## 6. 真机调试经验

### 6.1 NDK 损坏
- 报错：`[CXX1101] NDK ... did not have a source.properties file`（目录只剩 `.installer`）。
- 修复：删除损坏的 NDK 目录，AGP 自动重新下载。

### 6.2 小米/HyperOS 安装受限
- 报错：`INSTALL_FAILED_USER_RESTRICTED`。
- 修复：开发者选项打开「USB 安装」权限。

### 6.3 设备反复 offline → 改用无线调试 ✅
- USB 反复 `offline` = 物理连接问题（线/口），软件重连无效（adb 已是最新 v37.0.0）。
- 解决：**无线调试**绕开不稳定 USB：
  1. 手机：开发者选项 → 无线调试 → 配对。
  2. 电脑：`adb connect 192.168.31.14:37575`。
- 成功机型：Xiaomi 17（型号 25113PN0EC，Android 16，渲染 Impeller/Vulkan）。

```powershell
$adb='D:\dev\android-sdk\platform-tools\adb.exe'
& $adb connect 192.168.31.14:37575
& $adb devices -l
```

### 6.4 最新无线调试连接记录

2026-06-28 再次使用无线调试连接成功：

```powershell
$adb='D:\dev\android-sdk\platform-tools\adb.exe'
& $adb connect 192.168.31.14:42463
& $adb devices -l
flutter devices
```

验证结果：

- adb 状态：`already connected to 192.168.31.14:42463`
- 设备：`192.168.31.14:42463`
- 型号：`25113PN0EC`
- Android：`Android 16 (API 36)`
- 架构：`android-arm64`

Flutter 识别为：

```text
25113PN0EC (mobile) • 192.168.31.14:42463 • android-arm64 • Android 16 (API 36)
```

### 6.5 日志辨别
- 用 PID 区分自家应用日志：`com.evoly.app` 为 PID 22637；其它 PID（小米天气小组件、微信小程序等）为系统噪声。
- `sqflite` 警告、`Lost connection to device`（无线掉线/切后台）均属正常。

---

## 7. 已修复运行时 Bug

**文件**：`lib/features/goals/presentation/goal_list_page.dart`

**现象**：新建目标 BottomSheet 在 `await` 后立即 `dispose` 控制器，键盘 inset 动画在弹窗关闭时
重建 TextField，报：
```
TextEditingController was used after being disposed
RenderFlex overflowed by 99746 pixels
```

**修复**：
- 抽出独立的 `_CreateGoalSheet extends StatefulWidget`，自管理
  `_titleController` / `_taskController`，在自身 `dispose()` 中释放。
- 内容包 `SingleChildScrollView` 防键盘溢出，加 `_submitting` 标志防重复提交。
- `_showCreateGoalSheet()` 改为 `showModalBottomSheet<bool>`，提交成功回传 `true` 后再 `_loadGoals()`。

**验证**：真机重跑 `flutter run`，应用正常启动，无上述异常。

### 7.2 新建目标 BottomSheet 真机卡顿优化

**文件**：`lib/features/goals/presentation/goal_list_page.dart`

**现象**：Android 真机点击“新增目标”时，BottomSheet 弹出过程刷新率偏低，观感类似卡顿。

**原因判断**：
- BottomSheet 入场动画和 `TextField.autofocus` 触发的键盘弹出动画同时发生。
- 键盘 `viewInsets` 在动画过程中连续变化，直接参与布局，导致弹窗内容频繁重排。

**优化**：
- 移除 `TextField.autofocus`，改为 `FocusNode` 延后到 BottomSheet 入场动画后再请求焦点。
- 使用 `AnimatedPadding` 平滑响应键盘高度变化。
- 给弹窗内容加 `SafeArea(top: false)`，减少底部导航/安全区干扰。
- 给表单内容加 `RepaintBoundary`，降低父级动画导致的重绘影响。
- `SingleChildScrollView` 增加 `keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag`，移动端拖动时可收起键盘。

**验证**：
- `flutter analyze` 通过。
- `flutter test` 通过。
- `flutter build apk --debug` 通过。

### 7.3 Android 状态栏不可见修复

**文件**：
- `lib/main.dart`
- `lib/app/app.dart`
- `android/app/src/main/res/values/styles.xml`
- `android/app/src/main/res/values-night/styles.xml`

**现象**：Android 真机打开 App 后看不到系统状态栏，观感像进入了全屏或状态栏图标与背景混在一起。

**原因判断**：
- App 没有主动声明 Flutter 运行期的系统 UI overlay。
- Android 透明状态栏/厂商系统主题下，状态栏图标颜色可能与背景不匹配。

**修复**：
- 启动时调用 `SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values)`，强制显示顶部状态栏和底部导航栏。
- 在 `MaterialApp.builder` 中用 `AnnotatedRegion<SystemUiOverlayStyle>` 按亮/暗主题设置状态栏和导航栏图标颜色。
- Android light/night 启动主题显式设置 `windowFullscreen=false`、状态栏透明、导航栏颜色、light status/navigation bar 标志。

**验证**：
- `flutter analyze` 通过。
- `flutter test` 通过。
- `flutter build apk --debug` 通过。

---

## 8. 待手动验证（通知 / 后台逻辑）

Phase 5 后台任务（`AndroidBackgroundTaskService` 基于 AlarmManager + `zonedSchedule`，启动时
`resyncReminders`）代码已完成，需在手机上手动验证：

1. **即时通知**：新建目标/任务，触发提醒，确认通知出现。
2. **定时通知**：设 1–2 分钟后提醒，锁屏，确认按时弹出。
3. **后台存活**：从最近任务杀掉应用，等待定时提醒，确认仍触发（验证 AlarmManager）。
4. **重启重注册**：重启手机，确认提醒仍触发（验证 `RECEIVE_BOOT_COMPLETED`）。

> 小米/HyperOS 需手动授予：通知权限、「自启动」权限、关闭电池优化，后台通知才可靠。

### 8.1 注入后台通知测试数据

如果需要快速构造提醒场景，可使用脚本直接向当前真机 App 沙盒 SQLite 注入测试目标、任务和提醒：

```powershell
python scripts\inject_android_notification_demo.py --device 192.168.31.14:42463
```

脚本行为：

- 先 `force-stop com.evoly.app`，避免数据库写入时锁库。
- 从真机 `databases/evoly.db` 拉取数据库到本地临时目录。
- 删除并重建 `android-notify-demo-` 前缀的测试目标、任务和提醒。
- 推回 App 沙盒数据库。

注入内容：

- 目标：`Android 通知测试：后台提醒验证`
- 任务 1：`通知测试：2 分钟后弹出`
- 任务 2：`通知测试：5 分钟后台提醒`
- 任务 3：`通知测试：8 分钟杀掉应用`

测试步骤：

1. 运行注入脚本。
2. 重新打开 Evoly，让 `AppLifecycleCoordinator.bootstrap()` 执行并触发 `resyncReminders`。
3. 等待 2 分钟，验证前台或锁屏通知。
4. 切后台或锁屏，等待 5 分钟，验证后台通知。
5. 从最近任务杀掉 Evoly，等待 8 分钟，验证系统调度通知。

注意：

- 如果注入后等待太久才打开 App，2 分钟提醒可能已经过期；重新运行脚本即可刷新提醒时间。
- 小米/HyperOS 上需要通知权限、自启动权限、关闭电池优化，否则杀掉应用后的提醒可能被系统拦截。

---

### 8.2 通知测试疑似崩溃排查与修复

**现象**：真机通知测试时，点击高优先级的 `2 分钟后弹出` 通知/任务后，用户观察到 App 像是崩溃或退到后台。

**日志结论**：
- `adb shell pidof com.evoly.app` 仍能查到 Evoly 进程，说明当时 App 进程仍存活。
- `logcat -b crash` 未发现 `com.evoly.app` 的 `FATAL EXCEPTION`，只有系统/其他应用噪声。
- 更可能是通知点击/系统回前台行为不明确，或 Flutter 调试连接/前后台切换造成“像崩溃”的观感。

**加固修复**：
- Android 通知 ID 从 `String.hashCode` 改为稳定 FNV-1a 映射，避免重启后取消/重排通知 ID 不一致。
- 为 `flutter_local_notifications.initialize()` 增加通知点击回调，点击通知时只打印 payload，不直接改数据库或操作页面栈。
- 定时通知优先使用 `exactAllowWhileIdle`，若厂商系统/权限导致 `PlatformException`，自动降级到 `inexactAllowWhileIdle`，避免启动或重排提醒被异常打断。
- 增加 `stableAndroidNotificationId` 单元测试，锁定稳定 ID 行为。

**验证**：
- `flutter analyze` 通过。
- `flutter test` 通过。
- `flutter build apk --debug` 通过。
- 已安装到真机 `192.168.31.14:42463`，启动后 `pidof com.evoly.app` 正常返回进程号，未发现新的 Evoly FATAL。

**复测建议**：
1. 重新运行：
   ```powershell
   python scripts\inject_android_notification_demo.py --device 192.168.31.14:42463
   ```
2. 打开 Evoly，等待 2 分钟通知。
3. 点击通知后立即抓日志：
   ```powershell
   D:\dev\android-sdk\platform-tools\adb.exe -s 192.168.31.14:42463 logcat -d -v time -t 800 | Select-String -Pattern 'Evoly notification|com\.evoly|FATAL EXCEPTION|AndroidRuntime|PlatformException'
   ```

---

## 9. 可选优化（非 Bug）

日志提示 `OnBackInvokedCallback is not enabled`（Android 13+ 预测式返回手势）。如需适配，在
`android/app/src/main/AndroidManifest.xml` 的 `<application>` 加：
```xml
android:enableOnBackInvokedCallback="true"
```
