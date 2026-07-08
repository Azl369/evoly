# Evoly 常用调试速查

这份文档只放日常最常用命令。更完整的 Android 迁移/排错记录见 `ANDROID_BUILD_NOTES.md` 和 `ANDROID_DEV_LOG.md`。

---

## 1. 固定环境路径

| 项目 | 路径 |
|------|------|
| 项目目录 | `D:\time_table` |
| Flutter SDK | `D:\dev\flutter` |
| Android SDK | `D:\dev\android-sdk` |
| adb | `D:\dev\android-sdk\platform-tools\adb.exe` |
| Pub Cache | `D:\dev\pub-cache` |
| Gradle Cache | `D:\dev\gradle` |
| JDK | `D:\dev\jdk-17` |
| Windows 数据库 | `%APPDATA%\Evoly\evoly.db` |
| Windows 构建产物 | `build\windows\x64\runner\Release\evoly.exe` |
| Android debug APK | `build\app\outputs\flutter-apk\app-debug.apk` |

原则：新 SDK、缓存、安装包、开发库优先放 D 盘。Visual Studio Build Tools 目前是既有 C 盘安装，ATL 已补齐。

---

## 2. 每个新 PowerShell 先执行

```powershell
cd D:\time_table

$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
$env:PUB_CACHE='D:\dev\pub-cache'
$env:GRADLE_USER_HOME='D:\dev\gradle'
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
$env:PUB_HOSTED_URL='https://pub.flutter-io.cn'
```

如果 Android 构建找不到 Java，再补：

```powershell
$env:JAVA_HOME='D:\dev\jdk-17'
$env:Path='D:\dev\jdk-17\bin;' + $env:Path
```

### 2.1 Supabase 同步参数

V0.4 同步功能使用 `--dart-define` 注入 Supabase 配置，不把项目地址和 publishable key 写死进仓库。

```powershell
$env:SUPABASE_URL='<your-supabase-project-url>'
$env:SUPABASE_PUBLISHABLE_KEY='<your-supabase-publishable-key>'
```

运行时追加：

```powershell
flutter run -d windows `
  --dart-define=SUPABASE_URL=$env:SUPABASE_URL `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=$env:SUPABASE_PUBLISHABLE_KEY
```

Android 真机运行同理，把 `-d windows` 换成当前设备 ID。

---

## 3. Windows 桌面端调试

### 3.1 运行

```powershell
flutter run -d windows
```

常用热键：

```text
r  热重载
R  热重启
q  退出
```

### 3.2 构建

```powershell
flutter build windows
```

构建完成后运行：

```powershell
build\windows\x64\runner\Release\evoly.exe
```

### 3.3 Windows 构建排错

如果报：

```text
atlbase.h: No such file or directory
```

说明 Visual Studio C++ ATL 组件缺失。当前已经安装过，验证命令：

```powershell
Get-ChildItem 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools' -Recurse -Filter atlbase.h -ErrorAction SilentlyContinue | Select-Object -First 5
```

如果以后重装系统导致缺失，用管理员 PowerShell 执行：

```powershell
$setup = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\setup.exe'
$installPath = 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools'
$args = 'modify --installPath "' + $installPath + '" --add Microsoft.VisualStudio.Component.VC.ATL --passive --norestart --nocache'
Start-Process -FilePath $setup -ArgumentList $args -Verb RunAs -Wait
```

---

## 4. Android 真机调试

### 4.1 手机端准备

手机开发者选项确认：

- 开启 `USB 调试`
- 开启 `无线调试`
- 如果使用 USB 安装，开启 `USB 安装`
- 小米/HyperOS 如安装失败，重点检查安装权限和后台/通知权限

### 4.2 无线调试连接

手机路径：

```text
开发者选项 → 无线调试 → 查看当前 IP:端口
```

电脑执行：

```powershell
$adb='D:\dev\android-sdk\platform-tools\adb.exe'
& $adb connect 192.168.31.14:<当前端口>
& $adb devices -l
flutter devices
```

注意：无线调试端口会变。每次手机重新打开无线调试后，都要用新的端口。

### 4.3 Android 运行

```powershell
flutter run -d 192.168.31.14:<当前端口>
```

如果 Flutter 没识别设备，但 adb 已连接：

```powershell
& $adb kill-server
& $adb start-server
& $adb connect 192.168.31.14:<当前端口>
flutter devices
```

如果 `flutter run -d 192.168.31.14:<端口>` 提示找不到设备，大概率是还没执行 `adb connect`，或者手机无线调试端口变了。

### 4.4 Android 构建 APK

```powershell
flutter build apk --debug
```

产物：

```text
build\app\outputs\flutter-apk\app-debug.apk
```

### 4.5 Android 日志

查看所有日志：

```powershell
& $adb logcat
```

只看 Evoly 进程：

```powershell
& $adb shell pidof com.evoly.app
& $adb logcat --pid=<上一步PID>
```

清空日志后复现：

```powershell
& $adb logcat -c
& $adb logcat --pid=<PID>
```

强制停止 App：

```powershell
& $adb shell am force-stop com.evoly.app
```

启动 App：

```powershell
& $adb shell monkey -p com.evoly.app 1
```

---

## 5. 常用验证命令

日常改代码后优先跑：

```powershell
flutter analyze
flutter test
```

涉及 Android 时加：

```powershell
flutter build apk --debug
```

涉及 Windows 桌面端时加：

```powershell
flutter build windows
```

一次性全跑：

```powershell
flutter analyze
flutter test
flutter build apk --debug
flutter build windows
```

---

## 6. 测试数据脚本

### 6.1 V0.2 Coach 演示数据

用于测试今日页 Coach、Top 3、延期目标：

```powershell
python scripts\reset_demo_data.py --backup
```

### 6.2 V0.3 文档库演示数据

用于测试文档库、Markdown 预览、文档关联目标、目标详情反查文档：

```powershell
python scripts\reset_v03_document_demo_data.py --backup
```

如果要把同一组 V0.3 文档库数据注入 Android App：

```powershell
python scripts\inject_android_v03_document_demo.py --device 192.168.31.14:<当前端口>
```

### 6.3 Android 后台通知演示数据

先确认 adb 已连接设备，再执行：

```powershell
python scripts\inject_android_notification_demo.py --device 192.168.31.14:<当前端口>
```

注入后：

1. 打开 Evoly 一次，让 App 同步提醒。
2. 锁屏等待 2 分钟。
3. 再测试杀掉 App 后的 5/8 分钟通知。

---

## 7. 常见问题速查

### 7.1 Flutter 找不到 Android 设备

先执行：

```powershell
$adb='D:\dev\android-sdk\platform-tools\adb.exe'
& $adb connect 192.168.31.14:<当前端口>
flutter devices
```

不要直接把手机显示的端口填给 `flutter run`，必须先 `adb connect`。

### 7.2 Android 构建又开始下载到 C 盘

说明当前终端没设置缓存环境变量。重新执行第 2 节环境命令。

### 7.3 Kotlin 跨盘符错误

典型报错：

```text
this and base files have different roots
```

原因：项目在 D 盘，但 Pub/Gradle 缓存在 C 盘。修复：

```powershell
$env:PUB_CACHE='D:\dev\pub-cache'
$env:GRADLE_USER_HOME='D:\dev\gradle'
flutter clean
flutter pub get
```

### 7.4 小米/HyperOS 安装失败

如果出现：

```text
INSTALL_FAILED_USER_RESTRICTED
```

检查手机开发者选项里的 `USB 安装`、安装权限和安全限制。

### 7.5 无线调试突然断开

重新连接：

```powershell
& $adb disconnect
& $adb connect 192.168.31.14:<新端口>
flutter devices
```

---

## 8. 推荐调试流程

### Windows 页面/数据库功能

```powershell
cd D:\time_table
flutter run -d windows
```

适合测试：

- 文档库
- 目标详情
- SQLite 数据
- 桌面端布局

### Android 真机体验

```powershell
$adb='D:\dev\android-sdk\platform-tools\adb.exe'
& $adb connect 192.168.31.14:<当前端口>
flutter run -d 192.168.31.14:<当前端口>
```

适合测试：

- BottomSheet + 键盘动画
- 120Hz 流畅度
- 系统状态栏/导航栏
- 本地通知
- 后台/锁屏行为

### 测试打包
cd D:\time_table
```powershell
$env:Path = 'D:\dev\jdk-17\bin;' + [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
$env:JAVA_HOME='D:\dev\jdk-17'
$env:PUB_CACHE='D:\dev\pub-cache'
$env:GRADLE_USER_HOME='D:\dev\gradle'
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
$env:PUB_HOSTED_URL='https://pub.flutter-io.cn'

$env:SUPABASE_URL='https://qsyvkpydllbzjepctovi.supabase.co'
$env:SUPABASE_PUBLISHABLE_KEY='sb_publishable_dkkDieAkwCX7RmyEqIHRpA_1_KA1Fr8'

flutter build apk --release `
  --dart-define=SUPABASE_URL=$env:SUPABASE_URL `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=$env:SUPABASE_PUBLISHABLE_KEY

flutter build windows `
  --dart-define=SUPABASE_URL=$env:SUPABASE_URL `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=$env:SUPABASE_PUBLISHABLE_KEY
```
