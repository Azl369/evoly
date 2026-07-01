import argparse
import os
import shutil
import sqlite3
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path


DEMO_PREFIX = "demo-v031-"


@dataclass(frozen=True)
class DemoGoal:
    id: str
    title: str
    description: str
    priority: str
    status: str
    due_offset_days: int
    progress: float


@dataclass(frozen=True)
class DemoTask:
    id: str
    goal_id: str
    title: str
    priority: str
    status: str
    estimated_minutes: int
    due_offset_days: int
    completed: bool = False


@dataclass(frozen=True)
class DemoDocument:
    id: str
    title: str
    content_markdown: str
    type: str
    updated_offset_hours: int
    linked_goal_ids: tuple[str, ...] = ()


def main() -> None:
    args = parse_args()
    db_path = resolve_db_path(args.db)

    if not db_path.exists():
        raise SystemExit(f"数据库不存在：{db_path}。请先打开 Evoly 一次初始化数据库。")

    if args.backup:
        backup_path = backup_database(db_path)
        print(f"已备份数据库：{backup_path}")

    reset_demo_data(db_path)
    print(f"已重置 Evoly V0.3 文档库演示数据：{db_path}")
    print("包含：3 个演示目标、7 个子任务、6 篇 Markdown 文档、5 条目标关联。")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Reset Evoly local SQLite demo data for V0.3 document library testing.",
    )
    parser.add_argument(
        "--db",
        help="SQLite 数据库路径。默认使用 %%APPDATA%%\\Evoly\\evoly.db。",
    )
    parser.add_argument(
        "--backup",
        action="store_true",
        help="重置前备份当前数据库。",
    )
    return parser.parse_args()


def resolve_db_path(value: str | None) -> Path:
    if value:
        return Path(value).expanduser().resolve()

    app_data = os.environ.get("APPDATA")
    if not app_data:
        raise SystemExit("找不到 APPDATA 环境变量，请使用 --db 指定数据库路径。")

    return Path(app_data) / "Evoly" / "evoly.db"


def backup_database(db_path: Path) -> Path:
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup_path = db_path.with_name(f"evoly.backup-before-v03-doc-demo-{timestamp}.db")
    shutil.copy2(db_path, backup_path)
    return backup_path


def reset_demo_data(db_path: Path) -> None:
    now = datetime.now()
    today = datetime(now.year, now.month, now.day)
    created_at = encode_datetime(now - timedelta(days=3))

    goals = build_goals()
    tasks = build_tasks()
    documents = build_documents()

    connection = sqlite3.connect(db_path)
    try:
        connection.execute("PRAGMA foreign_keys = ON")
        ensure_document_schema(connection)
        connection.execute("BEGIN")
        connection.execute(
            "DELETE FROM document_links WHERE document_id LIKE ? OR target_id LIKE ?",
            (f"{DEMO_PREFIX}%", f"{DEMO_PREFIX}%"),
        )
        connection.execute(
            "DELETE FROM documents WHERE id LIKE ?",
            (f"{DEMO_PREFIX}%",),
        )
        connection.execute(
            "DELETE FROM reminders WHERE target_id LIKE ?",
            (f"{DEMO_PREFIX}%",),
        )
        connection.execute(
            "DELETE FROM tasks WHERE id LIKE ? OR goal_id LIKE ?",
            (f"{DEMO_PREFIX}%", f"{DEMO_PREFIX}%"),
        )
        connection.execute(
            "DELETE FROM goals WHERE id LIKE ?",
            (f"{DEMO_PREFIX}%",),
        )

        for goal in goals:
            due_date = today + timedelta(days=goal.due_offset_days)
            connection.execute(
                """
                INSERT INTO goals (
                  id, title, description, type, priority, status,
                  start_date, due_date, progress, created_at, updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    goal.id,
                    goal.title,
                    goal.description,
                    "longTerm",
                    goal.priority,
                    goal.status,
                    encode_datetime(today - timedelta(days=7)),
                    encode_datetime(due_date),
                    goal.progress,
                    created_at,
                    encode_datetime(now),
                ),
            )

        for task in tasks:
            due_at = today + timedelta(days=task.due_offset_days)
            due_at = due_at.replace(hour=18, minute=30)
            completed_at = encode_datetime(now - timedelta(hours=2)) if task.completed else None
            connection.execute(
                """
                INSERT INTO tasks (
                  id, goal_id, title, description, priority, status,
                  estimated_minutes, due_date_time, completed_at, created_at, updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    task.id,
                    task.goal_id,
                    task.title,
                    "",
                    task.priority,
                    task.status,
                    task.estimated_minutes,
                    encode_datetime(due_at),
                    completed_at,
                    created_at,
                    encode_datetime(now),
                ),
            )

        for document in documents:
            updated_at = now - timedelta(hours=document.updated_offset_hours)
            connection.execute(
                """
                INSERT INTO documents (
                  id, title, content_markdown, type,
                  created_at, updated_at, deleted_at
                )
                VALUES (?, ?, ?, ?, ?, ?, NULL)
                """,
                (
                    document.id,
                    document.title,
                    document.content_markdown,
                    document.type,
                    created_at,
                    encode_datetime(updated_at),
                ),
            )

            for goal_id in document.linked_goal_ids:
                connection.execute(
                    """
                    INSERT INTO document_links (
                      id, document_id, target_type, target_id, created_at
                    )
                    VALUES (?, ?, ?, ?, ?)
                    """,
                    (
                        f"{document.id}-goal-{goal_id}",
                        document.id,
                        "goal",
                        goal_id,
                        encode_datetime(updated_at),
                    ),
                )
        connection.commit()
    finally:
        connection.close()


def ensure_document_schema(connection: sqlite3.Connection) -> None:
    connection.execute(
        """
        CREATE TABLE IF NOT EXISTS documents (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          content_markdown TEXT NOT NULL DEFAULT '',
          type TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER
        )
        """
    )
    connection.execute(
        """
        CREATE TABLE IF NOT EXISTS document_links (
          id TEXT PRIMARY KEY,
          document_id TEXT NOT NULL,
          target_type TEXT NOT NULL,
          target_id TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE CASCADE
        )
        """
    )
    connection.execute(
        "CREATE INDEX IF NOT EXISTS idx_documents_updated_at ON documents(updated_at)"
    )
    connection.execute("CREATE INDEX IF NOT EXISTS idx_documents_type ON documents(type)")
    connection.execute(
        "CREATE INDEX IF NOT EXISTS idx_documents_deleted_at ON documents(deleted_at)"
    )
    connection.execute(
        "CREATE INDEX IF NOT EXISTS idx_document_links_document_id ON document_links(document_id)"
    )
    connection.execute(
        "CREATE INDEX IF NOT EXISTS idx_document_links_target ON document_links(target_type, target_id)"
    )


def build_goals() -> list[DemoGoal]:
    return [
        DemoGoal(
            id="demo-v031-goal-docs",
            title="V0.3 演示：文档库最小闭环",
            description="用于测试文档列表、Markdown 预览、目标详情关联文档。",
            priority="high",
            status="inProgress",
            due_offset_days=10,
            progress=0.55,
        ),
        DemoGoal(
            id="demo-v031-goal-android",
            title="V0.3 演示：Android 体验打磨",
            description="用于测试一篇文档关联到具体技术目标。",
            priority="medium",
            status="inProgress",
            due_offset_days=18,
            progress=0.4,
        ),
        DemoGoal(
            id="demo-v031-goal-brand",
            title="V0.3 演示：Evoly 品牌改版",
            description="用于测试品牌设计记录和未完成目标下的文档沉淀。",
            priority="low",
            status="notStarted",
            due_offset_days=30,
            progress=0.1,
        ),
    ]


def build_tasks() -> list[DemoTask]:
    return [
        DemoTask(
            id="demo-v031-task-docs-01",
            goal_id="demo-v031-goal-docs",
            title="完成文档库首页 smoke test",
            priority="high",
            status="completed",
            estimated_minutes=30,
            due_offset_days=0,
            completed=True,
        ),
        DemoTask(
            id="demo-v031-task-docs-02",
            goal_id="demo-v031-goal-docs",
            title="测试文档关联目标",
            priority="high",
            status="pending",
            estimated_minutes=40,
            due_offset_days=0,
        ),
        DemoTask(
            id="demo-v031-task-docs-03",
            goal_id="demo-v031-goal-docs",
            title="设计项目总结模板入口",
            priority="medium",
            status="pending",
            estimated_minutes=45,
            due_offset_days=1,
        ),
        DemoTask(
            id="demo-v031-task-android-01",
            goal_id="demo-v031-goal-android",
            title="检查 120Hz 动画观感",
            priority="medium",
            status="completed",
            estimated_minutes=20,
            due_offset_days=0,
            completed=True,
        ),
        DemoTask(
            id="demo-v031-task-android-02",
            goal_id="demo-v031-goal-android",
            title="验证后台通知测试数据",
            priority="medium",
            status="pending",
            estimated_minutes=30,
            due_offset_days=0,
        ),
        DemoTask(
            id="demo-v031-task-brand-01",
            goal_id="demo-v031-goal-brand",
            title="整理 Nobi 形象方向",
            priority="low",
            status="pending",
            estimated_minutes=35,
            due_offset_days=2,
        ),
        DemoTask(
            id="demo-v031-task-brand-02",
            goal_id="demo-v031-goal-brand",
            title="记录图标 B 方案落地过程",
            priority="low",
            status="pending",
            estimated_minutes=25,
            due_offset_days=3,
        ),
    ]


def build_documents() -> list[DemoDocument]:
    return [
        DemoDocument(
            id="demo-v031-doc-library-note",
            title="V0.3 文档库开发记录",
            type="projectNote",
            updated_offset_hours=1,
            linked_goal_ids=("demo-v031-goal-docs",),
            content_markdown="""# V0.3 文档库开发记录

## 当前目标

让 Evoly 不只记录任务完成，还能沉淀过程、复盘和知识资产。

## 已完成

- 新增底部文档库入口。
- 支持 Markdown 编辑和预览。
- 支持文档关联目标。
- 目标详情页展示最近关联文档。

## 下一步

做项目总结模板，让完成目标后可以一键生成复盘文档。
""",
        ),
        DemoDocument(
            id="demo-v031-doc-summary-draft",
            title="文档库最小闭环项目总结草稿",
            type="projectSummary",
            updated_offset_hours=3,
            linked_goal_ids=("demo-v031-goal-docs",),
            content_markdown="""# 项目总结：文档库最小闭环

## 1. 项目目标

把文档库从规划推进到可真实保存、可预览、可关联目标的状态。

## 2. 完成结果

- 文档库成为底部一级入口。
- 文档与目标可以建立关系。
- 目标详情页可以反向看到相关文档。

## 3. 可复用经验

先做最小闭环，再做复杂编辑器体验。这个节奏是对的。
""",
        ),
        DemoDocument(
            id="demo-v031-doc-android-polish",
            title="Android 体验打磨复盘",
            type="review",
            updated_offset_hours=8,
            linked_goal_ids=("demo-v031-goal-android",),
            content_markdown="""# Android 体验打磨复盘

## 现象

新建目标/子任务时，键盘动画和弹窗动画叠加，120Hz 屏幕上会显得不够丝滑。

## 处理

- 减少弹窗内多余动画。
- 避免键盘弹出时重复 AnimatedPadding。
- 保持表单状态由 sheet 自身管理。

## 结论

移动端优先保证稳定和响应速度，再逐步做更精细的动效。
""",
        ),
        DemoDocument(
            id="demo-v031-doc-brand",
            title="Evoly 图标与 Nobi 方向记录",
            type="projectNote",
            updated_offset_hours=15,
            linked_goal_ids=("demo-v031-goal-brand",),
            content_markdown="""# Evoly 图标与 Nobi 方向记录

## App 图标

当前选择 B 方案：上升轨迹，强调成长、路径和长期推进。

## Nobi

Nobi 暂定为独立卡通形象，不和 App 图标强绑定。

## 后续

需要继续探索足够可爱、有陪伴感、但不幼稚的形象方向。
""",
        ),
        DemoDocument(
            id="demo-v031-doc-weekly-review",
            title="本周成长复盘：先把闭环跑起来",
            type="review",
            updated_offset_hours=30,
            linked_goal_ids=(),
            content_markdown="""# 本周成长复盘

## 做得好的地方

- 没有一开始就做重型知识库。
- 先把文档库最小闭环跑通。
- Android 和 Windows 构建链路都逐步补齐。

## 卡住的地方

- 文档和目标的关系需要足够轻，不要变成复杂知识图谱。

## 下周最重要的 3 件事

1. 项目总结模板。
2. 目标详情查看全部文档。
3. 文档导出 Markdown。
""",
        ),
        DemoDocument(
            id="demo-v031-doc-music-preview",
            title="Markdown 音乐谱块测试：和弦、TAB 与 ABC",
            type="knowledge",
            updated_offset_hours=6,
            linked_goal_ids=("demo-v031-goal-docs",),
            content_markdown="""# Markdown 音乐谱块测试

这篇文档用于测试 Evoly 文档预览中的音乐谱块能力：ChordPro、吉他 TAB 和 ABC 简谱。

## 1. ChordPro 和弦谱

```chordpro
{title: Evoly Practice Loop}
{key: C}
{tempo: 76}

[C]今天先做一点点
[G]不要急着证明自己
[Am]稳定推进 [F]慢慢进化
```

## 2. 吉他 TAB

```tab
title: C major scale warmup
tuning: E A D G B e
tempo: 80

e|----------------0-1-3-|
B|------------0-1-------|
G|--------0-2-----------|
D|----0-2---------------|
A|0-3-------------------|
E|----------------------|
```

## 3. ABC 简谱

```abc
X:1
T:C Major Scale
M:4/4
L:1/4
Q:1/4=80
K:C
C D E F | G A B c |
```

## 4. 混合 Markdown

- [x] 和弦谱能渲染
- [x] TAB 能渲染
- [x] ABC 能渲染
- [ ] 后续再考虑播放、节拍器或导出

数学公式仍然应该正常显示：$E = mc^2$。
""",
        ),
    ]


def encode_datetime(value: datetime) -> int:
    return int(value.timestamp() * 1000)


if __name__ == "__main__":
    main()
