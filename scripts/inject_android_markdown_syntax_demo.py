import argparse
import sqlite3
import tempfile
from datetime import datetime, timedelta
from pathlib import Path

from inject_android_notification_demo import (
    DEFAULT_ADB,
    DEFAULT_PACKAGE,
    pull_database,
    push_database,
    run_adb,
)


DEMO_PREFIX = "demo-md-syntax-"


MARKDOWN_SYNTAX_CONTENT = r"""# Markdown 语法压力测试

> 这篇文档用于测试 Evoly 当前 Markdown 预览能力。点一下预览区域可以进入编辑模式。

## 1. 基础文本

这是普通段落，支持 **加粗**、*斜体*、~~删除线~~、`inline code`。

也可以写链接：[Flutter Markdown](https://pub.dev/packages/flutter_markdown)。

---

## 2. 待办事项列表

- [x] 已完成：打开文档默认看到预览
- [x] 已完成：点击预览进入编辑模式
- [ ] 待测试：任务列表 checkbox 是否被渲染
- [ ] 待测试：长文档滚动是否顺滑

## 3. 普通列表与嵌套列表

1. 第一层：文档库
   - 目标档案夹
   - 最近文档
   - 未归档文档
2. 第一层：目标详情
   - 打开目标档案夹
   - 创建项目总结

## 4. 表格

| 语法 | 预期效果 | 当前观察 |
| --- | --- | --- |
| 标题 | 分层显示 | 待观察 |
| 待办列表 | checkbox 或列表 | 待观察 |
| 表格 | 表格排版 | 待观察 |
| 数学公式 | 数学排版渲染 | 待观察 |

## 5. 代码块

```dart
class EvolyNote {
  const EvolyNote({
    required this.title,
    required this.markdown,
  });

  final String title;
  final String markdown;
}
```

## 6. 数学公式写法

行内公式：$E = mc^2$，以及 $a^2 + b^2 = c^2$。

块级公式：

$$
\sum_{i=1}^{n} i = \frac{n(n + 1)}{2}
$$

> 如果公式无法解析，会以普通文本降级显示。常见 TeX 写法应该可以直接渲染。

## 7. 引用与复盘

> 文档库不是为了收藏一切，而是为了把目标推进过程沉淀成可复用资产。

## 8. 下一步观察

- Android 上长文档预览滚动是否舒服。
- 从预览切到编辑是否自然。
- 编辑框去掉“Markdown 正文”标签后是否更清爽。
- 任务列表和数学公式是否需要后续增强渲染能力。
"""


def main() -> None:
    args = parse_args()
    adb = Path(args.adb)
    if not adb.exists():
        raise SystemExit(f"找不到 adb：{adb}")

    device_args = ["-s", args.device] if args.device else []

    run_adb(adb, device_args, ["shell", "am", "force-stop", args.package])

    with tempfile.TemporaryDirectory(
        prefix="evoly_android_markdown_syntax_demo_",
        ignore_cleanup_errors=True,
    ) as temp_dir:
        local_db = Path(temp_dir) / "evoly.db"
        pull_database(adb, device_args, args.package, local_db)
        inject_markdown_syntax_demo(local_db)
        prepare_database_for_push(local_db)
        print_counts(local_db)
        push_database(adb, device_args, args.package, local_db)

    print("已注入 Android Markdown 语法测试文档。")
    print("请重新打开 Evoly，进入「文档库」→「Markdown 语法测试」目标档案夹查看。")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Inject a Markdown syntax demo document into Evoly Android SQLite database.",
    )
    parser.add_argument(
        "--device",
        help="adb 设备 ID，例如 192.168.31.14:43191。为空时使用当前默认设备。",
    )
    parser.add_argument(
        "--package",
        default=DEFAULT_PACKAGE,
        help=f"Android applicationId，默认 {DEFAULT_PACKAGE}。",
    )
    parser.add_argument(
        "--adb",
        default=DEFAULT_ADB,
        help=f"adb 路径，默认 {DEFAULT_ADB}。",
    )
    return parser.parse_args()


def inject_markdown_syntax_demo(db_path: Path) -> None:
    now = datetime.now()
    today = datetime(now.year, now.month, now.day)
    goal_id = f"{DEMO_PREFIX}goal"
    document_id = f"{DEMO_PREFIX}document"

    with sqlite3.connect(db_path) as connection:
        connection.execute("PRAGMA foreign_keys = ON")
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
            "DELETE FROM tasks WHERE id LIKE ? OR goal_id LIKE ?",
            (f"{DEMO_PREFIX}%", f"{DEMO_PREFIX}%"),
        )
        connection.execute(
            "DELETE FROM goals WHERE id LIKE ?",
            (f"{DEMO_PREFIX}%",),
        )

        connection.execute(
            """
            INSERT INTO goals (
              id, title, description, type, priority, status,
              start_date, due_date, progress, created_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                goal_id,
                "Markdown 语法测试",
                "用于测试待办事项列表、表格、代码块、引用和数学公式写法。",
                "oneTime",
                "medium",
                "inProgress",
                encode_datetime(today),
                encode_datetime(today + timedelta(days=7)),
                0.3,
                encode_datetime(now),
                encode_datetime(now),
            ),
        )

        connection.execute(
            """
            INSERT INTO documents (
              id, title, content_markdown, type,
              created_at, updated_at, deleted_at
            )
            VALUES (?, ?, ?, ?, ?, ?, NULL)
            """,
            (
                document_id,
                "Markdown 语法压力测试：任务列表、表格、代码块与公式",
                MARKDOWN_SYNTAX_CONTENT,
                "knowledge",
                encode_datetime(now),
                encode_datetime(now),
            ),
        )

        connection.execute(
            """
            INSERT INTO document_links (
              id, document_id, target_type, target_id, created_at
            )
            VALUES (?, ?, ?, ?, ?)
            """,
            (
                f"{document_id}-goal-{goal_id}",
                document_id,
                "goal",
                goal_id,
                encode_datetime(now),
            ),
        )

        connection.commit()


def prepare_database_for_push(db_path: Path) -> None:
    with sqlite3.connect(db_path, timeout=10) as connection:
        connection.execute("PRAGMA busy_timeout = 5000")
        connection.execute("PRAGMA wal_checkpoint(TRUNCATE)")
        try:
            connection.execute("PRAGMA journal_mode = DELETE")
        except sqlite3.OperationalError:
            pass
        connection.commit()

    for suffix in ("-wal", "-shm"):
        optional_path = db_path.with_name(f"{db_path.name}{suffix}")
        if optional_path.exists():
            try:
                optional_path.unlink()
            except PermissionError:
                pass


def print_counts(db_path: Path) -> None:
    with sqlite3.connect(db_path) as connection:
        counts = {
            "goals": connection.execute(
                "SELECT COUNT(*) FROM goals WHERE id LIKE ?",
                (f"{DEMO_PREFIX}%",),
            ).fetchone()[0],
            "documents": connection.execute(
                "SELECT COUNT(*) FROM documents WHERE id LIKE ?",
                (f"{DEMO_PREFIX}%",),
            ).fetchone()[0],
            "links": connection.execute(
                "SELECT COUNT(*) FROM document_links WHERE document_id LIKE ?",
                (f"{DEMO_PREFIX}%",),
            ).fetchone()[0],
        }

    print(
        "本次写入："
        f"{counts['goals']} 个目标，"
        f"{counts['documents']} 篇 Markdown 语法测试文档，"
        f"{counts['links']} 条文档关联。"
    )


def encode_datetime(value: datetime) -> int:
    return int(value.timestamp() * 1000)


if __name__ == "__main__":
    main()
