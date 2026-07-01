import argparse
import os
import sqlite3
import subprocess
import tempfile
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path


DEMO_PREFIX = "android-notify-demo-"
DEFAULT_PACKAGE = "com.evoly.app"
DEFAULT_ADB = r"D:\dev\android-sdk\platform-tools\adb.exe"


@dataclass(frozen=True)
class ReminderDemoTask:
    id: str
    reminder_id: str
    title: str
    description: str
    minutes_from_now: int
    priority: str


def main() -> None:
    args = parse_args()
    adb = Path(args.adb)
    if not adb.exists():
        raise SystemExit(f"找不到 adb：{adb}")

    device_args = ["-s", args.device] if args.device else []

    run_adb(adb, device_args, ["shell", "am", "force-stop", args.package])

    with tempfile.TemporaryDirectory(prefix="evoly_android_demo_") as temp_dir:
        temp_path = Path(temp_dir)
        local_db = temp_path / "evoly.db"
        pull_database(adb, device_args, args.package, local_db)
        inject_demo_rows(local_db)
        push_database(adb, device_args, args.package, local_db)

    print("已注入 Android 后台通知测试数据。")
    print("请重新打开 Evoly，让应用启动时 resyncReminders 注册定时通知。")
    print("建议测试：打开 App 一次 → 锁屏等待 2 分钟 → 再杀掉 App 等待 5/8 分钟。")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Inject Evoly Android notification demo rows into app SQLite database.",
    )
    parser.add_argument(
        "--device",
        help="adb 设备 ID，例如 192.168.31.14:42463。为空时使用当前默认设备。",
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


def pull_database(
    adb: Path,
    device_args: list[str],
    package: str,
    local_db: Path,
) -> None:
    remote_cache = "cache/evoly_notification_demo"
    run_adb(
        adb,
        device_args,
        [
            "shell",
            (
                f"run-as {package} sh -c "
                f"\"mkdir -p {remote_cache} && "
                f"cp databases/evoly.db {remote_cache}/evoly.db && "
                f"(cp databases/evoly.db-wal {remote_cache}/evoly.db-wal 2>/dev/null || true) && "
                f"(cp databases/evoly.db-shm {remote_cache}/evoly.db-shm 2>/dev/null || true)\""
            ),
        ],
    )

    write_exec_out(
        adb,
        device_args,
        ["exec-out", "run-as", package, "cat", f"{remote_cache}/evoly.db"],
        local_db,
    )

    for suffix in ("-wal", "-shm"):
        optional_path = local_db.with_name(f"evoly.db{suffix}")
        result = run_adb(
            adb,
            device_args,
            ["exec-out", "run-as", package, "cat", f"{remote_cache}/evoly.db{suffix}"],
            check=False,
            capture=True,
        )
        if result.returncode == 0 and result.stdout:
            optional_path.write_bytes(result.stdout)


def push_database(
    adb: Path,
    device_args: list[str],
    package: str,
    local_db: Path,
) -> None:
    remote_db = "/data/local/tmp/evoly-notification-demo.db"
    run_adb(adb, device_args, ["push", str(local_db), remote_db])
    run_adb(adb, device_args, ["shell", "chmod", "644", remote_db])
    run_adb(
        adb,
        device_args,
        [
            "shell",
            (
                f"run-as {package} sh -c "
                f"\"cp {remote_db} databases/evoly.db && "
                "rm -f databases/evoly.db-wal databases/evoly.db-shm\""
            ),
        ],
    )
    run_adb(adb, device_args, ["shell", "rm", "-f", remote_db])


def inject_demo_rows(db_path: Path) -> None:
    now = datetime.now()
    today = datetime(now.year, now.month, now.day)
    created_at = encode_datetime(now)
    goal_id = f"{DEMO_PREFIX}goal"
    tasks = build_demo_tasks()

    connection = sqlite3.connect(db_path)
    try:
        connection.execute("PRAGMA foreign_keys = ON")
        connection.execute("PRAGMA journal_mode = DELETE")
        connection.execute("BEGIN")
        connection.execute(
            "DELETE FROM reminders WHERE id LIKE ? OR target_id LIKE ?",
            (f"{DEMO_PREFIX}%", f"{DEMO_PREFIX}%"),
        )
        connection.execute(
            "DELETE FROM tasks WHERE id LIKE ?",
            (f"{DEMO_PREFIX}%",),
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
                "Android 通知测试：后台提醒验证",
                "用于验证即时通知、定时通知、锁屏提醒和杀掉应用后的系统通知。",
                "longTerm",
                "high",
                "inProgress",
                encode_datetime(today),
                encode_datetime(today + timedelta(days=7)),
                0,
                created_at,
                created_at,
            ),
        )

        for task in tasks:
            due_at = now + timedelta(minutes=task.minutes_from_now)
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
                    goal_id,
                    task.title,
                    task.description,
                    task.priority,
                    "pending",
                    5,
                    encode_datetime(due_at),
                    None,
                    created_at,
                    created_at,
                ),
            )
            connection.execute(
                """
                INSERT INTO reminders (
                  id, target_type, target_id, remind_at, repeat_rule,
                  advance_minutes, enabled, fired_at, created_at, updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    task.reminder_id,
                    "task",
                    task.id,
                    encode_datetime(due_at),
                    "none",
                    0,
                    1,
                    None,
                    created_at,
                    created_at,
                ),
            )

        connection.commit()
    finally:
        connection.close()


def build_demo_tasks() -> list[ReminderDemoTask]:
    return [
        ReminderDemoTask(
            id=f"{DEMO_PREFIX}task-2m",
            reminder_id=f"{DEMO_PREFIX}reminder-2m",
            title="通知测试：2 分钟后弹出",
            description="打开 App 后等待 2 分钟，验证前台/锁屏定时通知。",
            minutes_from_now=2,
            priority="high",
        ),
        ReminderDemoTask(
            id=f"{DEMO_PREFIX}task-5m",
            reminder_id=f"{DEMO_PREFIX}reminder-5m",
            title="通知测试：5 分钟后台提醒",
            description="打开 App 让系统注册提醒后，切后台或锁屏等待。",
            minutes_from_now=5,
            priority="medium",
        ),
        ReminderDemoTask(
            id=f"{DEMO_PREFIX}task-8m",
            reminder_id=f"{DEMO_PREFIX}reminder-8m",
            title="通知测试：8 分钟杀掉应用",
            description="打开 App 后从最近任务杀掉 Evoly，等待系统通知是否仍触发。",
            minutes_from_now=8,
            priority="medium",
        ),
    ]


def encode_datetime(value: datetime) -> int:
    return int(value.timestamp() * 1000)


def write_exec_out(
    adb: Path,
    device_args: list[str],
    args: list[str],
    output_path: Path,
) -> None:
    result = run_adb(adb, device_args, args, capture=True)
    output_path.write_bytes(result.stdout)


def run_adb(
    adb: Path,
    device_args: list[str],
    args: list[str],
    *,
    check: bool = True,
    capture: bool = False,
) -> subprocess.CompletedProcess[bytes]:
    command = [str(adb), *device_args, *args]
    result = subprocess.run(
        command,
        check=False,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
    )

    if check and result.returncode != 0:
        stderr = result.stderr.decode("utf-8", errors="replace") if result.stderr else ""
        raise SystemExit(f"命令失败：{' '.join(command)}\n{stderr}")

    return result


if __name__ == "__main__":
    main()
