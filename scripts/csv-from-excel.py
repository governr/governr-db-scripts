#!/usr/bin/env python3
"""
Convert Excel (.xlsx) files to CSV format.

Usage:
    python csv-from-excel.py <xlsx_file> [xlsx_file2 ...]
    python csv-from-excel.py data/assessment_framework.xlsx
    python csv-from-excel.py data/*.xlsx

Args:
    xlsx_file: Path to one or more Excel files to convert.
"""
import argparse
import sys
from pathlib import Path

import pandas as pd


def convert_xlsx_to_csv(xlsx_path: Path) -> bool:
    """
    Convert a single Excel file to CSV.

    Args:
        xlsx_path: Path to the Excel file.

    Returns:
        True if conversion succeeded, False otherwise.
    """
    if not xlsx_path.exists():
        print(f"⚠️  {xlsx_path} not found")
        return False

    if xlsx_path.suffix.lower() != ".xlsx":
        print(f"⚠️  {xlsx_path} is not an .xlsx file")
        return False

    try:
        df = pd.read_excel(xlsx_path)
        csv_path = xlsx_path.with_suffix(".csv")
        df.to_csv(csv_path, index=False, encoding="utf-8", quoting=1)  # quoting=1 = QUOTE_ALL
        print(f"✅ {xlsx_path} → {csv_path}")
        return True
    except Exception as e:
        print(f"❌ Error converting {xlsx_path}: {e}")
        return False


def main():
    """Parse arguments and convert all specified Excel files."""
    parser = argparse.ArgumentParser(
        description="Convert Excel (.xlsx) files to CSV format.",
        epilog="Example: python csv-from-excel.py data/assessment_framework.xlsx",
    )
    parser.add_argument(
        "files",
 nargs="+",
        help="One or more Excel file paths to convert",
    )

    args = parser.parse_args()

    success_count = 0
    for file_path in args.files:
        path = Path(file_path)
        if convert_xlsx_to_csv(path):
            success_count += 1

    total = len(args.files)
    print(f"\nConverted {success_count}/{total} files successfully.")

    if success_count < total:
        sys.exit(1)


if __name__ == "__main__":
    main()
