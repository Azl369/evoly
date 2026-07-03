# Evoly

Evoly 是一个本地优先的个人成长追踪与目标驱动应用，目标是帮助用户把长期成长方向拆成每日行动，并通过提醒、进度追踪、统计反馈和复盘持续推进个人提升。

## 当前阶段

项目已进入 V0.4-alpha 阶段，当前主线是在 V0.3 文档库基础上，补齐全局主题/UI 体验，并接入 Android + Windows 的 Supabase 账号同步最小闭环。

V0.1 已验证的最小闭环：

```text
创建目标 → 添加任务 → 今日页查看 → 标记完成 → 看到完成反馈
```

V0.2 已完成重点：

- 本地规则版 Evoly Coach：今日任务负载分析、Top 3 关键任务、延期目标识别、简单行动建议。
- Coach 建议可操作化：开始第一项、只保留 Top 3、查看延期目标、添加今日行动。
- 本地提醒、统计、目标详情和 Android 体验打磨。

V0.3-alpha 已完成重点：

- 新增底部一级入口“文档库”。
- 支持新建、编辑、删除 Markdown 文档。
- 支持文档类型、最近更新、基础搜索和 Markdown 预览。
- Markdown 预览支持数学公式、ChordPro 和弦谱、吉他 TAB 与 ABC 简谱块；编辑页可一键插入音乐谱块模板。
- 文档库已升级为“目标档案夹”结构：一个目标天然对应一个文件夹，文件夹内承载过程记录、项目总结、复盘和知识沉淀。
- 目标详情页支持打开目标档案夹，并在目标档案夹内查看全部关联文档、新建过程记录和创建项目总结草稿。
- 文档自动保存和目标关联文档闭环已接入，后续继续补任务链接、文件夹内筛选和 Markdown 导出。

V0.4-alpha 当前重点：

- 全局主题系统：支持“默认蓝 / 森林绿 / 日出暖橙 / 墨灰”四套主题，以及跟随系统、浅色、深色模式。
- 全局 UI 重构：补齐设计 token、共享组件、紧凑表单弹层、任务/目标卡片、Today Coach、统计图和文档库视觉统一。
- 浮层滑动选择：目标、任务和子任务的优先级/状态选择统一为长按上浮、上下滑动、松手落回的交互。
- Supabase Auth：设置页支持登录、创建账号、退出、session 状态展示；未登录或未配置时同步保持关闭。
- V0.4 同步基础：本地新增 `device_identity`、`sync_state`、`sync_outbox` 及变更记录，支持 push/pull 到 Supabase `sync_changes`。
- Android + Windows 双端联调：Android 使用下拉刷新触发同步，Windows 在设置页保留“立即同步”按钮。
- 本地刷新修复：本机新增/编辑目标、任务、子任务和文档后，Today/Goals 等页面会立即收到刷新信号，不再依赖同步后才更新。
- Markdown 预览修复：数学公式块与 ChordPro/TAB/ABC 音乐块混合渲染时不再触发 `flutter_markdown` 的 `_inlines.isEmpty` assertion。

## 本次本地改动概览（相对上一次推送）

- **主题与设计系统**：新增主题预设、SQLite 设置持久化、`EvolyDesignTokens`、共享 UI 组件，并统一主要 Material 3 组件主题。
- **页面 UI 升级**：Today、Goals、Goal Detail、Task Sheets、Stats、Documents、Settings/Review 已按更轻量、更高级、更紧凑的方向重构。
- **编辑体验**：目标编辑弹层降低占屏比例并优化键盘动画；任务/子任务编辑减少上下留白；优先级和状态选择改为浮层滑动选择。
- **同步与账号**：接入 Supabase 初始化、深链回调、Auth controller、远端同步仓库、同步引擎、初始快照入队和本地 outbox。
- **同步入口**：Android Today/Goals 支持下拉同步；Windows 设置页保留按钮同步，并显示上传/拉取结果。
- **数据一致性**：远端变更应用时按依赖顺序写入，处理外键缺失跳过；本地写入后通知 UI 刷新，减少跨页面旧数据。
- **测试与演示**：新增设置页覆盖测试数据入口，补充 `SlideSelectField` 和 Markdown 自定义块渲染测试。
- **开发文档**：新增主题系统计划、V0.4 同步计划和 Supabase `sync_schema.sql`，调试指南补充 Supabase `--dart-define` 用法。

## 文档

- 产品目标：`PRODUCT_GOAL.md`
- 架构设计：`ARCHITECTURE_DESIGN.md`
- 调试速查：`DEBUG_GUIDE.md`
- V0.1 研发计划：`V0_1_DEV_PLAN.md`
- V0.2 研发计划：`V0_2_DEV_PLAN.md`
- V0.3 研发计划：`V0_3_DEV_PLAN.md`
- V0.4 研发计划：`V0_4_DEV_PLAN.md`
- 主题系统研发计划：`THEME_SYSTEM_DEV_PLAN.md`
- Supabase 同步 schema：`supabase/sync_schema.sql`
- 时序图渲染器开发计划：`TIMING_DIAGRAM_RENDERER_DEV_PLAN.md`

## 技术方向

- 客户端：Flutter
- 本地数据：SQLite
- 云同步：Supabase Auth + PostgreSQL/RLS，客户端通过 `--dart-define` 注入项目配置
- 提醒能力：系统本地通知
- 架构风格：本地优先、分层架构、模块化 Feature
- UI 策略：Material 3、全局主题预设、设计 token、共享组件、语义色
- 动画策略：统一 Motion Token、局部刷新、轻量转场、避免阻塞 UI 线程，支持减少动态效果降级

## 目录概览

```text
lib/
  app/        应用入口、路由、主题、生命周期
  core/       数据库、错误、时间、通用领域对象
  features/   Coach、文档库、目标、任务、提醒、今日计划、统计、复盘、设置
  services/   本地通知、存储、后台任务服务
  shared/     通用 UI 组件、动画 token、设计 token
  dev/        覆盖测试数据生成器
```

## Windows 桌面端开发

当前开发环境：

- Flutter SDK：`D:\dev\flutter`
- 目标平台：Windows Desktop
- 本地数据库：`%APPDATA%\\Evoly\\evoly.db`
- 构建产物：`build\\windows\\x64\\runner\\Release\\evoly.exe`

常用命令：

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d windows
flutter build windows
```

如果新终端识别不到 `flutter`，重启 IDE 或终端，让用户 PATH 中的 `D:\dev\flutter\bin` 生效。

V0.4 同步功能需要通过 `--dart-define` 注入 Supabase 配置。不要把真实项目 URL 或 publishable key 写死到仓库里：

```bash
flutter run -d windows \
  --dart-define=SUPABASE_URL=<your-supabase-project-url> \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<your-supabase-publishable-key>
```

Android 真机调试时把 `-d windows` 替换为当前设备 ID：

```bash
flutter run -d 192.168.31.14:<当前端口> \
  --dart-define=SUPABASE_URL=<your-supabase-project-url> \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<your-supabase-publishable-key>
```

## 本地演示数据

如果在 UI 中修改了 Coach 演示任务，可以运行脚本把本地 SQLite 恢复到 V0.2 Coach 测试状态：

```bash
python scripts/reset_demo_data.py
```

如需重置前备份数据库：

```bash
python scripts/reset_demo_data.py --backup
```

脚本只会删除并重建 `demo-v022-` 前缀的演示目标、任务和提醒，不会修改其他真实数据。默认数据库路径为 `%APPDATA%\\Evoly\\evoly.db`。

如果需要测试 V0.3 文档库、目标关联文档和 Markdown 预览，可以运行：

```bash
python scripts/reset_v03_document_demo_data.py --backup
```

脚本只会删除并重建 `demo-v031-` 前缀的演示目标、任务、文档和文档关联，不会修改其他真实数据。默认数据库路径同样为 `%APPDATA%\\Evoly\\evoly.db`。

如果需要把同一组 V0.3 文档库测试数据注入 Android 真机：

```bash
python scripts/inject_android_v03_document_demo.py --device 192.168.31.14:<当前端口>
```

如果需要覆盖测试全局 UI、主题、文档预览、统计和同步刷新路径，可以在设置页点击“生成覆盖测试数据”。该入口会创建 `coverage-` 前缀的目标、任务、提醒和文档，用于真机快速验收。

## 当前功能

- App 支持四套主题预设：默认蓝、森林绿、日出暖橙、墨灰。
- App 支持跟随系统、浅色、深色三种主题模式，并持久化保存到本地 SQLite 设置表。
- 全局 UI 已接入设计 token 和共享组件，主要页面的卡片、徽标、指标、空状态、弹层和列表密度保持一致。
- 今日页从本地 SQLite 读取今日任务。
- Android 今日页和目标页支持下拉触发同步；Windows 保留设置页“立即同步”按钮。
- 今日页展示 Evoly Coach 今日建议卡，支持展开/折叠。
- Coach Lite 可分析今日任务是否过多、推荐 Top 3 关键任务、识别延期风险目标，并给出本地规则建议。
- Coach 建议支持可操作化：开始第一项、只保留 Top 3、查看延期目标、添加今日行动、去统计页复盘；涉及批量修改时会先展示调整草案并等待确认。
- 今日页按高/中/低优先级和已完成分组展示任务，组内按截止时间排序。
- 今日页可编辑、延期、删除任务。
- 今日页启动时会检查已到期的本地提醒，并触发 Windows 系统通知；失败时降级为应用内提示。
- 任务编辑支持设置今天提醒、明天提醒或关闭提醒。
- 统计页从本地 SQLite 读取真实数据，展示今日/本周完成数、延期数、目标完成率和连续完成天数。
- 已完成任务和已完成目标会用删除线展示，模拟手动划掉的完成感。
- 统计页的今日完成、本周完成可点击展开/折叠，查看已完成项目明细。
- 目标页从本地 SQLite 读取目标列表。
- 目标页可创建一个目标和今天的第一步任务。
- 目标页可按状态筛选目标，并按最近更新、截止时间、优先级、进度、名称排序。
- 目标页可直接编辑和删除目标。
- 目标编辑弹层支持自动保存，修改后无需再手动点保存。
- 目标编辑弹层已优化键盘弹出时的布局和动效，占屏比例更紧凑。
- 目标优先级和状态支持长按上浮、上下滑动选择。
- 目标详情页可读取真实目标和子任务。
- 目标详情页可新增、完成、延期、删除子任务。
- 目标详情页可编辑目标名称、描述、优先级和状态。
- 目标详情页可编辑子任务名称、说明、优先级、状态、预计耗时和截止日期。
- 任务/子任务编辑弹层支持自动保存，关闭前会补一次保存。
- 任务/子任务优先级和状态支持浮层滑动选择。
- 今日页可标记任务完成，并持久化保存。
- 本地新增、编辑、完成、延期、删除任务或目标后，会通知相关页面立即刷新。
- 目标进度根据子任务完成比例自动计算。
- 底部导航新增“文档库”入口。
- 文档库从本地 SQLite 读取 Markdown 文档，首页以目标档案夹为主，支持目标文件夹、最近文档、未归档文档和标题/正文搜索。
- 文档库支持进入某个目标档案夹，查看该目标下全部关联文档。
- 文档编辑页支持标题、类型、Markdown 正文编辑、保存、删除和预览切换。
- 文档编辑页支持插入音乐谱块模板，预览时可渲染 ChordPro 和弦谱、吉他 TAB 与 ABC 简谱。
- Markdown 预览支持数学公式块和音乐谱块混合渲染，并对空自定义块做降级处理。
- 文档编辑页支持关联目标，保存后会写入本地 `document_links`。
- 目标详情页展示最近关联文档，并支持打开目标档案夹、直接新建一篇已关联当前目标的项目文档。
- 目标详情页支持创建项目总结草稿，自动生成 Markdown 复盘模板并关联当前目标。
- 设置页支持 Supabase 登录、创建账号、退出登录和 session 状态展示。
- 未登录或未配置 Supabase 时，同步保持关闭，App 仍完整保持本地优先使用。
- 本地数据库记录当前设备身份、同步状态和待上传 outbox。
- 同步引擎支持先上传本地变更、再按 revision 拉取远端变更。
- Supabase 远端使用 `sync_changes` 变更日志表和 RLS，实现按账号隔离的增量同步。

## 统计口径

- 今日完成：今天 `completed_at` 落在当天的已完成任务数。
- 本周完成：本周一到本周日 `completed_at` 落在本周的已完成任务数。
- 今日/本周延期：任务状态为已延期，且 `updated_at` 落在对应时间范围内。
- 目标完成率：已完成目标数 / 全部目标数。
- 连续完成天数：从今天向前连续计算“当天至少完成 1 个任务”的天数。

