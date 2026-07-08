# V0.4 Release Fix Plan

## Summary

本计划来自 v0.4.0 release 真机/桌面测试反馈，目标是在不扩大重构范围的前提下修复四个体验问题：

1. 未设置截止时间的长期演进子任务，也必须在计划视图中体现。
2. 同一优先级内的任务支持用户手动拖动排序。
3. Android 端键盘弹出/收起动画仍不流畅。
4. Windows 端 Markdown 编辑支持 `Ctrl+S` 保存当前文档。

## Product Direction

### Today Page Naming

当前“今日计划”语义偏窄，会让无截止日期但仍待推进的子任务被用户理解为“不属于今天”。建议将页面定位改为“计划”，并在页面内保留“今天”作为一个分区。

推荐信息结构：

- `计划`：底部导航和页面标题。
- `今日到期`：今天到期、逾期、今天提醒的任务。
- `待安排`：未完成、未设置截止时间、仍处于 pending/postponed 的任务。
- `稍后`：有未来截止日期但不是今天的任务，可先不在首批展示，避免计划页过重。

首批实现建议：

- 导航文案从“今日”改为“计划”。
- 页面标题从“今日计划”改为“计划”。
- 查询逻辑从只取 today due 扩展为：
  - 今日/逾期任务。
  - 无 dueDateTime 且未完成的任务。
- UI 分区显示，避免用户误以为所有任务都“今天必须完成”。

## Batch 1: Plan Page Includes Long-Running Tasks

### Scope

- `TodayPage` / `TodayController` / repository 查询。
- 导航栏文案。
- smoke/widget tests。

### Implementation Notes

- 新增 repository 方法或扩展现有查询：
  - `findPlanningCandidates(DateTime today)`，返回未完成且需要在计划中体现的任务。
  - 包含 `dueDateTime <= todayEnd` 的任务。
  - 包含 `dueDateTime == null` 的任务。
  - 排除 completed。
- Today 页面内部分区：
  - `今日到期`
  - `待安排`
- 空状态文案区分：
  - 今日无任务不代表没有长期任务。
  - 全部无待办才显示完整空状态。
- 同步刷新后计划页要重新加载。

### Tests

- 无截止时间 pending task 出现在计划页。
- completed 无截止时间 task 不出现。
- 今日到期和无截止时间任务分区显示正确。
- 原有今日/提醒/同步刷新测试继续通过。

## Batch 2: Manual Ordering Within Priority

### Scope

- task domain/database/repository。
- 计划页同优先级任务列表。
- goal detail 任务列表是否同步消费同一排序规则需要评估，建议一起统一。

### Product Rule

- 优先级仍是第一排序维度。
- 同一优先级内，用户可以上下拖动。
- 拖动只改变同优先级内的相对顺序，不跨优先级改 priority。
- 如果用户拖到另一个优先级区域，首批不允许落点，后续再考虑“拖动改优先级”。

### Data Model

新增字段建议：

- `sort_order INTEGER NOT NULL DEFAULT 0`

排序规则建议：

1. priority rank
2. sort_order ascending
3. dueDateTime nulls last or by section
4. createdAt ascending

写入策略：

- 现有任务迁移时用创建时间批量填充稳定 sort_order。
- 同优先级拖动后，只重写受影响任务的 sort_order。
- 新任务插入到当前 priority 的最后。
- 需要通过 `SyncChangeRecorder` 记录 task upsert，让排序可同步。

### UI

- Flutter `ReorderableListView` 或当前 section 内 `ReorderableList`。
- 拖拽 handle 使用图标按钮，不让整张卡误触发。
- 拖动中保留卡片宽度和高度，避免布局跳动。
- Android 长按拖动；Windows 鼠标拖动 handle。

### Tests

- 数据库 migration 保留既有任务。
- repository 保存 sort_order。
- 同优先级 reorder 后顺序稳定。
- 跨优先级拖动不改变 priority。
- 同步 outbox 包含 sort_order。

## Batch 3: Android Keyboard Animation Smoothness

### Scope

- task create/edit sheets。
- goal edit sheet。
- shared bottom sheet layout。
- slide select field / floating overlay 与 keyboard inset 的交互。

### Investigation Checklist

- 检查是否有多层 `AnimatedPadding`、`AnimatedSize`、`DraggableScrollableSheet` 同时响应 `viewInsets.bottom`。
- 检查 bottom sheet 是否在键盘弹出时重新 layout 过多大组件。
- 检查 TextField autofocus 是否触发连续 rebuild。
- 检查 Android 真机上是否存在 debug build jank；必要时用 profile build 验证。

### Implementation Direction

- 统一 bottom sheet 键盘处理入口：
  - 只在 `ResponsiveBottomSheetBody` 或 `BottomSheetFormLayout` 一层消费 `MediaQuery.viewInsets.bottom`。
  - 内层表单不再重复根据 keyboard inset 动画 padding。
- 动画参数：
  - 使用 `MotionTokens.normal`。
  - curve 使用 `Curves.easeOutCubic` 或现有 `MotionTokens.gentle`。
- 对长表单使用 `AnimatedPadding + SingleChildScrollView`，避免键盘弹出时内容被硬挤压。
- 对 slide select overlay：
  - 键盘打开时关闭浮层或重新定位。

### Tests

- Widget test 覆盖 viewInsets 从 0 到 keyboard height 时不 overflow。
- task create/edit sheet 在小屏高度下无 bottom overflow。
- goal edit sheet 在小屏高度下无 bottom overflow。
- 真机验收：
  - Android debug/profile 下打开任务编辑、子任务编辑、项目编辑。
  - 连续聚焦标题/备注/Markdown 输入时无明显跳动。

## Batch 4: Windows Markdown Ctrl+S Save

### Scope

- `DocumentEditPage`。
- Markdown editor focus/shortcut handling。

### Implementation Notes

- 使用 Flutter shortcuts/actions：
  - `SingleActivator(LogicalKeyboardKey.keyS, control: true)`。
  - Windows/Linux 可用 Ctrl+S。
  - macOS 如未来支持，可追加 meta+S。
- 快捷键触发当前保存逻辑，等同点击保存按钮。
- 保存中避免重复触发。
- 保存成功后沿用当前提示/dirty state。
- 如果当前没有改动：
  - 可显示“已是最新”或静默。

### Tests

- Windows shortcut test：按 Ctrl+S 调用保存。
- 保存中重复 Ctrl+S 不产生重复写入。
- 未聚焦 TextField / 聚焦 Markdown TextField 都能触发。
- 手动点击保存测试继续通过。

## Batch 5: Projectized Task Experience

### Scope

- 计划页任务卡、快速新建项目入口。
- 子任务编辑表单的所属项目切换。
- 用户可见中文文案从“目标”调整为“项目”。
- 不重命名内部 `Goal` / `goalId` / `goals` / sync entity `goal`。

### Product Rules

- “项目”是用户看到的一级容器名称。
- “子任务”继续作为项目下面的可执行事项。
- 计划页展示跨项目子任务，因此每张任务卡必须显示所属项目。
- 计划页快速入口只创建项目，不自动创建第一步子任务。
- 子任务切换所属项目只改变归属，不自动改变优先级、提醒、截止时间、状态或排序。

### Implementation Notes

- `TaskCard` 增加可选 `contextLabel`，计划页传入 `项目：<项目标题>`；项目详情页不传，避免重复上下文。
- `TodayPage` 加载任务时同时读取 `GoalRepository.findAll()`，维护 `goalId -> title` 映射；缺失映射时显示 `项目：未同步`。
- `TodayPage` app bar 增加 `新建项目` action，表单字段为项目名称、可选描述、优先级。
- 快速创建项目默认值：
  - `GoalType.longTerm`
  - `Priority.medium`
  - `GoalStatus.inProgress`
  - `startDate = now`
  - `dueDate = null`
- 创建成功后刷新计划数据，并打开新项目详情页，方便继续添加子任务。
- `TaskItem.copyWith` 增加 `goalId` 参数；SQLite 保存继续使用现有 `goal_id`，不需要迁移。
- `TaskEditSheet` 增加可选 `availableGoals` 参数；项目数量大于 1 时显示“所属项目”选择控件。
- 从项目详情页把子任务移动到其他项目后，当前详情页移除该子任务并提示“已移动到「xxx」”。
- 全局可见文案替换：
  - 底部导航：`项目`
  - 列表/详情：`项目`、`项目详情`
  - 文档：`项目档案` / `项目档案夹`
  - 统计：`项目完成率`
  - Coach/设置/空状态/删除确认等用户可见中文同步替换。

### Tests

- `TaskCard` 传入 `contextLabel` 时显示 `项目：xxx`，未传入时不显示归属标签。
- `TodayPage` 计划任务显示所属项目；缺失项目映射时显示 `项目：未同步`。
- `TodayPage` 快速新建只保存一个项目，不创建任务；创建后进入新项目详情页。
- `TaskEditSheet` 切换项目后保存的 `TaskItem.goalId` 改变，优先级、提醒、状态保持不变。
- `GoalDetailPage` 移动子任务到其他项目后，当前详情页不再显示该子任务。
- 文案回归：底部导航、项目列表、项目详情、文档库、统计页、设置页不再出现用户可见的“目标”主入口文案。

## Release Plan

建议版本：

- `v0.4.1`：修复当前 release 反馈问题。

建议批次：

1. Batch 1 + Batch 4：计划页长期任务可见、Windows Ctrl+S。影响最大且风险可控。
2. Batch 2：同优先级拖动排序。需要 migration 和同步字段，单独验证。
3. Batch 3：Android 键盘动画。需要真机反复验收，单独收尾。

## Validation

每批次至少运行：

```powershell
flutter analyze
flutter test
flutter build apk --debug --dart-define=SUPABASE_URL=$env:SUPABASE_URL --dart-define=SUPABASE_PUBLISHABLE_KEY=$env:SUPABASE_PUBLISHABLE_KEY
flutter build windows --dart-define=SUPABASE_URL=$env:SUPABASE_URL --dart-define=SUPABASE_PUBLISHABLE_KEY=$env:SUPABASE_PUBLISHABLE_KEY
```

发布前手动验收：

- Android：登录同步账号，创建无截止时间任务，确认计划页展示并可同步到 Windows。
- Android：打开任务/项目编辑，键盘弹出收起动画无明显抖动。
- Windows：登录同账号，拉取 Android 创建的任务。
- Windows：编辑 Markdown，按 `Ctrl+S` 保存。
- Windows：同优先级任务拖动排序后重启仍保持顺序。
