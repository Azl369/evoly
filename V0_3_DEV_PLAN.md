# Evoly V0.3 开发计划：文档库与目标知识沉淀

## 1. 版本定位

V0.3 的主线不再只是“在目标详情里加几篇笔记”，而是正式引入一个独立的 **文档库**。

文档库是 Evoly 的第四个核心能力：

```text
目标：决定要去哪里
任务：推动今天做什么
提醒：保证不要忘记
文档库：沉淀过程、复盘经验和可复用知识
```

V0.3 的一句话目标：

```text
让 Evoly 不只帮助用户完成目标，还能把目标推进过程沉淀成可复盘、可检索、可链接的 Markdown 文档库。
```

---

## 2. 产品判断

### 2.1 为什么文档库重要

对 Evoly 来说，文档库不是附属功能，而是个人成长产品的重要闭环。

用户完成一个项目或目标后，如果只留下“已完成任务”，价值是不够的。真正有长期价值的是：

- 这个项目怎么推进的。
- 中间遇到了什么问题。
- 做过哪些决策。
- 哪些经验下次还能复用。
- 哪些错误下次应该避免。
- 最终沉淀出什么知识文档。

因此，文档库应该成为 Evoly 的一等公民。

### 2.2 与普通笔记软件的区别

Evoly 不应该复制 Notion / Obsidian / 语雀。

Evoly 文档库的差异点是：

- 文档天然归属于目标档案夹。
- 一个目标天然对应一个文件夹，用来承载该目标推进过程中的所有文档。
- 文档可以链接到任务。
- 文档可以承接复盘。
- 文档可以从目标完成过程生成总结模板。
- 文档服务于“成长追踪”和“项目复盘”，而不是无限自由的信息收集。

### 2.2.1 目标文件夹式文档库

V0.3 文档库的信息架构应从“按文档类型管理”调整为“按目标文件夹管理”。

核心判断：

```text
目标 = 一个项目文件夹
文件夹里面 = 这个目标涉及到的各种过程文档、复盘文档、项目总结和知识记录
```

因此，文档库首页的主视图不应该是“项目文档 / 项目总结 / 复盘记录”的类型列表，而应该是：

```text
文档库
  ├─ 目标文件夹：V0.3 文档库最小闭环
  │   ├─ 开发记录
  │   ├─ 问题记录
  │   ├─ 项目总结
  │   └─ 复盘记录
  │
  ├─ 目标文件夹：Android 通知系统适配
  │   ├─ 权限记录
  │   ├─ 测试记录
  │   └─ 技术方案总结
  │
  └─ 未归档文档
      └─ 本周成长复盘
```

文档类型只作为文件夹内的标签或筛选条件，不再作为文档库的一级组织方式。

V0.3.3 的产品方向应明确为：

```text
文档库首页：目标文件夹列表
目标文件夹详情：该目标下的所有文档
目标详情页：展示目标档案入口，而不是承载完整文档管理
```

### 2.3 V0.3 的边界

V0.3 要做“够用且和目标系统强绑定”的文档库，不做重型知识库。

做：

- Markdown 文档。
- 文档库独立页面。
- 目标文件夹式文档库。
- 文档和目标/任务链接。
- 项目总结模板。
- 基础搜索。
- 最近更新。
- 目标详情页展示关联文档。

不做：

- 双向链接图谱。
- 多人协作。
- 云同步。
- 富文本编辑器。
- 复杂自由文件夹系统。
- 复杂空间/团队/权限系统。
- AI 自动长文生成。
- 大型附件管理。

---

## 3. 底部导航调整

### 3.1 新增底部入口

V0.3 需要在底部导航新增一个一级入口：

```text
今日 / 目标 / 文档库 / 统计 / 设置
```

建议顺序：

1. 今日
2. 目标
3. 文档库
4. 统计
5. 设置

原因：

- 今日和目标仍然是执行入口。
- 文档库是沉淀入口，应该放在目标之后。
- 统计是结果观察，排在文档库之后。
- 设置继续放最后。

### 3.2 导航原则

- 文档库必须是独立页面，不藏在目标详情页里。
- 目标详情页只展示“与该目标相关的文档”。
- 文档详情页可以反向看到它链接了哪些目标和任务。
- 用户应该能从任意目标快速进入相关文档，也能从文档库全局管理所有文档。

---

## 4. 核心页面

### 4.1 文档库首页

页面名称：

```text
文档库
```

核心内容：

- 搜索框。
- 目标文件夹列表。
- 最近更新文档。
- 未归档文档入口。
- 快速新建文档按钮。
- 目标文件夹卡片：
  - 目标标题
  - 目标进度
  - 文档数量
  - 最近更新文档标题
  - 最后更新时间

文档类型筛选不再作为文档库首页的主入口，只保留在目标文件夹详情页内作为辅助筛选。

空状态文案：

```text
还没有目标档案。
创建一个目标后，Evoly 会为它生成一个文件夹，用来沉淀过程、复盘和总结。
```

### 4.1.1 目标文件夹详情页

页面名称：

```text
目标档案：{goal_title}
```

核心内容：

- 目标摘要：标题、进度、状态。
- 新建文档。
- 创建项目总结。
- 文件夹内文档列表。
- 文件夹内按类型轻量筛选：
  - 全部
  - 过程记录
  - 项目总结
  - 复盘记录

目标文件夹详情页才是管理某个目标下所有文档的主场。

### 4.2 文档编辑页

能力：

- 编辑标题。
- 编辑 Markdown 正文。
- 编辑 / 预览切换。
- 保存。
- 删除。
- 选择文档类型。
- 管理链接目标。
- 管理链接任务。

建议顶部操作：

```text
返回 / 预览 / 保存 / 更多
```

编辑体验：

- 默认打开编辑模式。
- 支持长文本输入。
- 输入区占满屏幕。
- Android 键盘弹出时不能遮挡编辑区。
- 离开页面时如有未保存内容，需要提示。

### 4.3 目标详情页中的文档区域

目标详情页新增区域：

```text
关联文档
```

展示：

- 最近 3 篇关联文档。
- “查看全部”入口。
- “新建关联文档”按钮。
- “创建项目总结”按钮。

触发条件：

- 目标未完成时：展示普通项目文档入口。
- 目标完成或完成率 100% 时：展示项目总结入口。

### 4.4 文档链接选择页 / 弹窗

用途：

- 在文档编辑页选择要链接的目标或任务。
- 在目标详情页选择已有文档进行关联。

V0.3 可以先做轻量弹窗：

- 搜索目标。
- 勾选目标。
- 保存链接。

任务链接可以放在 V0.3.1，如果 V0.3 时间不够，先实现目标链接。

---

## 5. 核心场景

### 场景 1：项目过程中沉淀知识

用户正在推进一个目标：

```text
Android 通知系统适配
```

他在文档库中新建文档：

```markdown
# Android 通知适配记录

## 背景

需要支持前台、后台、锁屏和杀掉应用后的提醒。

## 问题

- 小米/HyperOS 后台限制较多。
- 精确闹钟权限需要处理。
- 通知点击后页面落点需要设计。

## 解决方案

- 使用 flutter_local_notifications。
- 定时提醒优先 exactAllowWhileIdle，失败后降级。
- 通过测试数据脚本构造提醒场景。
```

然后把这篇文档链接到目标：

```text
目标：Android 通知系统适配
```

以后在目标详情页能看到这篇文档；在文档详情页也能看到它关联了这个目标。

### 场景 2：目标完成后创建项目总结

当目标完成后，Evoly 提供入口：

```text
创建项目总结
```

点击后生成 Markdown 模板：

```markdown
# 项目总结：{{goal_title}}

## 1. 项目目标

{{goal_description}}

## 2. 完成结果

## 3. 已完成任务

- [x] {{task_1}}
- [x] {{task_2}}
- [x] {{task_3}}

## 4. 关键过程记录

## 5. 遇到的问题

## 6. 解决方案

## 7. 可复用经验

## 8. 下次可以改进
```

这篇文档类型为：

```text
projectSummary
```

并自动链接当前目标。

### 场景 3：随时复盘总结

用户在文档库中新建复盘文档：

```markdown
# 本周复盘

## 做得好的地方

## 卡住的地方

## 下周最重要的 3 件事
```

这类文档可以不链接目标，也可以链接多个目标。

未链接文档在文档库中会显示：

```text
未链接
```

后续可以提醒用户整理归档。

### 场景 4：从目标找到历史经验

用户打开一个目标详情页，能看到：

```text
关联文档 3 篇
```

点击后看到：

- 项目推进记录
- 技术问题解决记录
- 项目总结

这让目标不再只是“任务列表”，而是一个完整的项目档案。

---

## 6. 数据模型设计

### 6.1 Document

```dart
class Document {
  final String id;
  final String title;
  final String contentMarkdown;
  final DocumentType type;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
}
```

### 6.2 DocumentType

```dart
enum DocumentType {
  projectNote,
  projectSummary,
  review,
  knowledge,
}
```

说明：

- `projectNote`：项目过程记录。
- `projectSummary`：项目完成后的总结。
- `review`：复盘记录。
- `knowledge`：可复用知识文档。

### 6.3 DocumentLink

```dart
class DocumentLink {
  final String id;
  final String documentId;
  final String targetType;
  final String targetId;
  final DateTime createdAt;
}
```

`targetType` 可选：

```text
goal
task
review
```

V0.3 优先实现：

```text
document <-> goal
```

任务链接和复盘链接可以作为 V0.3.1 增强。

---

## 7. SQLite 表设计

### 7.1 documents

```sql
CREATE TABLE documents (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  content_markdown TEXT NOT NULL,
  type TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT
);
```

### 7.2 document_links

```sql
CREATE TABLE document_links (
  id TEXT PRIMARY KEY,
  document_id TEXT NOT NULL,
  target_type TEXT NOT NULL,
  target_id TEXT NOT NULL,
  created_at TEXT NOT NULL
);
```

### 7.3 索引

```sql
CREATE INDEX idx_documents_updated_at
ON documents(updated_at DESC);

CREATE INDEX idx_documents_type_updated_at
ON documents(type, updated_at DESC);

CREATE INDEX idx_document_links_document_id
ON document_links(document_id);

CREATE INDEX idx_document_links_target
ON document_links(target_type, target_id);
```

### 7.4 软删除

V0.3 建议文档采用软删除：

- 删除时写入 `deleted_at`。
- 默认查询排除已删除文档。
- V0.3 不做回收站 UI。
- 后续如需要可加“最近删除”。

---

## 8. 技术架构

### 8.1 Feature 目录

建议新增：

```text
lib/features/documents/
  domain/
    document.dart
    document_link.dart
  data/
    document_repository.dart
    sqlite_document_repository.dart
    document_mapper.dart
  application/
    document_controller.dart
    document_link_service.dart
    project_summary_template_service.dart
  presentation/
    document_library_page.dart
    document_editor_page.dart
    document_preview.dart
    document_link_picker.dart
    goal_documents_section.dart
```

### 8.2 依赖建议

建议引入：

```yaml
dependencies:
  flutter_markdown: ^0.7.0
```

用途：

- Markdown 预览。
- 支持标题、列表、代码块、引用、链接等基础语法。

暂不引入复杂富文本编辑器。

### 8.3 路由建议

```text
/documents
/documents/new
/documents/:documentId
/goals/:goalId/documents
```

目标详情页仍然走现有目标路由，只在页面内部加入关联文档区域。

### 8.4 底部导航改造

需要更新：

- `AppRoutes`
- 今日页底部导航
- 目标页底部导航
- 统计页底部导航
- 设置页底部导航
- 新增文档库页底部导航

建议抽一个共享 Bottom Navigation 组件，避免每个页面重复写导航项。

---

## 9. UI 设计原则

### 9.1 文档库首页

重点是轻量、清晰：

- 搜索在顶部。
- 最近更新优先。
- 不要一开始就做复杂文件夹。
- 文档卡片要显示关联目标，让用户知道这篇文档属于哪个项目。

文档卡片示例：

```text
Android 通知适配记录
项目文档 · 关联 1 个目标 · 今天 18:30
记录 Android 通知、后台提醒、锁屏提醒的适配过程...
```

### 9.2 Markdown 编辑页

移动端优先考虑：

- 大输入区域。
- 明确保存状态。
- 键盘弹出不遮挡。
- 预览切换不要太重。

Windows 端优先考虑：

- 编辑和预览可以后续做左右分栏。
- V0.3 首版仍可保持单栏切换，降低复杂度。

### 9.3 目标详情页关联文档

不应喧宾夺主。

目标详情页仍以目标和任务为主，文档区域负责连接沉淀：

```text
关联文档
最近更新的 3 篇
[新建文档] [创建项目总结]
```

---

## 10. 分期计划

### Phase 1：文档数据层

目标：

- 建立文档库的数据基础。

任务：

- 新增 `documents` 表。
- 新增 `document_links` 表。
- 新增 Document / DocumentLink 模型。
- 新增 Repository 接口。
- 新增 SQLite 实现。
- 支持 CRUD。
- 支持按更新时间查询。
- 支持按目标查询关联文档。

验收：

- 文档可以创建、更新、软删除。
- 文档可以链接目标。
- 可以查询某个目标下的关联文档。

### Phase 2：底部「文档库」页面

目标：

- 文档库成为一级入口。

任务：

- 新增 `DocumentLibraryPage`。
- 底部导航新增「文档库」。
- 文档库展示最近更新文档。
- 支持按类型筛选。
- 支持搜索标题。
- 支持新建文档。

验收：

- 底部导航能进入文档库。
- 文档库能展示所有文档。
- 新建文档后能回到文档库并刷新。

### Phase 3：Markdown 编辑与预览

目标：

- 用户可以真正写文档。

任务：

- 新增 `DocumentEditorPage`。
- 支持标题编辑。
- 支持 Markdown 正文编辑。
- 支持编辑/预览切换。
- 支持保存。
- 支持删除。
- 支持未保存离开提醒。

验收：

- Markdown 标题、列表、引用、代码块能预览。
- 长文本编辑不卡顿。
- Android 键盘体验可用。

### Phase 4：目标链接能力

目标：

- 文档能链接到目标。

任务：

- 文档编辑页支持链接目标。
- 文档卡片显示关联目标数量。
- 目标详情页显示关联文档区域。
- 目标详情页支持创建关联文档。
- 目标详情页支持查看全部关联文档。

验收：

- 从目标详情页创建文档后，文档自动链接当前目标。
- 文档详情页能看到关联目标。
- 目标详情页能看到关联文档。

### Phase 5：项目总结模板

目标：

- 项目完成后能沉淀结构化总结。

任务：

- 新增 `ProjectSummaryTemplateService`。
- 根据目标信息生成 Markdown 模板。
- 自动插入目标标题、描述、已完成任务列表。
- 目标完成时显示“创建项目总结”入口。

验收：

- 完成目标后可以创建项目总结。
- 总结文档自动链接目标。
- 模板内容结构清晰，可直接继续编辑。

### Phase 6：体验与文档

目标：

- 让文档库成为稳定可用的 V0.3 功能。

任务：

- 更新 README。
- 更新 PRODUCT_GOAL。
- 更新 ARCHITECTURE_DESIGN。
- 补充空状态。
- 补充 Android 真机编辑体验验证。
- 补充 Windows 桌面端编辑体验验证。

验收：

- `flutter analyze` 通过。
- `flutter test` 通过。
- Android 真机基础可用。
- Windows 桌面端基础可用。

---

## 11. 完成定义

满足以下条件即可认为 V0.3 完成：

- 底部导航包含「文档库」。
- 用户可以进入独立文档库页面。
- 用户可以创建 Markdown 文档。
- 用户可以编辑、保存、删除文档。
- 用户可以预览 Markdown。
- 用户可以从文档库查看目标文件夹列表。
- 用户可以进入某个目标文件夹查看该目标下所有文档。
- 用户可以查看最近更新文档。
- 用户可以查看未归档文档。
- 用户可以搜索文档标题。
- 用户可以将文档链接到目标。
- 目标详情页可以展示目标档案入口和最近关联文档。
- 从目标详情页创建文档时自动链接目标。
- 目标完成后可以创建项目总结模板。
- 文档和链接都保存在本地 SQLite。
- `flutter analyze` 通过。
- `flutter test` 通过。
- Android 真机验证通过。
- Windows 桌面端验证通过。

---

## 12. 测试计划

### 12.1 单元测试

- Document CRUD。
- DocumentLink 创建与删除。
- 按目标查询关联文档。
- 项目总结模板生成。
- 软删除文档不出现在默认列表。

### 12.2 Widget / Smoke 测试

- 文档库页面可渲染。
- 空状态可渲染。
- 目标文件夹列表可渲染。
- 目标文件夹详情页可渲染。
- 最近文档列表可渲染。
- 未归档文档列表可渲染。
- 编辑页可打开。
- 预览模式可切换。

### 12.3 手动验收

- 新建一篇文档。
- 编辑 Markdown 内容。
- 切换预览。
- 链接一个目标。
- 从文档库进入目标文件夹。
- 在目标文件夹内查看该目标相关文档。
- 回到目标详情页查看目标档案入口。
- 完成目标后创建项目总结。
- Android 真机测试键盘输入。
- Windows 桌面端测试长文编辑。

---

## 13. 风险与边界控制

### 13.1 产品臃肿风险

风险：

- 文档库如果不断扩展，会变成一个独立知识库产品。

控制：

- V0.3 只围绕目标、任务、复盘做文档沉淀。
- 暂不做复杂自由文件夹、图谱、多人协作。
- 目标文件夹是由目标天然生成的档案夹，不是用户随意创建的多层目录。
- 文档库强调“项目过程沉淀”，不是无限笔记收集。

### 13.2 编辑器复杂度风险

风险：

- 富文本编辑器会增加大量跨平台复杂度。

控制：

- V0.3 只做 Markdown 原文编辑和预览。
- 不做 WYSIWYG。
- 不做复杂块编辑器。

### 13.3 移动端长文体验风险

风险：

- 手机上写长文天然不如桌面舒服。

控制：

- 移动端先保证可编辑、可预览、不卡顿。
- 后续可支持导出 Markdown，在外部编辑器继续编辑。
- Windows 桌面端可以后续增强为左右分栏。

---

## 14. 后续扩展

V0.3 完成后，后续可以逐步增强：

- Markdown 导出为 `.md`。
- 项目总结导出。
- 全文搜索。
- 标签系统。
- 自定义文件夹/集合。
- 文档链接任务。
- 文档链接复盘。
- Nobi 帮用户生成复盘提示。
- AI 根据任务历史生成总结草案。
- 周复盘/月复盘自动汇总到文档库。

---

## 15. 当前结论

文档库应作为 Evoly 的核心模块推进，而不是目标详情页里的附属笔记。

V0.3 的优先级应明确调整为：

```text
底部独立文档库
        ↓
目标文件夹列表
        ↓
目标文件夹详情
        ↓
Markdown 编辑与预览
        ↓
项目完成后沉淀总结
```

这条路线更符合 Evoly 的长期定位：

```text
不只是完成目标，而是把完成目标的过程变成可复用的成长资产。
```

---

## 16. V0.3.0-alpha 当前落地状态

已完成：

- 新增 `lib/features/documents/` 文档库模块。
- 新增 `documents`、`document_links` SQLite 表，数据库版本升级到 `3`。
- 新增 `DocumentRepository` 与 SQLite 实现。
- 新增底部一级入口“文档库”，底部导航调整为：

```text
今日 / 目标 / 文档库 / 统计 / 设置
```

- 新增文档库首页：
  - 最近更新文档列表。
  - 文档类型筛选。
  - 标题/正文基础搜索。
  - 空状态。
- 新增文档编辑页：
  - 新建文档。
  - 编辑标题。
  - 编辑 Markdown 正文。
  - 选择文档类型。
  - 保存文档。
  - 删除文档。
  - Markdown 预览。
- V0.3.1 新增文档关联目标：
  - 文档编辑页可以选择/管理关联目标。
  - 保存文档时同步写入 `document_links`。
  - 目标详情页展示最近 3 篇关联文档。
  - 目标详情页可以直接新建一篇已关联当前目标的项目文档。
- V0.3.2 新增项目总结模板：
  - 目标详情页可以创建项目总结草稿。
  - 自动生成 `projectSummary` Markdown 文档。
  - 自动带入目标名称、描述、进度、已完成任务和未完成/延期任务。
  - 自动关联当前目标。
  - 如果已存在同名项目总结，则直接打开已有文档，避免重复创建。
- V0.3.3 设计修正：目标文件夹式文档库：
  - 文档库首页应从“文档列表”调整为“目标文件夹列表”。
  - 每个目标天然对应一个文件夹。
  - 文件夹内承载该目标涉及的过程文档、复盘、项目总结和知识记录。
  - 文档类型降级为文件夹内标签，不再作为文档库一级组织方式。
  - 当前 `document_links` 结构可以继续复用，不需要新增自由文件夹表。

待继续：

- 文档库首页改为目标文件夹列表。
- 新增目标文件夹详情页。
- 目标详情页改为目标档案入口。
- 任务链接放到 V0.3.1 或后续阶段。
- Markdown 导出。

验证状态：

- `flutter analyze` 通过。
- `flutter test` 通过。
- `flutter build apk --debug` 通过。
- C++ ATL 组件已安装，`atlbase.h` 已找到。
- `flutter build windows` 通过。

---

## 17. 2026-06-30 开发进度更新：目标档案夹最小闭环已落地

### 本次完成

- 文档库首页已从“普通文档列表”调整为“目标文件夹优先”的结构。
- 每个目标天然对应一个目标档案夹，不额外引入自由文件夹表。
- 文档库首页现在展示：
  - 目标文件夹列表；
  - 最近文档；
  - 未归档文档；
  - 搜索目标文件夹或文档。
- 新增目标档案夹详情页：
  - 展示目标标题、描述、进度、子任务数、文档数；
  - 展示该目标下的全部关联文档；
  - 支持在文件夹内新建过程记录；
  - 支持在文件夹内创建项目总结草稿。
- 目标详情页中的“关联文档”升级为“目标档案”入口：
  - 保留最近关联文档预览；
  - 新增“打开文件夹”入口；
  - 新建过程记录会自动关联当前目标；
  - 创建项目总结会自动生成 Markdown 模板并关联当前目标。
- 项目总结 Markdown 模板已抽成共享方法，目标详情页和目标档案夹详情页复用同一套生成逻辑。
- SQLite 查询层新增：
  - `findGoalFolders({String? query})`：按目标聚合文档数量、最新文档和更新时间；
  - `findUnfiled({String? query})`：查询未关联目标的文档。

### 涉及代码

- `lib/features/documents/presentation/document_library_page.dart`
- `lib/features/documents/presentation/goal_document_folder_page.dart`
- `lib/features/documents/domain/document_folder_summary.dart`
- `lib/features/documents/data/document_repository.dart`
- `lib/features/documents/data/sqlite_document_repository.dart`
- `lib/features/documents/application/project_summary_template.dart`
- `lib/features/goals/presentation/goal_detail_page.dart`
- `lib/app/router.dart`

### 验证状态

- `flutter analyze`：通过。
- `flutter test`：通过。
- `flutter build apk --debug`：通过。
- `flutter build windows`：通过。

### 当前阶段判断

V0.3 的“文档库最小闭环”已经从单纯 Markdown 文档能力，推进到更符合 Evoly 定位的 **目标档案夹系统**：

```text
目标 → 目标档案夹 → 过程记录 / 项目总结 / 复盘文档 / 知识沉淀
```

这意味着 V0.3 主线已经基本成型，后续不应优先扩展复杂知识库能力，而应继续打磨“目标档案夹”内的真实使用体验。

### 下一步建议

优先级从高到低：

1. 文档编辑页中的“已关联目标”点击后，进入对应目标档案夹，而不是只做静态展示。
2. 文档编辑页支持自动保存，和目标/任务编辑体验保持一致。
3. 目标档案夹详情页增加轻量文档类型筛选，但只作为文件夹内筛选，不回到类型一级导航。
4. 增加“从目标完成页引导写总结”的入口，让项目总结更自然地进入用户流程。
5. 增加 Markdown 导出，为后续外部沉淀和备份做准备。
