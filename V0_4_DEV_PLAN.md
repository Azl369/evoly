# Evoly V0.4 开发计划：本地优先数据同步与云端备份

## 0. 已确认技术决策

V0.4 同步方案已确认采用以下边界：

```text
后端：Supabase
账号：需要账号登录
冲突策略：初版接受“最新修改覆盖旧修改”
首批平台：Android + Windows
产品定位：本地优先，多端同步，不做多人协作
```

这意味着 V0.4 的主目标不是设计复杂协同系统，而是先做出稳定的个人多端同步闭环：

- 使用 Supabase Auth 作为账号系统。
- 使用 Supabase PostgreSQL 作为远端实体存储。
- 使用 Supabase Row Level Security 按 `user_id` 隔离数据。
- 客户端继续以 SQLite 为本地主数据源。
- 初版冲突处理采用 Last Write Wins，依据 `updated_at` / 远端 revision 判断最新版本。
- 为降低误覆盖风险，被覆盖版本可写入本地 `sync_conflicts` 或同步历史表，先不做复杂冲突处理 UI。

### 0.1 你需要准备的 Supabase 信息

开始实现前，需要准备：

- 一个 Supabase project。
- Project URL。
- Publishable key。
- 开启 Email + Password 登录。
- 确认是否允许邮箱注册。
- 一套用于开发联调的测试账号。

敏感配置不要直接写死进仓库。V0.4 建议使用：

```text
--dart-define=SUPABASE_URL=...
--dart-define=SUPABASE_PUBLISHABLE_KEY=...
```

初版账号登录建议先做邮箱 + 密码，不做 magic link、Google 登录或 Apple 登录。这样 Android 与 Windows 都能共用同一套登录 UI，避免早期处理深链回调和桌面 OAuth 回调窗口。

---

## 1. 版本定位

V0.4 的主线不是“做一个在线应用”，而是为 Evoly 增加 **本地优先的数据同步能力**。

Evoly 当前已经形成了目标、任务、提醒、统计、Coach Lite 和文档库的本地闭环。随着 Android 与 Windows 双端同时推进，下一阶段最大的产品问题会变成：

```text
我在手机上记录的目标、任务和文档，能不能在电脑上继续看、继续写？
电脑上整理的项目总结，能不能回到手机上复盘？
换设备或重装 App 时，成长数据会不会丢？
```

因此 V0.4 的一句话目标是：

```text
在不破坏本地优先体验的前提下，让 Evoly 支持可控、可靠、可恢复的个人数据同步。
```

V0.4 不追求多人协作、不做团队空间、不做实时协同编辑。它服务的是个人多设备与数据安全。

---

## 2. 产品边界

### 2.1 V0.4 要做

- 用户可选择开启同步，而不是默认上传。
- 支持一个账号下多设备同步。
- 支持 Android 与 Windows 之间同步核心数据。
- 支持离线编辑，网络恢复后自动同步。
- 支持云端备份与新设备恢复。
- 支持同步状态展示：未登录、未开启、同步中、已同步、失败。
- 支持 Last Write Wins 冲突策略：最新修改覆盖旧修改。
- 支持手动触发“立即同步”。
- 支持本地导出备份作为兜底。

### 2.2 V0.4 不做

- 不做多人协作。
- 不做实时协同编辑。
- 不做共享目标或共享文档。
- 不做复杂权限系统。
- 不做复杂冲突合并 UI。
- 不做端到端加密的完整产品化方案。
- 不做大附件同步。
- 不做后台常驻高频同步。
- 不把云端变成唯一可信数据源。

---

## 3. 当前架构现状

### 3.1 已具备的基础

当前 Evoly 已经具备同步的几个前置条件：

- 数据存储集中在 SQLite。
- 核心表普遍有 `id`、`created_at`、`updated_at`。
- 文档已支持 `deleted_at` 软删除。
- 业务模块按 Feature 分层，Repository 是比较自然的同步接入点。
- 已支持 Android 与 Windows，存在真实多端同步需求。
- 本地优先产品定位明确，离线可用是基础原则。

### 3.2 当前缺口

如果直接做云同步，会遇到以下问题：

- `goals`、`tasks`、`reminders` 目前删除多为硬删除，远端无法知道“删除”这个事实。
- 没有 `device_id`，无法区分变更来自哪台设备。
- 没有本地变更队列，无法可靠重试失败的上传。
- 没有服务端 revision / cursor，无法做增量拉取。
- 没有冲突记录表，冲突只能静默覆盖。
- 没有同步状态 UI，用户不知道数据是否安全。
- 文档 Markdown 内容较长，未来需要考虑冲突与合并策略。

### 3.3 核心结论

V0.4 不能只做“把 SQLite 上传到云端”。正确方向应该是：

```text
本地 SQLite 继续作为主数据源
  ↓
Repository 写入本地数据时同时记录变更
  ↓
Sync Engine 按变更队列上传
  ↓
服务端保存实体快照和修订号
  ↓
客户端按 cursor 拉取远端增量
  ↓
本地合并并刷新页面
```

也就是说，V0.4 要先建立 **同步协议与变更追踪能力**，再谈云端实现细节。

---

## 4. 技术架构分析

### 4.1 推荐架构：Local-first + Change Outbox + Remote Revision

推荐采用以下同步架构：

```text
Flutter App
  ├─ SQLite 本地业务表
  ├─ Sync Metadata 同步元数据表
  ├─ Sync Outbox 本地变更队列
  ├─ Sync Engine 同步引擎
  └─ Sync Repository 远端访问层

Cloud Sync Service
  ├─ Auth 账号身份
  ├─ Remote Entity Store 远端实体表
  ├─ Revision Log 服务端变更日志
  └─ Sync API 增量上传/拉取接口
```

关键原则：

- 本地写入永远先成功，UI 不等待网络。
- 所有本地写操作进入 `sync_outbox`。
- 服务端按用户维度维护递增 `revision`。
- 客户端保存 `last_pulled_revision`。
- 每次同步先 push 本地变更，再 pull 远端变更。
- 覆盖行为可检测、可记录、可诊断，不把同步失败伪装成成功。

### 4.2 同步对象范围

V0.4 优先同步用户核心成长资产：

| 数据类型 | 是否 V0.4 同步 | 原因 |
| --- | --- | --- |
| goals | 是 | 目标是核心主数据 |
| tasks | 是 | 今日行动与目标进度依赖任务 |
| reminders | 是，但本地重调度 | 提醒规则可同步，系统通知必须每端重新注册 |
| documents | 是 | 文档库是 V0.3 核心资产 |
| document_links | 是 | 保证目标档案夹关系完整 |
| settings | 部分 | 仅同步产品偏好，不同步设备相关配置 |
| stats | 否 | 统计应由任务/目标重新计算 |
| coach insight | 否 | Coach 是本地规则计算结果，不需要同步 |
| notification runtime state | 否 | `fired_at` 等运行态按设备处理 |

### 4.3 数据同步层级

V0.4 建议分三层：

#### 第一层：备份恢复

目标是“不丢数据”。

- 手动导出本地数据库或 JSON。
- 手动导入恢复。
- 可作为云同步失败时的兜底。

#### 第二层：单向云备份

目标是“换设备能恢复”。

- 本地数据上传到云端。
- 新设备可拉取完整数据。
- 不处理多设备同时编辑冲突。

#### 第三层：双向增量同步

目标是“手机和电脑都能继续编辑”。

- 每端记录本地变更。
- 云端保存实体最新快照和修订日志。
- 多设备按 revision 增量同步。
- 冲突进入可解释状态。

V0.4 应做到第三层的最小可用版本，但实现顺序要从第一层开始。

### 4.4 技术方案对比

#### 方案 A：直接同步 SQLite 文件

优点：

- 实现简单。
- 备份恢复很快。

缺点：

- 多端同时编辑极易覆盖。
- 无法细粒度冲突处理。
- Android 与 Windows 文件路径、锁、写入时机复杂。
- 难以做增量同步。

结论：

```text
只适合作为“手动备份”，不适合作为 Evoly 的主同步方案。
```

#### 方案 B：每张业务表加同步字段

例如给 `goals`、`tasks`、`documents` 增加：

```text
sync_status
remote_revision
deleted_at
last_synced_at
```

优点：

- 查询直观。
- 单表同步状态容易理解。

缺点：

- 每张表都要迁移。
- 同步逻辑侵入业务模型。
- 后续新增表需要重复设计。

结论：

```text
可行，但容易让业务表变脏，不是最优。
```

#### 方案 C：独立同步元数据 + 本地变更队列

新增通用同步表：

```text
sync_state
sync_entities
sync_outbox
sync_conflicts
device_identity
```

优点：

- 对业务表侵入小。
- 所有实体用统一同步协议。
- 更容易支持重试、冲突、诊断和扩展。
- 适合 Evoly 当前 Feature 分层。

缺点：

- 初始架构设计复杂一点。
- Repository 写入时必须补同步记录。

结论：

```text
推荐作为 V0.4 主方案。
```

### 4.5 后端方案：Supabase

V0.4 已确认使用 Supabase：

```text
Flutter App
  ↓ Supabase Auth
Supabase PostgreSQL
  ↓ Row Level Security
用户隔离的远端同步表
```

Supabase 负责：

- 邮箱账号登录与会话管理。
- 远端实体表存储。
- 基于 `auth.uid()` 的 Row Level Security。
- Android 与 Windows 共用同一个远端数据源。

客户端仍然负责：

- 本地 SQLite 主数据读写。
- 本地 outbox 记录。
- push / pull 同步流程。
- Last Write Wins 合并。
- 失败重试和同步状态 UI。
- 本地提醒重新调度。

#### V0.4 实施顺序

仍然建议保留“两段式”实现：

```text
先实现客户端同步协议与 Fake Remote
  ↓
再接 Supabase Auth + Supabase Remote Repository
```

原因：

- 同步最难的是本地变更追踪、合并顺序和删除语义。
- Fake Remote 能让 push/pull、outbox、revision 在不依赖网络的情况下先跑通。
- 接 Supabase 时只替换 `RemoteSyncRepository` 实现，不推翻客户端同步引擎。

---

## 5. V0.4 推荐同步协议

### 5.1 实体标识

所有可同步实体使用：

```text
entity_type + entity_id
```

示例：

```text
goal / goal-xxx
task / task-xxx
document / doc-xxx
document_link / link-xxx
reminder / reminder-xxx
```

### 5.2 本地变更流程

```text
用户修改任务
  ↓
Repository 写入 SQLite 业务表
  ↓
SyncChangeRecorder 写入 sync_outbox
  ↓
UI 立即更新
  ↓
SyncEngine 在合适时机上传变更
```

### 5.3 同步流程

推荐一轮同步按以下顺序：

```text
1. 检查账号与网络
2. 读取本地 device_id
3. 上传 sync_outbox 中未同步变更
4. 服务端返回每条变更的 remote_revision
5. 标记 outbox 已同步
6. 根据 last_pulled_revision 拉取远端增量
7. 合并远端变更到本地 SQLite
8. 更新 last_pulled_revision
9. 重新调度本地提醒
10. 通知 UI 刷新同步状态
```

### 5.4 冲突策略：Last Write Wins

V0.4 初版接受“最新修改覆盖旧修改”。

判断依据：

```text
优先比较 updated_at
  ↓
如果 updated_at 相同，比较 remote_revision
  ↓
如果仍无法判断，远端版本优先
```

实体策略：

| 实体 | V0.4 策略 |
| --- | --- |
| goal | 最新版本覆盖旧版本 |
| task | 最新版本覆盖旧版本 |
| reminder | 最新版本覆盖旧版本，并在本端重新注册通知 |
| document | 最新版本覆盖旧版本，不做三路合并 |
| document_link | 最新集合覆盖旧集合 |
| settings | 只同步允许跨端共享的设置，最新版本覆盖旧版本 |

为了降低误覆盖风险，V0.4 可以在覆盖前把旧版本写入 `sync_conflicts` 或 `sync_history`，但初版 UI 不强制展示复杂冲突处理。这样用户体验保持简单，同时保留后续恢复与诊断空间。

### 5.5 文档同步策略

Markdown 文档初版不做复杂文本合并。

规则：

```text
本地文档更新后进入 outbox
  ↓
同步时与远端比较 updated_at / revision
  ↓
较新的文档正文成为最终版本
  ↓
较旧版本可写入本地历史快照
```

V0.5+ 可再升级为“冲突副本”或三路文本合并。

---

## 6. 本地数据库改造

### 6.1 数据库版本

当前数据库版本为 `4`。V0.4 同步改造建议升级到：

```text
version: 5
```

### 6.2 新增表：device_identity

记录当前设备身份。

```sql
CREATE TABLE device_identity (
  id TEXT PRIMARY KEY,
  device_name TEXT NOT NULL,
  platform TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

说明：

- 每个安装实例生成一个稳定 `device_id`。
- 重装 App 后视为新设备。
- 用于冲突提示和同步诊断。

### 6.3 新增表：sync_state

记录全局同步状态。

```sql
CREATE TABLE sync_state (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at INTEGER NOT NULL
);
```

建议 key：

```text
sync_enabled
account_id
last_pulled_revision
last_success_at
last_error
```

### 6.4 新增表：sync_entities

记录每个实体的同步元信息。

```sql
CREATE TABLE sync_entities (
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  remote_revision INTEGER NOT NULL DEFAULT 0,
  dirty INTEGER NOT NULL DEFAULT 0,
  deleted_at INTEGER,
  last_local_change_id TEXT,
  last_synced_at INTEGER,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY(entity_type, entity_id)
);
```

### 6.5 新增表：sync_outbox

记录本地待上传变更。

```sql
CREATE TABLE sync_outbox (
  id TEXT PRIMARY KEY,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  operation TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  base_remote_revision INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0,
  last_error TEXT
);
```

`operation` 可选：

```text
upsert
delete
link
unlink
```

### 6.6 新增表：sync_conflicts

记录需要用户或系统处理的冲突。

```sql
CREATE TABLE sync_conflicts (
  id TEXT PRIMARY KEY,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  local_payload_json TEXT NOT NULL,
  remote_payload_json TEXT NOT NULL,
  reason TEXT NOT NULL,
  resolved_at INTEGER,
  created_at INTEGER NOT NULL
);
```

### 6.7 软删除改造

当前 `documents` 已有 `deleted_at`，但以下表也需要支持同步删除语义：

- `goals`
- `tasks`
- `reminders`
- `document_links`

V0.4 需要评估两种方案：

1. 给业务表增加 `deleted_at`。
2. 业务表保持硬删除，但删除前写入 `sync_entities.deleted_at` 和 `sync_outbox(delete)`。

建议：

```text
goals/tasks/reminders 增加 deleted_at，更直观也更安全。
document_links 可以用 sync_outbox 记录 unlink，但长期也建议增加 deleted_at。
```

### 6.8 Supabase 远端表建议

V0.4 初版可以采用统一远端实体表，减少每张业务表重复建同步字段的成本：

```sql
CREATE SEQUENCE sync_revision_seq;

CREATE TABLE sync_entities (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  payload_json JSONB NOT NULL,
  deleted_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL,
  device_id TEXT NOT NULL,
  revision BIGINT NOT NULL DEFAULT nextval('sync_revision_seq'),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY(user_id, entity_type, entity_id)
);

CREATE OR REPLACE FUNCTION bump_sync_revision()
RETURNS TRIGGER AS $$
BEGIN
  NEW.revision = nextval('sync_revision_seq');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER sync_entities_bump_revision
BEFORE UPDATE ON sync_entities
FOR EACH ROW
EXECUTE FUNCTION bump_sync_revision();
```

同时开启 Row Level Security：

```sql
ALTER TABLE sync_entities ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own sync entities"
ON sync_entities FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own sync entities"
ON sync_entities FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own sync entities"
ON sync_entities FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);
```

增量拉取可以先按 `revision > last_pulled_revision` 查询。后续如果需要更强审计，再增加独立 `sync_revisions` 日志表。

---

## 7. 代码架构设计

### 7.1 新增 Feature 目录

建议新增：

```text
lib/features/sync/
  domain/
    sync_change.dart
    sync_entity.dart
    sync_conflict.dart
    sync_status.dart
  data/
    sync_repository.dart
    sqlite_sync_metadata_repository.dart
    remote_sync_repository.dart
    fake_remote_sync_repository.dart
  application/
    sync_engine.dart
    sync_change_recorder.dart
    sync_scheduler.dart
    sync_conflict_resolver.dart
  presentation/
    sync_settings_section.dart
    sync_status_badge.dart
    sync_conflict_page.dart
```

### 7.2 Repository 接入点

业务 Repository 不应直接调用 HTTP。

推荐方式：

```text
GoalRepository.save()
  ↓
SQLite 写入 goals
  ↓
SyncChangeRecorder.recordUpsert(goal)
```

为了避免污染业务层，可以提供包装：

```text
SyncAwareGoalRepository
SyncAwareTaskRepository
SyncAwareDocumentRepository
```

但 V0.4 初期也可以先在 SQLite Repository 内显式记录变更，等模式稳定后再抽象。

### 7.3 Sync Engine

`SyncEngine` 核心职责：

- 判断是否允许同步。
- 执行 push/pull。
- 处理重试。
- 写入同步状态。
- 合并远端变更。
- 调用提醒重新调度。

接口建议：

```dart
abstract class SyncEngine {
  Future<SyncResult> syncNow();
  Future<SyncStatus> loadStatus();
  Future<void> enableSync();
  Future<void> disableSync();
}
```

### 7.4 Remote Sync Repository

远端接口不直接暴露业务 Repository，而是暴露同步协议：

```dart
abstract class RemoteSyncRepository {
  Future<PushResult> pushChanges(List<SyncChange> changes);
  Future<PullResult> pullChanges({required int sinceRevision});
}
```

这样无论远端实现是 Fake Remote 还是 Supabase，都可以复用客户端同步引擎。

---

## 8. UI 与用户体验

### 8.1 设置页新增同步入口

设置页新增：

```text
数据同步
  状态：未登录 / 未开启 / 已同步 / 同步中 / 失败
  账号：未登录 / xxx
  设备：Android 手机 / Windows 电脑
  最近同步：刚刚 / 10 分钟前 / 从未同步
  [登录 / 退出登录]
  [开启同步]
  [立即同步]
  [导出本地备份]
```

### 8.2 首页同步状态

V0.4 不建议在首页常驻复杂同步 UI。

建议仅在以下情况展示轻提示：

- 首次开启同步。
- 同步失败。
- 当前设备刚从云端恢复数据。
- 本端数据被更新的远端版本覆盖。

### 8.3 覆盖提示

V0.4 使用最新修改覆盖旧修改，文案要轻、不制造焦虑：

```text
已同步来自 Windows 的较新修改。
```

仅在发生较大范围覆盖时提示，普通同步不打扰用户。诊断记录留在本地，不在初版做复杂冲突处理页。

### 8.4 动画与性能要求

同步不能破坏当前的流畅体验。

约束：

- 同步任务不阻塞 UI 线程。
- 大量远端变更合并时分批写入。
- 同步状态变更只刷新小组件，不刷新整页。
- 文档大文本同步不在用户输入时频繁上传。
- App 启动时不强制等待同步完成。

---

## 9. 安全与隐私

Evoly 是个人成长产品，数据包含目标、任务、复盘和文档，隐私级别很高。

V0.4 必须坚持：

- 同步默认关闭。
- 开启同步前明确说明会上传哪些数据。
- 传输必须使用 HTTPS。
- 本地可随时关闭同步。
- 关闭同步不删除本地数据。
- 支持导出本地备份。
- 后续如做端到端加密，需要作为 V0.5+ 独立专题，不塞进 V0.4。

V0.4 可先实现：

```text
传输加密 + 服务端账号隔离 + 本地可导出
```

暂不承诺：

```text
端到端加密 + 零知识服务端
```

---

## 10. 分阶段研发计划

### Phase 1：同步协议与本地元数据

目标：

```text
先让本地数据库具备“知道哪些数据变了”的能力。
```

任务：

- 数据库版本升级到 `5`。
- 新增 `device_identity`。
- 新增 `sync_state`。
- 新增 `sync_entities`。
- 新增 `sync_outbox`。
- 新增 `sync_conflicts`。
- 定义 `SyncChange`、`SyncEntity`、`SyncStatus`。
- 实现 `SyncChangeRecorder`。
- 在 Goal / Task / Document / DocumentLink 写入处记录 outbox。

验收：

- 新建目标会产生 `sync_outbox(upsert goal)`。
- 修改任务会产生 `sync_outbox(upsert task)`。
- 删除文档会产生 `sync_outbox(delete document)` 或软删除变更。
- 重启 App 后 outbox 仍存在。

### Phase 2：本地 Fake Remote 跑通同步引擎

目标：

```text
不接真实云服务，先验证同步协议正确。
```

任务：

- 实现 `FakeRemoteSyncRepository`。
- Fake Remote 可用本地 JSON 文件或内存模拟。
- 实现 `SyncEngine.syncNow()`。
- 支持 push 本地 outbox。
- 支持 pull 远端 revision。
- 支持 `last_pulled_revision`。
- 支持 Last Write Wins 合并验证。

验收：

- 本地修改可 push 到 fake remote。
- fake remote 中新增变更可 pull 回本地。
- 重复同步不会重复创建数据。
- 无网络/远端失败时 outbox 不丢失。

### Phase 3：真实云端最小闭环

目标：

```text
实现账号登录后的真实云同步。
```

任务：

- 创建 Supabase 项目。
- 配置 Supabase Auth 邮箱登录。
- 创建 `sync_entities` 远端表。
- 配置 Row Level Security。
- 实现 Supabase 版 `RemoteSyncRepository`。
- 实现远端 revision sequence / trigger。
- 客户端接入 Supabase Auth session。

验收：

- Windows 创建目标，Android 可同步看到。
- Android 完成任务，Windows 可同步看到。
- 文档内容可跨端同步。
- 新设备登录后可恢复目标、任务和文档。

### Phase 4：Last Write Wins 与删除安全

目标：

```text
按“最新修改覆盖旧修改”完成多端合并，并保证删除可同步、可追踪。
```

任务：

- 为目标/任务/提醒补齐删除同步策略。
- 为 document_links 补齐删除或 unlink 同步策略。
- 实现 Last Write Wins 合并器。
- 覆盖旧版本前写入本地快照或 `sync_conflicts` 记录。
- 远端删除同步到本地软删除。
- 同步完成后重新计算目标进度。
- 同步完成后重新注册本地提醒。

验收：

- 两端同时编辑同一实体，最新修改成为最终版本。
- 被覆盖版本有本地诊断记录或历史快照。
- 删除目标可同步到另一端。
- 删除目标前关联任务/文档处理符合预期。
- 删除任务、提醒、文档链接不会在下次同步中复活。

### Phase 5：同步设置页与用户可控体验

目标：

```text
让用户知道同步在做什么，并能控制它。
```

任务：

- 设置页新增“数据同步”区域。
- 显示同步状态。
- 显示最近同步时间。
- 显示当前设备名。
- 支持开启/关闭同步。
- 支持立即同步。
- 支持导出本地备份。
- 支持同步失败重试。

验收：

- 用户不开启同步时，App 完全本地运行。
- 开启同步后可看到同步状态。
- 同步失败有明确提示。
- 关闭同步不会删除本地数据。

### Phase 6：稳定性、测试与发布

目标：

```text
同步能力达到可以长期承载用户真实数据的最低稳定标准。
```

任务：

- 补充单元测试。
- 补充 fake remote 集成测试。
- 补充 Android / Windows 手动验收脚本。
- 测试断网、重连、重复同步。
- 测试大文档同步。
- 测试 1000 条任务的同步性能。
- 更新 README。
- 更新 ARCHITECTURE_DESIGN。
- 升级版本号到 `0.4.0+1`。

验收：

- `flutter analyze` 通过。
- `flutter test` 通过。
- `flutter build apk --debug` 通过。
- `flutter build windows` 通过。
- Android 与 Windows 双端同步核心数据通过。

---

## 11. 测试计划

### 11.1 单元测试

- `SyncChangeRecorder` 正确记录 upsert。
- `SyncChangeRecorder` 正确记录 delete。
- `SyncEngine` push 成功后清理 outbox。
- `SyncEngine` push 失败后保留 outbox。
- `SyncEngine` 根据 revision 拉取增量。
- Last Write Wins 合并逻辑正确。
- 覆盖旧版本前可写入本地快照或诊断记录。
- Supabase remote repository 正确携带当前登录用户 session。

### 11.2 集成测试

- 设备 A 创建目标，设备 B 拉取。
- 设备 A 创建任务，设备 B 拉取。
- 设备 B 完成任务，设备 A 拉取。
- 设备 A 创建文档，设备 B 拉取。
- 设备 A 删除任务，设备 B 同步删除。
- 两端同时修改同一文档，最新修改覆盖旧修改。
- 未登录状态不能读写远端数据。
- Supabase RLS 阻止跨账号读取数据。

### 11.3 手动验收

- Windows 开启同步并创建目标。
- Android 登录同账号并恢复数据。
- Android 离线新增任务，恢复网络后同步。
- Windows 修改文档，Android 查看最新内容。
- 两端同时编辑同一文档，确认最新修改成为最终版本。
- 关闭同步后，确认本地数据仍可正常使用。

---

## 12. 风险与控制

### 12.1 数据丢失风险

风险：

- 同步 bug 可能覆盖用户真实数据。

控制：

- V0.4 必须先做本地导出备份。
- 初版接受最新修改覆盖旧修改，但覆盖前尽量保留本地快照。
- 删除走软删除或 tombstone。
- 每次破坏性迁移前备份数据库。

### 12.2 产品复杂度风险

风险：

- 同步引入账号、网络、覆盖、错误状态，可能让 Evoly 变复杂。

控制：

- 设置页集中管理同步。
- 首页只在必要时轻提示。
- V0.4 不做多人协作。
- 默认保持本地优先。

### 12.3 动画卡顿风险

风险：

- 同步合并大量数据时影响页面流畅度。

控制：

- 同步在后台执行。
- 分批写入。
- UI 只订阅同步状态摘要。
- 大文档上传使用节流，不在输入时高频触发。

### 12.4 后端锁定风险

风险：

- 过早绑定某个后端服务，后续迁移困难。

控制：

- 客户端只依赖 `RemoteSyncRepository` 抽象。
- V0.4 先用 fake remote 验证协议。
- 后端实现可替换；V0.4 已确认第一实现是 Supabase。

---

## 13. V0.4 完成定义

满足以下条件可以认为 V0.4 完成：

- App 保持本地优先，不登录也能完整使用。
- 用户可在设置页开启同步。
- 本地数据变更会进入同步队列。
- Sync Engine 可执行 push / pull。
- Android 与 Windows 可同步：
  - goals
  - tasks
  - reminders 规则
  - documents
  - document_links
- 新设备可从云端恢复核心数据。
- 两端同时修改时，最新修改覆盖旧修改。
- 同步失败可重试。
- 用户可导出本地备份。
- README 和架构文档更新到 V0.4。
- `flutter analyze`、`flutter test`、`flutter build apk --debug`、`flutter build windows` 通过。

---

## 14. 建议优先级

如果开发资源有限，V0.4 应按以下顺序推进：

1. 本地备份导出。
2. `sync_outbox` 与变更记录。
3. Fake Remote 跑通 push/pull。
4. Supabase Auth + RLS + 远端实体表。
5. Android + Windows 真实跨端同步。
6. 设置页同步状态。
7. 删除同步与恢复体验打磨。

不要一开始就做完整账号体系、订阅系统或多人协作。同步架构一旦做错，后面所有数据能力都会变得脆弱；V0.4 最重要的是把地基打稳。

---

## 15. 当前结论

V0.4 应该被定义为 Evoly 从“单机本地成长工具”走向“个人多端成长系统”的基础版本。

它不是云端化，也不是协作化，而是：

```text
本地优先
多端可达
数据可恢复
最新覆盖
用户可控制
```

这条路线最符合 Evoly 的长期定位：用户的目标、任务、复盘和文档不是临时数据，而是个人成长资产。V0.4 的使命，就是让这些资产可以安全地跨设备延续。
