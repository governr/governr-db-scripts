#!/usr/bin/env python3
"""
Run the assessment framework seed SQL script.

Usage:
    python scripts/run_seed.py --tenant "tenant_name" --username "username"
"""

import argparse
import os
import subprocess
import sys
from pathlib import Path

from dotenv import load_dotenv


def parse_args() -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Run the assessment framework seed SQL script"
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
        "--sql-file",
        default="sql/001_assessment_framework_seed.sql",
        help="Path to the SQL file (default: sql/001_assessment_framework_seed.sql)",
    )
    return parser.parse_args()


def main() -> int:
    """
    Main entry point for the seed script runner.

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

    # Get the absolute path to the SQL file
    script_dir = Path(__file__).parent.parent
    sql_file = script_dir / args.sql_file

    if not sql_file.exists():
        print(f"Error: SQL file not found: {sql_file}")
        return 1

    print(f"Running seed script...")
    print(f"  Tenant:   {args.tenant}")
    print(f"  Username: {args.username}")
    print(f"  Database: {db_name} @ {db_host}:{db_port}")
    print()

    # Build the psql command
    # Use -q for quiet mode and capture output
    conn_string = f"host={db_host} port={db_port} dbname={db_name} user={db_user} password={db_password}"

    cmd = [
        "psql",
        "-q",  # Quiet mode - suppress status messages
        conn_string,
        "-c", f"SET vars.tenant_name = '{args.tenant}';",
        "-c", f"SET vars.username = '{args.username}';",
        "-f", str(sql_file),
    ]

    # Change to the script directory so relative paths in SQL work
    os.chdir(script_dir)

    # Run the command and capture output
    result = subprocess.run(cmd, capture_output=True, text=True)

    # Filter and display NOTICE messages
    if result.stderr:
        for line in result.stderr.splitlines():
            if "NOTICE:" in line:
                # Extract just the notice message after "NOTICE:"
                notice = line.split("NOTICE:")[-1].strip()
                print(f"  {notice}")
            elif "ERROR:" in line:
                error = line.split("ERROR:")[-1].strip()
                print(f"  Error: {error}")

    print()

    if result.returncode == 0:
        print("Seed completed successfully!")
    else:
        print(f"Seed failed with exit code: {result.returncode}")

    return result.returncode


if __name__ == "__main__":
    sys.exit(main())