#!/usr/bin/env python3
"""
Run all seed SQL scripts in order.

Usage:
    python scripts/run_all_seeds.py --tenant "tenant_name" --username "username"
"""

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

from dotenv import load_dotenv


def parse_args() -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Run all seed SQL scripts in numeric order"
    )
    parser.add_argument(
        "--tenant",
        required=True,
        help="Tenant name (matches tenant.tn_tenant_name)",
    )
    parser.add_argument(
        "--username",
        required=True,
        help="Username (matches tenant_user.tu_username)",
    )
    parser.add_argument(
        "--sql-dir",
        default="sql",
        help="Directory containing SQL seed files (default: sql)",
    )
    return parser.parse_args()


def get_seed_files(sql_dir: Path) -> list[Path]:
    """
    Get all seed SQL files sorted by numeric prefix.

    Args:
        sql_dir: Directory containing SQL files.

    Returns:
        List of Path objects sorted by numeric prefix.
    """
    pattern = re.compile(r"^(\d+)_.+_seed\.sql$")
    seed_files = []

    for f in sql_dir.iterdir():
        if f.is_file() and pattern.match(f.name):
            seed_files.append(f)

    # Sort by numeric prefix
    seed_files.sort(key=lambda p: int(pattern.match(p.name).group(1)))
    return seed_files


def run_seed_file(
    sql_file: Path,
    tenant: str,
    username: str,
    conn_string: str,
    script_dir: Path,
) -> tuple[bool, str]:
    """
    Run a single seed SQL file.

    Args:
        sql_file: Path to the SQL file.
        tenant: Tenant name.
        username: Username.
        conn_string: PostgreSQL connection string.
        script_dir: Base script directory.

    Returns:
        Tuple of (success, output_message).
    """
    cmd = [
        "psql",
        "-q",
        conn_string,
        "-c", f"SET vars.tenant_name = '{tenant}';",
        "-c", f"SET vars.username = '{username}';",
        "-f", str(sql_file),
    ]

    result = subprocess.run(cmd, capture_output=True, text=True, cwd=script_dir)

    messages = []
    if result.stderr:
        for line in result.stderr.splitlines():
            if "NOTICE:" in line:
                notice = line.split("NOTICE:")[-1].strip()
                messages.append(notice)
            elif "ERROR:" in line:
                error = line.split("ERROR:")[-1].strip()
                messages.append(f"Error: {error}")

    return result.returncode == 0, "\n".join(messages)


def main() -> int:
    """
    Main entry point for running all seed scripts.

    Returns:
        int: Exit code (0 for success, non-zero for failure)
    """
    args = parse_args()

    # Load environment variables from .env file
    env_path = Path(__file__).parent.parent / ".env"
    load_dotenv(env_path)

    # Get database connection details from environment
    db_host = os.getenv("DB_HOST")
    db_port = os.getenv("DB_PORT", "5432")
    db_name = os.getenv("DB_NAME")
    db_user = os.getenv("DB_USER")
    db_password = os.getenv("DB_PASSWORD")

    # Validate required environment variables
    missing_vars = [
        var for var in ["DB_HOST", "DB_NAME", "DB_USER", "DB_PASSWORD"]
        if not os.getenv(var)
    ]
    if missing_vars:
        print(f"Error: Missing environment variables: {', '.join(missing_vars)}")
        print("Ensure these are defined in your .env file")
        return 1

    # Get the script directory
    script_dir = Path(__file__).parent.parent
    sql_dir = script_dir / args.sql_dir

    if not sql_dir.exists():
        print(f"Error: SQL directory not found: {sql_dir}")
        return 1

    # Get all seed files
    seed_files = get_seed_files(sql_dir)

    if not seed_files:
        print(f"No seed files found in {sql_dir}")
        return 0

    print(f"Running {len(seed_files)} seed script(s)...")
    print(f"  Tenant:   {args.tenant}")
    print(f"  Username: {args.username}")
    print(f"  Database: {db_name} @ {db_host}:{db_port}")
    print()

    # Build connection string
    conn_string = f"host={db_host} port={db_port} dbname={db_name} user={db_user} password={db_password}"

    # Run each seed file
    success_count = 0
    failed_file = None

    for sql_file in seed_files:
        print(f"  [{sql_file.name}]")
        success, output = run_seed_file(sql_file, args.tenant, args.username, conn_string, script_dir)

        if output:
            for line in output.splitlines():
                print(f"    {line}")

        if success:
            success_count += 1
            print(f"    ✓ Done")
        else:
            failed_file = sql_file.name
            print(f"    ✗ Failed")
            break

        print()

    # Summary
    print("-" * 40)
    if failed_file:
        print(f"Seed failed at: {failed_file}")
        print(f"Completed: {success_count}/{len(seed_files)}")
        return 1
    else:
        print(f"All seeds completed successfully! ({success_count}/{len(seed_files)})")
        return 0


if __name__ == "__main__":
    sys.exit(main())