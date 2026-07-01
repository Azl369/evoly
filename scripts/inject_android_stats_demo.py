import argparse
import sqlite3
import tempfile
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path

from inject_android_notification_demo import (
    DEFAULT_ADB,
    DEFAULT_PACKAGE,
    pull_database,
    push_database,
    run_adb,
)


DEMO_PREFIX = "demo-stats-"


@dataclass(frozen=True)
class DemoGoal:
    id: str
    title: str
    description: str
    priority: str
    status: str
    progress: float
    due_offset_days: int


@dataclass(frozen=True)
class DemoTask:
    id: str
    goal_id: str
    title: str
    priority: str
    status: str
    estimated_minutes: int
    due_at: datetime
    completed_at: datetime | None
    updated_at: datetime


def main() -> None:
    args = parse_args()
    adb = Path(args.adb)
    if not adb.exists():
        raise SystemExit(f"找不到 adb：{adb}")

    device_args = ["-s", args.device] if args.device else []

    run_adb(adb, device_args, ["shell", "am", "force-stop", args.package])

    with tempfile.TemporaryDirectory(
        prefix="evoly_android_stats_demo_",
        ignore_cleanup_errors=True,
    ) as temp_dir:
        local_db = Path(temp_dir) / "evoly.db"
        pull_database(adb, device_args, args.package, local_db)
        inject_stats_demo_rows(local_db)
        prepare_database_for_push(local_db)
        print_counts(local_db)
        push_database(adb, device_args, args.package, local_db)

    print("已注入 Android 统计页测试数据。")
    print("请重新打开 Evoly，进入「统计」页测试今日/本周完成、延期展开和饼图/折线图切换。")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Inject Evoly Android stats demo rows into app SQLite database.",
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


def inject_stats_demo_rows(db_path: Path) -> None:
    now = datetime.now()
    today = datetime(now.year, now.month, now.day)
    week_start = today - timedelta(days=today.weekday())
    created_at = encode_datetime(now)
    goals = build_goals()
    tasks = build_tasks(now=now, today=today, week_start=week_start)

    with sqlite3.connect(db_path) as connection:
        connection.execute("PRAGMA foreign_keys = ON")
        connection.execute("PRAGMA journal_mode = DELETE")
        connection.execute("BEGIN")
        connection.execute(
            "DELETE FROM reminders WHERE target_id LIKE ?",
            (f"{DEMO_PREFIX}%",),
        )
        connection.execute(
            "DELETE FROM tasks WHERE id LIKE ?",
            (f"{DEMO_PREFIX}%",),
        )
        connection.execute(
            "DELETE FROM goals WHERE id LIKE ?",
            (f"{DEMO_PREFIX}%",),
        )

        for goal in goals:
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
                    encode_datetime(week_start),
                    encode_datetime(today + timedelta(days=goal.due_offset_days)),
                    goal.progress,
                    created_at,
                    created_at,
                ),
            )

        for task in tasks:
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
                    "统计页测试数据，可安全删除或重复注入。",
                    task.priority,
                    task.status,
                    task.estimated_minutes,
                    encode_datetime(task.due_at),
                    encode_datetime(task.completed_at)
                    if task.completed_at is not None
                    else None,
                    created_at,
                    encode_datetime(task.updated_at),
                ),
            )

        connection.commit()


def build_goals() -> list[DemoGoal]:
    return [
        DemoGoal(
            id=f"{DEMO_PREFIX}goal-growth",
            title="统计测试：个人成长追踪",
            description="用于测试完成明细、延期明细和本周完成图表。",
            priority="high",
            status="inProgress",
            progress=0.55,
            due_offset_days=14,
        ),
        DemoGoal(
            id=f"{DEMO_PREFIX}goal-docs",
            title="统计测试：文档库体验打磨",
            description="用于测试本周完成趋势和目标完成率。",
            priority="medium",
            status="completed",
            progress=1,
            due_offset_days=7,
        ),
        DemoGoal(
            id=f"{DEMO_PREFIX}goal-health",
            title="统计测试：健康习惯恢复",
            description="用于测试延期任务聚合。",
            priority="medium",
            status="inProgress",
            progress=0.25,
            due_offset_days=21,
        ),
    ]


def build_tasks(
    *,
    now: datetime,
    today: datetime,
    week_start: datetime,
) -> list[DemoTask]:
    tasks: list[DemoTask] = []

    def at(day: datetime, hour: int, minute: int = 0) -> datetime:
        return day.replace(hour=hour, minute=minute)

    completed_days = [week_start + timedelta(days=index) for index in range(today.weekday() + 1)]
    completed_index = 1
    for day_index, day in enumerate(completed_days):
        count = 2 if day_index == 0 else 1
        if day.date() == today.date():
            count = 3

        for offset in range(count):
            completed_at = at(day, 9 + offset * 3, 20)
            tasks.append(
                DemoTask(
                    id=f"{DEMO_PREFIX}task-completed-{completed_index}",
                    goal_id=f"{DEMO_PREFIX}goal-docs"
                    if completed_index % 2 == 0
                    else f"{DEMO_PREFIX}goal-growth",
                    title=f"已完成：统计图表测试任务 {completed_index}",
                    priority="high" if offset == 0 else "medium",
                    status="completed",
                    estimated_minutes=25 + offset * 10,
                    due_at=completed_at,
                    completed_at=completed_at,
                    updated_at=completed_at,
                ),
            )
            completed_index += 1

    postponed_specs = [
        ("今日延期：整理统计页反馈", today, 11, "high"),
        ("今日延期：补充折线图验收", today, 17, "medium"),
        ("本周延期：复盘文档归档", today - timedelta(days=1), 16, "medium"),
        ("本周延期：健康习惯打卡", week_start, 20, "low"),
    ]
    for index, (title, day, hour, priority) in enumerate(postponed_specs, start=1):
        updated_at = at(day, hour, 30)
        tasks.append(
            DemoTask(
                id=f"{DEMO_PREFIX}task-postponed-{index}",
                goal_id=f"{DEMO_PREFIX}goal-health"
                if index % 2 == 0
                else f"{DEMO_PREFIX}goal-growth",
                title=title,
                priority=priority,
                status="postponed",
                estimated_minutes=30,
                due_at=updated_at - timedelta(days=1),
                completed_at=None,
                updated_at=updated_at,
            ),
        )

    pending_specs = [
        ("待办：观察统计页展开体验", 19, "high"),
        ("待办：记录图表展示感受", 21, "medium"),
    ]
    for index, (title, hour, priority) in enumerate(pending_specs, start=1):
        due_at = at(today, hour, 0)
        tasks.append(
            DemoTask(
                id=f"{DEMO_PREFIX}task-pending-{index}",
                goal_id=f"{DEMO_PREFIX}goal-growth",
                title=title,
                priority=priority,
                status="pending",
                estimated_minutes=20,
                due_at=due_at,
                completed_at=None,
                updated_at=now,
            ),
        )

    return tasks


def prepare_database_for_push(db_path: Path) -> None:
    with sqlite3.connect(db_path) as connection:
        connection.execute("PRAGMA wal_checkpoint(TRUNCATE)")
        connection.execute("PRAGMA journal_mode = DELETE")
        connection.commit()

    for suffix in ("-wal", "-shm"):
        optional_path = db_path.with_name(f"{db_path.name}{suffix}")
        if optional_path.exists():
            optional_path.unlink()


def print_counts(db_path: Path) -> None:
    with sqlite3.connect(db_path) as connection:
        counts = {
            "goals": connection.execute(
                "SELECT COUNT(*) FROM goals WHERE id LIKE ?",
                (f"{DEMO_PREFIX}%",),
            ).fetchone()[0],
            "completed": connection.execute(
                "SELECT COUNT(*) FROM tasks WHERE id LIKE ? AND status = 'completed'",
                (f"{DEMO_PREFIX}%",),
            ).fetchone()[0],
            "postponed": connection.execute(
                "SELECT COUNT(*) FROM tasks WHERE id LIKE ? AND status = 'postponed'",
                (f"{DEMO_PREFIX}%",),
            ).fetchone()[0],
            "pending": connection.execute(
                "SELECT COUNT(*) FROM tasks WHERE id LIKE ? AND status = 'pending'",
                (f"{DEMO_PREFIX}%",),
            ).fetchone()[0],
        }

    print(
        "本次写入："
        f"{counts['goals']} 个目标，"
        f"{counts['completed']} 个已完成任务，"
        f"{counts['postponed']} 个延期任务，"
        f"{counts['pending']} 个待办任务。"
    )


def encode_datetime(value: datetime) -> int:
    return int(value.timestamp() * 1000)


if __name__ == "__main__":
    main()
