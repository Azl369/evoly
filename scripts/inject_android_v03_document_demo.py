import argparse
import sqlite3
import tempfile
from pathlib import Path

from inject_android_notification_demo import (
    DEFAULT_ADB,
    DEFAULT_PACKAGE,
    pull_database,
    push_database,
    run_adb,
)
from reset_v03_document_demo_data import reset_demo_data


def main() -> None:
    args = parse_args()
    adb = Path(args.adb)
    if not adb.exists():
        raise SystemExit(f"找不到 adb：{adb}")

    device_args = ["-s", args.device] if args.device else []

    run_adb(adb, device_args, ["shell", "am", "force-stop", args.package])

    with tempfile.TemporaryDirectory(
        prefix="evoly_android_v03_demo_",
        ignore_cleanup_errors=True,
    ) as temp_dir:
        temp_path = Path(temp_dir)
        local_db = temp_path / "evoly.db"
        pull_database(adb, device_args, args.package, local_db)
        reset_demo_data(local_db)
        prepare_database_for_push(local_db)
        print_counts(local_db)
        push_database(adb, device_args, args.package, local_db)

    print("已注入 Android V0.3 文档库测试数据。")
    print("请重新打开 Evoly，进入「文档库」和「目标详情」测试文档关联。")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Inject Evoly Android V0.3 document library demo rows into app SQLite database.",
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


def print_counts(db_path: Path) -> None:
    with sqlite3.connect(db_path) as connection:
        counts = {
            "goals": connection.execute(
                "SELECT COUNT(*) FROM goals WHERE id LIKE 'demo-v031-%'",
            ).fetchone()[0],
            "tasks": connection.execute(
                "SELECT COUNT(*) FROM tasks WHERE id LIKE 'demo-v031-%'",
            ).fetchone()[0],
            "documents": connection.execute(
                "SELECT COUNT(*) FROM documents WHERE id LIKE 'demo-v031-%'",
            ).fetchone()[0],
            "links": connection.execute(
                "SELECT COUNT(*) FROM document_links WHERE document_id LIKE 'demo-v031-%'",
            ).fetchone()[0],
        }

    print(
        "本次写入："
        f"{counts['goals']} 个目标、"
        f"{counts['tasks']} 个子任务、"
        f"{counts['documents']} 篇文档、"
        f"{counts['links']} 条文档关联。"
    )


def prepare_database_for_push(db_path: Path) -> None:
    with sqlite3.connect(db_path) as connection:
        connection.execute("PRAGMA wal_checkpoint(TRUNCATE)")
        connection.execute("PRAGMA journal_mode = DELETE")
        connection.commit()

    for suffix in ("-wal", "-shm"):
        optional_path = db_path.with_name(f"{db_path.name}{suffix}")
        if optional_path.exists():
            optional_path.unlink()


if __name__ == "__main__":
    main()
