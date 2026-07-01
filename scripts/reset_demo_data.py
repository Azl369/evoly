import argparse
import os
import shutil
import sqlite3
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path


DEMO_PREFIX = "demo-v022-"


@dataclass(frozen=True)
class DemoGoal:
    id: str
    title: str
    description: str
    priority: str
    start_offset_days: int
    due_offset_days: int
    progress: float


@dataclass(frozen=True)
class DemoTask:
    id: str
    goal_id: str
    title: str
    description: str
    priority: str
    status: str
    estimated_minutes: int
    due_day_offset: int
    due_hour: int
    due_minute: int
    completed_offset_hours: int | None = None
    updated_offset_days: int = 0


def main() -> None:
    args = parse_args()
    db_path = resolve_db_path(args.db)

    if not db_path.exists():
        raise SystemExit(f"数据库不存在：{db_path}")

    if args.backup:
        backup_path = backup_database(db_path)
        print(f"已备份数据库：{backup_path}")

    reset_demo_data(db_path)
    print(f"已重置 Evoly Coach 演示数据：{db_path}")
    print("包含：3 个演示目标、8 个今日待办、1 个今日完成、2 条延期风险记录。")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Reset Evoly local SQLite demo data for Coach Lite testing.",
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
    backup_path = db_path.with_name(f"evoly.backup-before-demo-reset-{timestamp}.db")
    shutil.copy2(db_path, backup_path)
    return backup_path


def reset_demo_data(db_path: Path) -> None:
    now = datetime.now()
    today = datetime(now.year, now.month, now.day)
    created_at = encode_datetime(now)

    goals = build_goals()
    tasks = build_tasks()

    with sqlite3.connect(db_path) as connection:
        connection.execute("PRAGMA foreign_keys = ON")
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
                    "inProgress",
                    encode_datetime(today + timedelta(days=goal.start_offset_days)),
                    encode_datetime(today + timedelta(days=goal.due_offset_days)),
                    goal.progress,
                    created_at,
                    created_at,
                ),
            )

        for task in tasks:
            due_at = today + timedelta(days=task.due_day_offset)
            due_at = due_at.replace(hour=task.due_hour, minute=task.due_minute)
            completed_at = (
                encode_datetime(now - timedelta(hours=task.completed_offset_hours))
                if task.completed_offset_hours is not None
                else None
            )
            updated_at = encode_datetime(now - timedelta(days=task.updated_offset_days))

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
                    task.description,
                    task.priority,
                    task.status,
                    task.estimated_minutes,
                    encode_datetime(due_at),
                    completed_at,
                    created_at,
                    updated_at,
                ),
            )


def build_goals() -> list[DemoGoal]:
    return [
        DemoGoal(
            id="demo-v022-goal-focus",
            title="V0.2 Coach 演示：产品发布准备",
            description="用于演示今日过载、Top 3 和调整草案。",
            priority="high",
            start_offset_days=0,
            due_offset_days=14,
            progress=0.25,
        ),
        DemoGoal(
            id="demo-v022-goal-health",
            title="V0.2 Coach 演示：健康恢复计划",
            description="用于演示普通任务和低优先级任务延期。",
            priority="medium",
            start_offset_days=0,
            due_offset_days=21,
            progress=0.1,
        ),
        DemoGoal(
            id="demo-v022-goal-english-risk",
            title="V0.2 Coach 演示：英语口语提升",
            description="用于演示延期风险目标。",
            priority="high",
            start_offset_days=-10,
            due_offset_days=30,
            progress=0.08,
        ),
    ]


def build_tasks() -> list[DemoTask]:
    return [
        DemoTask(
            id="demo-v022-task-01",
            goal_id="demo-v022-goal-focus",
            title="完成 V0.2 Coach 草案体验自测",
            description="高优先级且接近截止，应进入 Top 3。",
            priority="high",
            status="pending",
            estimated_minutes=45,
            due_day_offset=0,
            due_hour=10,
            due_minute=30,
        ),
        DemoTask(
            id="demo-v022-task-02",
            goal_id="demo-v022-goal-focus",
            title="整理 Evoly 演示脚本",
            description="高优先级，应进入 Top 3。",
            priority="high",
            status="pending",
            estimated_minutes=60,
            due_day_offset=0,
            due_hour=15,
            due_minute=0,
        ),
        DemoTask(
            id="demo-v022-task-03",
            goal_id="demo-v022-goal-english-risk",
            title="录 15 分钟英语口语练习",
            description="延期风险目标下的启动任务，应被 Coach 关注。",
            priority="medium",
            status="pending",
            estimated_minutes=30,
            due_day_offset=0,
            due_hour=11,
            due_minute=30,
        ),
        DemoTask(
            id="demo-v022-task-04",
            goal_id="demo-v022-goal-focus",
            title="检查 README 当前功能说明",
            description="可延期的普通任务。",
            priority="medium",
            status="pending",
            estimated_minutes=40,
            due_day_offset=0,
            due_hour=17,
            due_minute=0,
        ),
        DemoTask(
            id="demo-v022-task-05",
            goal_id="demo-v022-goal-health",
            title="晚饭后散步 20 分钟",
            description="健康目标低压力任务。",
            priority="low",
            status="pending",
            estimated_minutes=20,
            due_day_offset=0,
            due_hour=20,
            due_minute=0,
        ),
        DemoTask(
            id="demo-v022-task-06",
            goal_id="demo-v022-goal-focus",
            title="整理下一版功能想法",
            description="低优先级，可被延期。",
            priority="low",
            status="pending",
            estimated_minutes=35,
            due_day_offset=0,
            due_hour=21,
            due_minute=0,
        ),
        DemoTask(
            id="demo-v022-task-07",
            goal_id="demo-v022-goal-health",
            title="记录今天饮水情况",
            description="低优先级，可被延期。",
            priority="low",
            status="pending",
            estimated_minutes=10,
            due_day_offset=0,
            due_hour=22,
            due_minute=0,
        ),
        DemoTask(
            id="demo-v022-task-08",
            goal_id="demo-v022-goal-focus",
            title="清理旧的临时测试项",
            description="低优先级，可被延期。",
            priority="low",
            status="pending",
            estimated_minutes=25,
            due_day_offset=0,
            due_hour=23,
            due_minute=0,
        ),
        DemoTask(
            id="demo-v022-task-09",
            goal_id="demo-v022-goal-focus",
            title="已完成：打开 Evoly 检查首页",
            description="用于演示已完成数量。",
            priority="medium",
            status="completed",
            estimated_minutes=15,
            due_day_offset=0,
            due_hour=8,
            due_minute=30,
            completed_offset_hours=2,
        ),
        DemoTask(
            id="demo-v022-task-10",
            goal_id="demo-v022-goal-english-risk",
            title="延期记录：昨天口语跟读",
            description="用于演示延期风险。",
            priority="medium",
            status="postponed",
            estimated_minutes=30,
            due_day_offset=-1,
            due_hour=9,
            due_minute=0,
            updated_offset_days=1,
        ),
        DemoTask(
            id="demo-v022-task-11",
            goal_id="demo-v022-goal-english-risk",
            title="延期记录：前天复述练习",
            description="用于演示延期风险。",
            priority="high",
            status="postponed",
            estimated_minutes=30,
            due_day_offset=-2,
            due_hour=9,
            due_minute=0,
            updated_offset_days=2,
        ),
    ]


def encode_datetime(value: datetime) -> int:
    return int(value.timestamp() * 1000)


if __name__ == "__main__":
    main()
