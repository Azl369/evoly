# Evoly Android 平台迁移计划

## 概述

Evoly 当前为 Windows Desktop 应用，基于 Flutter + SQLite + 本地通知。由于 Flutter 天生跨平台，核心业务逻辑（目标、任务、Coach、统计、复盘）无需修改，迁移工作集中在**平台服务层适配**和**构建配置**。

---

## 一、迁移范围评估

| 层级 | 迁移工作量 | 说明 |
|------|-----------|------|
| Presentation 表现层 | 低 | Flutter UI 天然跨平台，无需修改 |
| Application 应用层 | 无 | 纯 Dart 逻辑，平台无关 |
| Domain 领域层 | 无 | 纯 Dart 逻辑，平台无关 |
| Data 数据层 | 低 | SQLite 驱动需切换为移动端兼容方案 |
| Platform 平台服务层 | **中** | 通知、数据库路径、后台任务需要 Android 实现 |
| 构建配置 | 中 | 需生成 Android 工程目录并配置 |

---

## 二、详细步骤

### Phase 1：工程初始化（预计 1 天）

1. **生成 Android 工程目录**
   ```bash
   flutter create --platforms=android .
   ```
   这会在项目根目录生成 `android/` 文件夹，包含 Gradle、AndroidManifest、MainActivity 等。

2. **配置基本信息**
   - `android/app/build.gradle`：设置 `applicationId`（如 `com.evoly.app`）、`minSdkVersion`（建议 21+）、`targetSdkVersion`（34+）。
   - `android/app/src/main/AndroidManifest.xml`：配置应用名称、图标、权限。

3. **验证基础编译**
   ```bash
   flutter run -d android
   ```

---

### Phase 2：SQLite 适配（预计 0.5 天）

**当前问题**：项目使用 `sqflite_common_ffi`，这是桌面端方案。Android 原生支持 SQLite，应使用 `sqflite` 包。

**方案**：使用条件初始化，桌面端保持 FFI，移动端使用原生 sqflite。

1. **添加依赖**
   ```yaml
   dependencies:
     sqflite: ^2.3.0          # Android/iOS 原生 SQLite
     sqflite_common_ffi: ^2.4.2  # 保留，桌面端使用
   ```

2. **修改 `app_database.dart` 初始化逻辑**
   ```dart
   import 'dart:io';
   import 'package:sqflite_common_ffi/sqflite_ffi.dart';
   import 'package:sqflite/sqflite.dart' as sqflite_mobile;

   Future<Database> open() async {
     if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
       sqfliteFfiInit();
       databaseFactory = databaseFactoryFfi;
     }
     // Android/iOS 使用默认 databaseFactory，无需额外初始化
     
     final dbPath = await _databasePath();
     // ... 其余逻辑不变
   }
   ```

3. **修改 `_databasePath()` 支持 Android**
   ```dart
   Future<String> _databasePath() async {
     if (Platform.isAndroid || Platform.isIOS) {
       final dbDir = await sqflite_mobile.getDatabasesPath();
       return p.join(dbDir, 'evoly.db');
     }
     // Windows 保持现有 APPDATA 逻辑
     final appData = Platform.environment['APPDATA'];
     final baseDir = appData == null || appData.isEmpty
         ? p.join(Directory.current.path, '.evoly')
         : p.join(appData, 'Evoly');
     return p.join(baseDir, 'evoly.db');
   }
   ```

---

### Phase 3：通知服务适配（预计 1-2 天）

**当前问题**：`WindowsToastNotificationService` 通过 PowerShell 调用 Windows Toast API，Android 不可用。

**方案**：引入 `flutter_local_notifications` 插件，实现 `NotificationService` 接口的 Android 版本。

1. **添加依赖**
   ```yaml
   dependencies:
     flutter_local_notifications: ^17.0.0
   ```

2. **创建 Android 通知实现**

   新建 `lib/services/android_notification_service.dart`：
   ```dart
   class AndroidNotificationService implements NotificationService {
     FlutterLocalNotificationsPlugin? _plugin;

     @override
     Future<void> initialize() async {
       _plugin = FlutterLocalNotificationsPlugin();
       const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
       const settings = InitializationSettings(android: androidSettings);
       await _plugin!.initialize(settings);
     }

     @override
     Future<void> showNow({required String id, required String title, required String body}) async {
       await _plugin?.show(
         id.hashCode,
         title,
         body,
         const NotificationDetails(android: AndroidNotificationDetails(
           'evoly_reminders', 'Evoly 提醒',
           importance: Importance.high,
           priority: Priority.high,
         )),
       );
     }

     @override
     Future<void> schedule({...}) async {
       // 使用 zonedSchedule 实现定时通知
     }

     @override
     Future<void> cancel(String id) async {
       await _plugin?.cancel(id.hashCode);
     }
   }
   ```

3. **Android 权限配置**

   `android/app/src/main/AndroidManifest.xml` 添加：
   ```xml
   <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
   <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
   <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
   ```

4. **运行时权限请求**（Android 13+）
   ```dart
   if (Platform.isAndroid) {
     await _plugin!.resolvePlatformSpecificImplementation<
       AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
   }
   ```

---

### Phase 4：依赖注入平台适配（预计 0.5 天）

修改 `app_dependencies.dart`，根据平台注入对应的 Service 实现：

```dart
NotificationService _createNotificationService() {
  if (Platform.isWindows) {
    return const WindowsToastNotificationService();
  } else if (Platform.isAndroid) {
    return AndroidNotificationService();
  }
  return const NoopNotificationService();
}
```

---

### Phase 5：后台任务适配（预计 1 天）

**当前问题**：`BackgroundTaskService` 在 Windows 端为 Noop。Android 上如果需要应用关闭后仍能触发提醒，需要后台调度。

**方案**：使用 `android_alarm_manager_plus` 或 `workmanager` 插件。

1. **添加依赖**
   ```yaml
   dependencies:
     android_alarm_manager_plus: ^4.0.0
   ```

2. **实现 Android 后台任务服务**
   - 应用启动时注册 AlarmManager 定时检查到期提醒。
   - 设备重启后通过 `RECEIVE_BOOT_COMPLETED` 重新注册。

---

### Phase 6：UI/UX 移动端适配（预计 1-2 天）

虽然 Flutter UI 天然跨平台，但移动端有一些体验差异需处理：

1. **响应式布局**：确认页面在手机屏幕（竖屏、宽度 360-414dp）下布局正常。
2. **触控适配**：按钮点击区域 ≥ 48dp，列表项间距合理。
3. **返回键处理**：Android 物理/手势返回键需正确处理路由回退。
4. **状态栏/导航栏**：适配 Android 刘海屏、挖孔屏 SafeArea。
5. **键盘弹出**：表单输入时键盘不遮挡内容。
6. **应用图标**：提供各分辨率 Android 图标（mipmap-mdpi ~ xxxhdpi）。
7. **启动页**：配置 Android splash screen。

---

### Phase 7：测试与发布（预计 1-2 天）

1. **功能测试**
   - 目标创建 → 任务添加 → 今日查看 → 标记完成 → 反馈 闭环验证。
   - Coach 建议卡展示与操作。
   - 本地通知触发（即时 + 定时）。
   - 应用杀死后定时通知仍生效。

2. **设备兼容性**
   - 最低支持 Android 5.0 (API 21)。
   - 测试 Android 12+ 精确闹钟权限限制。
   - 测试 Android 13+ 通知权限运行时请求。

3. **发布准备**
   - 签名配置：生成 keystore，配置 `key.properties`。
   - ProGuard/R8 混淆规则。
   - 构建 Release APK/AAB：
     ```bash
     flutter build apk --release
     flutter build appbundle --release
     ```
   - 准备 Google Play 商店资料（可选）。

---

## 三、依赖变更汇总

| 包名 | 用途 | 操作 |
|------|------|------|
| `sqflite` | Android 原生 SQLite | 新增 |
| `flutter_local_notifications` | Android 本地通知 | 新增 |
| `android_alarm_manager_plus` | 后台定时任务 | 新增 |
| `timezone` | 定时通知时区处理 | 新增 |
| `sqflite_common_ffi` | 桌面端 SQLite | 保留 |
| `permission_handler` | 运行时权限请求（可选） | 新增 |

---

## 四、需修改的现有文件

| 文件 | 修改内容 |
|------|---------|
| `pubspec.yaml` | 添加 Android 相关依赖 |
| `lib/core/database/app_database.dart` | 平台条件初始化 + 路径适配 |
| `lib/services/notification_service.dart` | 保持接口，可选拆分文件 |
| `lib/app/app_dependencies.dart` | 平台条件注入 |
| `lib/services/background_task_service.dart` | 新增 Android 实现 |
| `lib/app/lifecycle.dart` | Android 生命周期适配（如有需要） |

---

## 五、新增文件

| 文件 | 用途 |
|------|------|
| `lib/services/android_notification_service.dart` | Android 通知实现 |
| `lib/services/android_background_task_service.dart` | Android 后台任务实现 |
| `android/` 目录 | Flutter 自动生成的 Android 工程 |

---

## 六、风险与注意事项

1. **电池优化**：Android 厂商（小米、华为、OPPO 等）有各自的后台杀进程策略，定时通知可能被系统拦截。需引导用户关闭电池优化或加入白名单。
2. **精确闹钟限制**：Android 12+ 需要 `SCHEDULE_EXACT_ALARM` 权限，且用户可在设置中撤销。
3. **通知渠道**：Android 8.0+ 必须创建 Notification Channel，否则通知不展示。
4. **数据迁移**：Android 版本是全新安装，无需考虑从 Windows 迁移数据（除非后续加入云同步）。
5. **SQLite 版本差异**：Android 系统自带 SQLite 版本不一，复杂 SQL 特性可能不可用。如需统一版本可使用 `sqlite3_flutter_libs`。

---

## 七、当前进度记录

记录时间：2026-06-28

### 已完成

- 已生成 Android 工程目录，并完成基础构建链路。
- 已配置 Android 包名为 `com.evoly.app`。
- 已接入 Android 真机远程调试设备：`192.168.31.14:42463`。
- 已完成 Android 状态栏显示修复，当前真机启动后状态栏可见。
- 已注入一组 Android 通知测试数据，用于验证即时通知、定时通知、锁屏/后台提醒场景。
- 已完成目标页 → 目标详情页 → 子任务编辑弹层的真机验证。
- 已修复子任务编辑弹层在键盘弹出时可能出现底部溢出/红屏的问题。
- 已修复今日页打开任务编辑弹层时标题显示为 `??????` 的问题，当前显示为 `编辑任务`。

### 本次真机验证结果

- 真机地址：`192.168.31.14:42463`。
- 测试路径：今日页 → 底部「目标」→ 第一个高优先级目标 → 第一个子任务 → 编辑弹层 → 点击输入框弹出键盘。
- 验证结果：弹层正常浮现，键盘弹出后内容正常上移，没有出现 Flutter 红屏。
- 日志结果：未发现 `BOTTOM OVERFLOW`、`Failed assertion`、`FATAL EXCEPTION`、`AndroidRuntime` 等关键崩溃日志。
- 进程状态：测试结束后 `com.evoly.app` 进程仍在运行。
- 验证截图：`evoly_verify_sheet.png`、`evoly_verify_focus.png`。

### 已通过的命令

```bash
flutter analyze
flutter test
flutter build apk --debug
```

### 待继续

- 继续验证后台通知：前台、后台、锁屏、杀掉应用后的提醒表现。
- 针对小米/MIUI 后台限制补充用户引导文案。
- 验证 Android 13+ 通知权限请求流程。
- 梳理 Release APK/AAB 签名与打包流程。

---

## 八、时间线估计

| 阶段 | 预计工时 |
|------|---------|
| Phase 1：工程初始化 | 1 天 |
| Phase 2：SQLite 适配 | 0.5 天 |
| Phase 3：通知服务适配 | 1.5 天 |
| Phase 4：依赖注入适配 | 0.5 天 |
| Phase 5：后台任务适配 | 1 天 |
| Phase 6：UI/UX 移动端适配 | 1.5 天 |
| Phase 7：测试与发布 | 1.5 天 |
| **总计** | **约 7.5 天** |

---

## 九、后续可选优化

- Material You 动态取色适配（Android 12+）。
- Widget（Android 桌面小组件）展示今日 Top 3 任务。
- 深度链接（Deep Link）从通知跳转到具体任务。
- 指纹/面部识别锁应用。
- 云同步后多端数据统一。
