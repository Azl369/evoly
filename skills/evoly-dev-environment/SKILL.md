---
name: evoly-dev-environment
description: Evoly project development environment rules. Use when working in D:\time_table on Flutter builds, Android debugging, Windows builds, installing SDKs/tools/dependencies, configuring caches, or troubleshooting Visual Studio C++ ATL/MSVC issues. Enforces the rule that new SDKs, package caches, installers, and development libraries should go on D drive whenever possible.
---

# Evoly Dev Environment

## Core Rule

Prefer D drive for all new development tooling, SDKs, package caches, installers, and local libraries.

Use C drive only when a vendor-managed existing installation cannot be relocated safely. If C drive is unavoidable, explain why and keep all configurable caches/downloads on D drive.

## Standard Paths

- Project: `D:\time_table`
- Flutter SDK: `D:\dev\flutter`
- Android SDK / adb: `D:\dev\android-sdk`
- Pub cache: `D:\dev\pub-cache`
- Gradle cache: `D:\dev\gradle`
- JDK: `D:\dev\jdk-17`
- Installers/downloaded setup files: `D:\dev\installers`
- Temporary build/download workspace: `D:\dev\tmp`

Create missing D-drive directories before using them.

## Flutter Command Environment

Before running Flutter/Dart commands in this project, set:

```powershell
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
$env:PUB_CACHE='D:\dev\pub-cache'
$env:GRADLE_USER_HOME='D:\dev\gradle'
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
$env:PUB_HOSTED_URL='https://pub.flutter-io.cn'
```

For Android builds, ensure Java resolves to `D:\dev\jdk-17` when Gradle needs it.

## Installing Dependencies

- Put new SDKs and toolchains under `D:\dev`.
- Put downloaded installers under `D:\dev\installers`.
- Put package/cache directories on D drive via environment variables.
- Do not install new large development tools under default C-drive paths unless there is no safe alternative.
- If modifying an existing C-drive vendor installation, keep the modification minimal and document it.

## Visual Studio Build Tools / ATL

Current Windows Build Tools instance:

```text
C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools
```

This existing instance is vendor-managed on C drive. Adding ATL modifies that instance; it cannot be redirected to D drive without reinstalling Build Tools.

If `flutter build windows` fails with `atlbase.h: No such file or directory`, install ATL from an elevated Administrator terminal:

```powershell
$setup = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\setup.exe'
$installPath = 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools'
$args = 'modify --installPath "' + $installPath + '" --add Microsoft.VisualStudio.Component.VC.ATL --passive --norestart --nocache'
Start-Process -FilePath $setup -ArgumentList $args -Verb RunAs -Wait
```

Verify ATL:

```powershell
Get-ChildItem 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools' -Recurse -Filter atlbase.h -ErrorAction SilentlyContinue | Select-Object -First 5
flutter build windows
```

If the process is not elevated, Visual Studio Installer can return `5007` and no ATL files will be installed. If `installPath` is not quoted, setup will parse it as `C:\Program` and fail with exit code `1`.

## Android Debugging

Use the current wireless debugging port from the phone each session:

```powershell
D:\dev\android-sdk\platform-tools\adb.exe connect 192.168.31.14:<port>
flutter devices
flutter run -d 192.168.31.14:<port>
```

The port changes when wireless debugging is restarted.

## Validation Defaults

For normal Evoly changes, run:

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

Run `flutter build windows` after ATL/MSVC setup is healthy.
