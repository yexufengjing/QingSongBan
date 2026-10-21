"""Capture privacy-preserving business-row evidence from an Android app DB.

The SQLite bytes travel only through memory. No database export or row content
is written to disk or printed. Evidence stores table counts and SHA-256 row
digests so a later seeded snapshot can prove original rows were retained.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
import subprocess
import sys
from collections import Counter
from pathlib import Path


PACKAGE = "com.yexufengjing.qingsongban"
DB_PATH = "app_flutter/qingsongban.sqlite"


def read_database(serial: str) -> sqlite3.Connection:
    command = [
        "adb",
        "-s",
        serial,
        "exec-out",
        "run-as",
        PACKAGE,
        "cat",
        DB_PATH,
    ]
    result = subprocess.run(command, capture_output=True, check=False)
    if result.returncode != 0 or not result.stdout:
        raise RuntimeError("Could not read the app database through run-as.")
    connection = sqlite3.connect(":memory:")
    try:
        connection.deserialize(result.stdout)
    except Exception:
        connection.close()
        raise RuntimeError("The in-memory SQLite snapshot could not be opened.")
    return connection


def canonical(value: object) -> object:
    if isinstance(value, bytes):
        return {"bytesSha256": hashlib.sha256(value).hexdigest(), "length": len(value)}
    return value


def snapshot(connection: sqlite3.Connection) -> dict[str, object]:
    tables = [
        row[0]
        for row in connection.execute(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name NOT LIKE 'sqlite_%' AND name <> 'drift_migrations' "
            "ORDER BY name"
        )
    ]
    table_evidence: dict[str, object] = {}
    foreign_key_violations = connection.execute("PRAGMA foreign_key_check").fetchall()
    total_rows = 0
    total_demo_rows = 0
    for table in tables:
        safe_table = table.replace('"', '""')
        cursor = connection.execute(f'SELECT * FROM "{safe_table}"')
        columns = [column[0] for column in cursor.description or ()]
        row_hashes: list[str] = []
        demo_hashes: list[str] = []
        demo_count = 0
        for values in cursor.fetchall():
            row = {key: canonical(value) for key, value in zip(columns, values)}
            encoded = json.dumps(
                row, ensure_ascii=False, sort_keys=True, separators=(",", ":")
            ).encode("utf-8")
            digest = hashlib.sha256(encoded).hexdigest()
            row_hashes.append(digest)
            # Keep only a count. Demo markers are inspected in memory and never
            # retained in evidence.
            if any(
                isinstance(value, str)
                and ("DEMO-" in value.upper() or "【演示】" in value)
                for value in values
            ):
                demo_count += 1
                demo_hashes.append(digest)
        row_hashes.sort()
        demo_hashes.sort()
        table_evidence[table] = {
            "count": len(row_hashes),
            "rowSha256": row_hashes,
            "demoCount": demo_count,
            "demoRowSha256": demo_hashes,
        }
        total_rows += len(row_hashes)
        total_demo_rows += demo_count
    return {
        "package": PACKAGE,
        "database": DB_PATH,
        "tableCount": len(tables),
        "rowCount": total_rows,
        "demoRowCount": total_demo_rows,
        "foreignKeyViolationCount": len(foreign_key_violations),
        "tables": table_evidence,
    }


def capture(serial: str, output: Path) -> dict[str, object]:
    connection = read_database(serial)
    try:
        result = snapshot(connection)
    finally:
        connection.close()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return result


def load_evidence(path: Path) -> dict[str, object]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict) or not isinstance(value.get("tables"), dict):
        raise ValueError("Evidence file has an unsupported shape.")
    return value


def verify(
    serial: str,
    baseline_path: Path,
    previous_path: Path | None,
    require_demo_growth: bool,
) -> dict[str, object]:
    baseline = load_evidence(baseline_path)
    connection = read_database(serial)
    try:
        current = snapshot(connection)
    finally:
        connection.close()
    baseline_tables = baseline["tables"]
    current_tables = current["tables"]
    missing_original_rows: dict[str, int] = {}
    for table, prior in baseline_tables.items():
        now = current_tables.get(table)
        current_hashes = Counter(now["rowSha256"]) if now else Counter()
        prior_hashes = Counter(prior["rowSha256"])
        missing = sum((prior_hashes - current_hashes).values())
        if missing:
            missing_original_rows[table] = missing
    demo_growth = int(current["demoRowCount"]) - int(baseline["demoRowCount"])
    unchanged_demo_rows = None
    if previous_path is not None:
        previous = load_evidence(previous_path)
        unchanged_demo_rows = current["demoRowCount"] == previous["demoRowCount"]
        previous_tables = previous["tables"]
        for table, prior in previous_tables.items():
            now = current_tables.get(table)
            if not now or Counter(prior["demoRowSha256"]) != Counter(now["demoRowSha256"]):
                unchanged_demo_rows = False
                break
    result = {
        "originalRowsRetained": not missing_original_rows,
        "missingOriginalRowCountByTable": missing_original_rows,
        "demoRowGrowth": demo_growth,
        "demoGrowthPositive": demo_growth > 0,
        "foreignKeyViolationCount": current["foreignKeyViolationCount"],
        "foreignKeysValid": current["foreignKeyViolationCount"] == 0,
        "demoRowsUnchangedSincePrevious": unchanged_demo_rows,
        "currentTableCount": current["tableCount"],
        "currentRowCount": current["rowCount"],
    }
    if not result["originalRowsRetained"] or not result["foreignKeysValid"]:
        raise RuntimeError("Device database verification failed: " + json.dumps(result))
    if require_demo_growth and not result["demoGrowthPositive"]:
        raise RuntimeError("No demo-row growth was found: " + json.dumps(result))
    if previous_path is not None and not result["demoRowsUnchangedSincePrevious"]:
        raise RuntimeError("Demo rows changed since the previous snapshot: " + json.dumps(result))
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serial", default="emulator-5554")
    parser.add_argument("--capture", type=Path, help="Write aggregate evidence to this JSON path.")
    parser.add_argument("--baseline", type=Path, help="Verify existing rows against a baseline evidence file.")
    parser.add_argument("--previous", type=Path, help="Also require demo rows to match a previous snapshot.")
    parser.add_argument("--require-demo-growth", action="store_true")
    args = parser.parse_args()
    if (args.capture is None) == (args.baseline is None):
        parser.error("Choose exactly one of --capture or --baseline.")
    if args.previous is not None and args.baseline is None:
        parser.error("--previous requires --baseline.")
    try:
        result = (
            capture(args.serial, args.capture)
            if args.capture is not None
            else verify(args.serial, args.baseline, args.previous, args.require_demo_growth)
        )
    except Exception as error:
        print(f"Device database evidence failed: {type(error).__name__}", file=sys.stderr)
        return 1
    if args.capture is not None:
        report = {
            key: result[key]
            for key in ("tableCount", "rowCount", "demoRowCount", "foreignKeyViolationCount")
        }
        report["evidenceWritten"] = True
    else:
        report = result
    print(json.dumps(report, ensure_ascii=False, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
