---
name: evoly-android-edit-performance
description: Diagnose and fix Evoly Android edit-mode jank, keyboard animation lag, and large-data Flutter performance regressions. Use when Android forms, bottom sheets, text editing, keyboard popup, Today page, project detail, or heavy task lists feel slow or janky on real devices.
---

# Evoly Android Edit Performance

Use this skill when Evoly Android feels slow in edit mode, keyboard popup is
not smooth, bottom sheets jump during IME animation, or large task/project data
makes Today/project detail pages stutter.

Always pair this skill with `evoly-dev-environment` for Flutter, adb, cache,
and D-drive path rules.

## Core Lesson

The keyboard itself is often not the only bottleneck. In the July 2026 Android
investigation, Xiaomi Notes and Evoly both showed about 320 ms hot keyboard
popup latency, while Evoly still felt worse because app UI was doing too much
work around the keyboard and heavy pages were consuming too much memory.

The winning fixes were:

- Stop Android IME resize from relaying out the Flutter form route.
- Avoid Flutter-side keyboard padding animations that fight the system IME.
- Render heavy task lists lazily.
- Measure on a real device with injected data before guessing.

## Fast Triage

1. Confirm the user-facing path.
   - Which page: Today, project list, project detail, document edit, task edit.
   - Which action: tap edit, focus text field, open keyboard, scroll, save.
   - Which device and adb serial.

2. Check whether it is system IME latency or app jank.
   - Compare with a native app such as Notes on the same device.
   - If both open the keyboard in roughly the same time, focus on app layout,
     memory, and build cost.

3. Measure before editing.
   - Use profile/release mode where possible.
   - Debug mode is useful for correctness, not frame-rate conclusions.

## adb Setup

Use the active wireless debugging serial supplied by the user:

```powershell
$adb = 'D:\dev\android-sdk\platform-tools\adb.exe'
$serial = '192.168.31.14:43225'
& $adb connect $serial
& $adb -s $serial get-state
```

If adb reports multiple devices, always pass `-s $serial`.

## Build and Run

Use project environment variables before Flutter commands:

```powershell
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
$env:PUB_CACHE='D:\dev\pub-cache'
$env:GRADLE_USER_HOME='D:\dev\gradle'
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
$env:PUB_HOSTED_URL='https://pub.flutter-io.cn'

D:\dev\flutter\bin\flutter.bat run --profile --no-resident -d $serial
```

## Measurement Tools

### Memory

```powershell
& $adb -s $serial shell dumpsys meminfo com.evoly.app |
  Select-String -Pattern 'Native Heap|Graphics|TOTAL PSS|TOTAL RSS'
```

Red flags:

- PSS above several hundred MB on ordinary pages.
- PSS climbing hundreds of MB after entering a page or scrolling.
- Native Heap climbing with list rendering.

The July 2026 failure case reached about 1.2 GB PSS on Today and about 1.6 GB
after heavy project-detail scrolling. After lazy rendering it stayed around
420-453 MB on the same injected data.

### SurfaceFlinger Frame Estimate

`dumpsys gfxinfo` can report zero Flutter frames on some SurfaceView/Vulkan
paths. When that happens, use SurfaceFlinger latency.

Find the Flutter SurfaceView layer:

```powershell
& $adb -s $serial shell dumpsys SurfaceFlinger --list |
  Select-String -Pattern 'SurfaceView\[com.evoly.app'
```

Measure scroll FPS:

```powershell
function Get-EvolyLayer {
  $list = & $adb -s $serial shell dumpsys SurfaceFlinger --list
  $line = ($list | Where-Object {
    $_ -match 'SurfaceView\[com\.evoly\.app/com\.evoly\.app\.MainActivity\]\(BLAST\)'
  } | Select-Object -Last 1)
  return ($line -replace '^RequestedLayerState\{','' -replace ' parentId=.*$','')
}

$layer = Get-EvolyLayer
& $adb -s $serial shell "dumpsys SurfaceFlinger --latency-clear '$layer'" | Out-Null
Start-Sleep -Milliseconds 200

$sw = [System.Diagnostics.Stopwatch]::StartNew()
1..4 | ForEach-Object {
  & $adb -s $serial shell input swipe 600 2200 600 600 450 | Out-Null
  Start-Sleep -Milliseconds 120
}
$sw.Stop()
Start-Sleep -Milliseconds 600

$lat = & $adb -s $serial shell "dumpsys SurfaceFlinger --latency '$layer'"
$rows = $lat | Select-Object -Skip 1 | ForEach-Object {
  $p = $_ -split '\s+'
  if ($p.Count -ge 3 -and $p[0] -match '^\d+$' -and [int64]$p[0] -gt 0) {
    [pscustomobject]@{ actual = [int64]$p[1] }
  }
}
$count = @($rows).Count
if ($count -gt 1) {
  $first = ($rows | Select-Object -First 1).actual
  $last = ($rows | Select-Object -Last 1).actual
  $durMs = ($last - $first) / 1000000.0
  $fps = if ($durMs -gt 0) { ($count - 1) * 1000.0 / $durMs } else { 0 }
  "frames=$count sf_duration_ms=$([math]::Round($durMs,1)) approx_fps=$([math]::Round($fps,1))"
}
```

### UI State

```powershell
& $adb -s $serial shell uiautomator dump /sdcard/window.xml *> $null
& $adb -s $serial shell cat /sdcard/window.xml
```

Use this to confirm that injected data is visible, a tab is selected, or a
bottom sheet/dialog actually opened.

## Large Data Injection Pattern

Before pushing any generated performance DB to the phone, pull or keep a clean
backup:

```powershell
$backup = 'D:\dev\tmp\evoly_perf\evoly.before_perf.db'
```

Restore the backup when done:

```powershell
& $adb -s $serial shell am force-stop com.evoly.app
& $adb -s $serial push $backup /data/local/tmp/evoly.before_perf.db
& $adb -s $serial shell chmod 644 /data/local/tmp/evoly.before_perf.db
& $adb -s $serial shell run-as com.evoly.app cp /data/local/tmp/evoly.before_perf.db /data/user/0/com.evoly.app/databases/evoly.db
& $adb -s $serial shell run-as com.evoly.app rm -f /data/user/0/com.evoly.app/databases/evoly.db-journal /data/user/0/com.evoly.app/databases/evoly.db-wal /data/user/0/com.evoly.app/databases/evoly.db-shm
& $adb -s $serial shell rm -f /data/local/tmp/evoly.before_perf.db /data/local/tmp/evoly.with_perf.db
```

Verify cleanup by pulling the DB and counting rows:

```powershell
cmd /c "D:\dev\android-sdk\platform-tools\adb.exe -s $serial exec-out run-as com.evoly.app cat /data/user/0/com.evoly.app/databases/evoly.db > D:\dev\tmp\evoly_perf\evoly.restored_verify.db"
```

Then inspect with SQLite/Python.

## Code Fix Patterns

### Android keyboard and bottom sheets

Prefer these patterns:

- `android:windowSoftInputMode="adjustNothing"` for `MainActivity`.
- Full-screen form routes use `Scaffold(resizeToAvoidBottomInset: false)`.
- Form content scrolls and uses bottom padding from `MediaQuery.viewInsets`.
- Avoid long delayed focus on Android forms if the user expects immediate edit.
- Avoid stacking bottom-sheet entrance animation with a second slow Flutter
  keyboard padding animation.

Known Evoly files:

- `android/app/src/main/AndroidManifest.xml`
- `lib/shared/ui/bottom_sheets/bottom_sheet_focus.dart`
- `lib/shared/ui/bottom_sheets/bottom_sheet_form_layout.dart`
- `lib/shared/ui/bottom_sheets/responsive_bottom_sheet_body.dart`

### Heavy task lists

Never put hundreds or thousands of task rows into:

- `ListView(children: [...])`
- `Column(children: [... for (final task in tasks) ...])`
- A single custom reorder group that eagerly builds every row.

Use:

- `ListView.builder`
- `CustomScrollView` + `SliverList` + `SliverChildBuilderDelegate`
- A flattened item model for headers/groups/rows.
- Inline reorder groups only for small groups; degrade large groups to lazy
  non-eager rows.

Known Evoly files:

- `lib/features/today/presentation/today_page.dart`
- `lib/features/goals/presentation/goal_detail_page.dart`

July 2026 example:

- Today page changed from eager section widget expansion to lazy list items.
- Goal detail changed from one `ListView(children)` containing a full task
  `Column` to `CustomScrollView` with sliver task lists.
- Per-task `GlobalKey` allocation was limited to highlighted/initial task
  paths instead of every row.

### Database queries

Do not assume SQLite is the bottleneck. Measure first.

Use local `EXPLAIN QUERY PLAN` and timing against the injected DB. In the July
2026 case, SQLite queries were fast enough:

- Goal aggregate around 2 ms for 251 goals / 6002 tasks.
- Heavy goal tasks around 2.3 ms for 1200 tasks.
- Today candidates around 6 ms for 2495 rows.

The real bottleneck was eager Flutter rendering and memory, not SQL.

## Validation Checklist

Run targeted checks first, then broader checks when changing shared UI:

```powershell
D:\dev\flutter\bin\flutter.bat analyze lib\features\today\presentation\today_page.dart lib\features\goals\presentation\goal_detail_page.dart
D:\dev\flutter\bin\flutter.bat test test\smoke_test.dart
D:\dev\flutter\bin\flutter.bat build apk --debug
```

For performance-sensitive Android fixes, also run profile on the real device:

```powershell
D:\dev\flutter\bin\flutter.bat run --profile --no-resident -d $serial
```

Compare before/after:

- Cold page PSS.
- PSS after entering heavy page.
- PSS after repeated scroll.
- SurfaceFlinger scroll FPS.
- Keyboard open path against a native baseline app.

## Decision Rules

- If native apps show similar keyboard popup latency, do not overfit on IME
  speed. Fix Evoly layout pressure and memory first.
- If PSS jumps by hundreds of MB after opening a page, inspect eager lists and
  keys before adding indexes.
- If `gfxinfo` reports zero frames, switch to SurfaceFlinger latency.
- If the user asks to inject performance data, always create or locate a clean
  backup before pushing the perf DB.
- Restore user data after testing unless the user explicitly wants the perf DB
  left on the phone.

