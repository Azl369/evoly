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

## 07/08 Feedback: Due Time, Reminders, and Task Surface

### Current Findings

- `TaskItem.dueDateTime` 当前已经是具体 `DateTime`，不是只有“今天/明天”的枚举；问题主要在 UI 只暴露了粗粒度入口。
- 新建子任务默认写入 `今天 23:59`；编辑子任务里“明天”当前写入 `明天 23:59`。
- 计划页查询已包含 `dueDateTime < 今日结束` 的任务，但 UI 仍归到“今日到期”，缺少独立“已延期”分区，导致第二天到期任务的语义不清楚。
- 小组件/迷你提醒面板读取的是 `Reminder` 记录，不是 `Evoly Compass` 建议；只有设置了提醒的任务才会进入提醒面板，“截止时间”本身不等于提醒。
- Coach 今日建议主要围绕今日窗口和已加载上下文，未来到期任务没有被设计成一定提醒，因此“明天到期”不会稳定出现在 Coach 提醒里。
- “开始第一项”当前打开子任务编辑页，用户目标更像是进入该子任务所属项目继续处理。
- 子任务卡 hover 仍带有偏重阴影，不符合后续 section-based / Astryx-inspired 的更轻量 surface 方向。
- `预计耗时` 在当前流程里没有形成强功能闭环，用户感知成本高于收益，可以从主编辑流程移除或降级。

## Batch 6: Delayed Plan Section

### Scope

- `TodayPage` 任务分区与排序。
- `TaskRepository.findPlanningCandidates` 查询语义确认。
- smoke/widget tests。

### Product Rules

- 计划页分区调整为：
  - `已延期`：未完成且 `status == postponed`，或未完成且 `dueDateTime < now`。
  - `今日到期`：未完成且 `todayStart <= dueDateTime < todayEnd`。
  - `待安排`：未完成且 `dueDateTime == null`。
  - `今天已完成`：今天完成的任务。
- `已延期` 优先显示在 `今日到期` 上方，避免用户漏看。
- 已延期任务仍按优先级分组，并保留用户手动排序。
- 被用户延期到明天/未来的任务也进入 `已延期`，而不是从计划页消失。
- 超过截止时间但仍是 `pending` 的任务，UI 有效状态显示为 `已延期`，不继续显示 `待完成`。
- 未来到期任务首批仍不进入计划页主列表，等 Batch 7 完成精确到期时间后再评估是否增加“稍后”分区。

### Implementation Notes

- 新增 `_belongsToDelayedSection(TaskItem task, DateTime now)`：
  - `status == postponed`
  - 或 `dueDateTime != null && dueDateTime < now`
  - `status` 非 completed/cancelled。
- `TaskItem` 增加 effective status 规则：`pending + dueDateTime < now` 展示为 `postponed`。
- `TaskCard` 和 `TaskEditSheet` 使用 effective status，避免已延期分区里仍显示 `待完成`。
- `_belongsToDueSection` 改为只匹配今天，不再包含过去日期。
- `_taskGroups` 增加 delayed section，并复用现有 priority section 组件。
- `TaskRepository.findPlanningCandidates` 纳入 `status == postponed` 的任务，即使 dueDateTime 是明天/未来。
- 概览区增加 `x 已延期` 计数，颜色使用 warning/error 语义 token，不使用强警报式大面积红色。
- 空状态需区分：
  - 没有已延期：不显示已延期分区。
  - 只有已延期：计划页仍有任务，不显示全局空状态。

### Tests

- 已到期且未完成的 pending 任务显示在 `已延期`。
- 已到期且未完成的 pending 任务卡片状态显示为 `已延期`，不显示 `待完成`。
- 手动延期到明天/未来的任务显示在 `已延期`。
- 昨天到期任务不显示在 `今日到期`。
- 今天到期任务仍显示在 `今日到期`。
- 无截止任务仍显示在 `待安排`。
- 已完成/已取消的延期/过期任务不显示在 `已延期`。
- 第二天打开同一任务时，从 `今日到期` 变为 `已延期`。

## Batch 7: Precise Due Date and Time Picker

### Scope

- `TaskCreateSheet`。
- `TaskEditSheet`。
- 任务卡截止时间展示。
- reminder/coach 交互文案。

### Product Rules

- 截止时间和提醒是两个不同概念：
  - 截止时间：任务什么时候应该完成。
  - 提醒：系统什么时候通知用户。
- 新建子任务默认截止时间为 `今天 23:59`。
- 快捷选项保留：
  - `今天`：今天 23:59。
  - `明天`：明天 23:59。
  - `不设`：清空截止时间。
- 增加 `自定义`：
  - 可选择具体日期。
  - 可选择具体时间。
  - 保存到同一个 `dueDateTime` 字段，不需要数据库迁移。
- 如果用户选择“明天 10:00”，第二天 10:00 之后进入 `已延期`。
- 任务卡展示日期+时间：
  - 今天：`截止 今天 18:00`。
  - 明天：`截止 明天 10:00`。
  - 更远日期：`截止 7月12日 10:00`。
  - 已延期：`已延期 昨天 23:59` 或 `已延期 7月6日 18:00`。

### Implementation Notes

- 用 Flutter 原生 `showDatePicker` + `showTimePicker`，不要手写复杂日历。
- 在 `TaskEditSheet` 中替换当前 `_DueOption` 的纯 segmented 控件：
  - 上方保留快捷 segmented。
  - 下方在有 dueDateTime 时显示一个可点击的 compact due summary row。
  - 点 summary row 进入日期/时间选择。
- `TaskCreateSheet` 当前没有到期时间选择，需要补齐：
  - 默认值为今天 23:59。
  - 可在创建时改为明天/不设/自定义。
- 清空截止时间时不自动清空提醒；提醒仍由提醒控件独立控制。

### Tests

- 新建子任务默认 dueDateTime 为今天 23:59。
- 新建子任务可设置明天具体时间。
- 编辑子任务可把 dueDateTime 改为指定日期时间。
- `不设` 清空 dueDateTime。
- 自定义 dueDateTime 不改变 reminder。
- 任务卡按今天/明天/未来日期/过期显示正确文案。

## Batch 8: Reminder Panel and Coach Boundary

### Scope

- Compact reminder service/panel。
- Reminder copy。
- Coach entry copy。
- Task create/edit reminder UX。

### Product Rules

- 小组件/迷你面板展示的是“提醒”，不是 `Evoly Compass`。
- 没有设置提醒时，显示 `暂无提醒` 是符合当前数据逻辑的，但需要给用户一个更清楚的解释和入口。
- 截止时间不自动创建提醒，避免用户只想记录 deadline 却被打扰。
- 可以增加一个轻量桥接：
  - 设置截止时间时，提醒控件提供 `到期前提醒` 快捷项。
  - 或在提醒面板空状态提供 `为任务添加提醒` 操作。

### Implementation Notes

- 将迷你面板文案从可能让用户误解为 Coach 的表达，调整为 `任务提醒` / `下一个任务提醒`。
- 空状态：
  - 标题：`暂无任务提醒`
  - 说明：`给子任务设置提醒后会显示在这里。`
  - 行动：`打开计划`
- `CompactReminderService` 保持读取 `ReminderRepository.findUpcoming`，不直接读取 Coach insight。
- `TaskReminderPicker` 增加基于 dueDateTime 的快捷项评估：
  - `到期时`
  - `提前 10 分钟`
  - `提前 1 小时`
  - 首批可以只做文案/计划，不一定立即实现。
- Coach 继续保留“今日建议”，但不要承担系统通知职责。

### Tests

- 没有 reminder 时迷你面板显示 `暂无任务提醒`。
- 有 dueDateTime 但没有 reminder 时，迷你面板仍不显示该任务。
- 有 reminder 时迷你面板显示最近提醒。
- 已完成任务的 reminder 不进入面板。
- 每周/月重复提醒继续正常滚动到下一次。

## Batch 9: Coach Primary Action Navigation

### Scope

- Today page Coach card/action。
- Navigation route arguments。
- Goal detail highlight behavior。

### Product Rules

- `开始第一项` 不打开子任务编辑页。
- 点击后进入该子任务所属项目详情页。
- 如果可能，项目详情页滚动/高亮该子任务，而不是直接打开编辑表单。
- 用户想编辑时再点子任务卡。

### Implementation Notes

- 将当前 pending task open 行为拆分：
  - Compact reminder 点击任务：可以继续打开任务编辑。
  - Coach `开始第一项`：进入项目详情。
- `GoalDetailPage` 增加可选 `initialTaskId` 参数或 route arguments object。
- 进入后：
  - 如果 task 存在于当前项目列表，短暂高亮任务卡。
  - 如果 task 已完成/移动/删除，显示项目详情即可，不报错。
- 保持桌面和 Android 行为一致。

### Tests

- 点击 `开始第一项` 跳转到对应项目详情。
- 不弹出 `TaskEditSheet`。
- 对应任务卡存在时显示高亮状态。
- 如果任务项目映射缺失，回退到计划页提示，不崩溃。

## Batch 10: Task Card Hover and Form Simplification

### Scope

- `TaskCard` hover/pressed states。
- `AppListCard` / shared surface state。
- `TaskCreateSheet` / `TaskEditSheet` estimated minutes。
- Tests for visual state semantics where practical。

### Product Rules

- 子任务 hover 不使用明显阴影作为主反馈。
- 采用轻量 hover surface：
  - 背景轻微提亮或 tint。
  - 左侧/边框可有 subtle accent。
  - 保持列表稳定，不产生跳动。
- `预计耗时` 从子任务主创建/编辑流程移除。
- 既有数据字段 `estimatedMinutes` 暂时保留，避免 schema/sync 扩大变更。
- 新建任务默认 estimatedMinutes 仍写入内部默认值，例如 `30`，但不暴露给普通用户。
- 任务卡是否显示 `xx 分钟` 需要同步评估：
  - 首批建议从任务卡 meta 中隐藏预计耗时。
  - 后续如果引入排程/容量规划，再恢复为高级功能。

### Implementation Notes

- `TaskCard` 移除 estimated minutes meta pill，或放到调试/高级模式之后。
- `TaskCreateSheet` 删除预计耗时输入。
- `TaskEditSheet` 删除预计耗时输入和 controller。
- `_buildUpdatedTask` 保留原 estimatedMinutes，不因编辑其他字段而重置。
- 新建任务时默认 estimatedMinutes = 30。
- Hover：
  - 检查 `AppListCard` 当前 selected/hover shadow。
  - 改为 tokenized background/border transition。
  - 不新增强阴影。

### Tests

- 新建任务不再显示 `预计耗时（分钟）`。
- 编辑任务不再显示 `预计耗时（分钟）`。
- 编辑任务保存时保留原 estimatedMinutes。
- 任务卡不再显示 `30 分钟` 等预计耗时 meta。
- hover 状态不会改变卡片尺寸。

## Release Plan

建议版本：

- `v0.4.1`：修复当前 release 反馈问题。
- `v0.4.4`：修复 07/08 反馈中的到期、提醒和任务表面问题。

建议批次：

1. Batch 1 + Batch 4：计划页长期任务可见、Windows Ctrl+S。影响最大且风险可控。
2. Batch 2：同优先级拖动排序。需要 migration 和同步字段，单独验证。
3. Batch 3：Android 键盘动画。需要真机反复验收，单独收尾。
4. Batch 6 + Batch 7：到期语义修复，先解决“第二天不过期”和具体时间选择。
5. Batch 8：小组件提醒与 Coach 边界澄清，修复“暂无提醒”的误解。
6. Batch 9 + Batch 10：入口导航和任务卡/表单体验优化。

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
