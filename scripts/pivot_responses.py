#!/usr/bin/env python3
"""Pivot wide response CSV into one row per response option."""
import csv
import sys
from pathlib import Path

SCORE_COLUMNS = [
    ("Score 0 (Gap)", 1, "Y", 0),
    ("Score 25 (Weak)", 2, "N", 25),
    ("Score 50 (Baseline)", 3, "N", 50),
    ("Score 75 (Robust)", 4, "N", 75),
    ("Score 100 (Compliant)", 5, "N", 100),
]


def pivot(input_path: Path, output_path: Path) -> None:
    rows = []
    with open(input_path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            risk_id = row["Risk ID"].strip()
            for col, seq, is_default, score in SCORE_COLUMNS:
                rows.append({
                    "atqro_code": f"{risk_id}-R{seq:02d}",
                    "atq_code": risk_id,
                    "atqro_label": row[col].strip(),
                    "atqro_sequence": seq,
                    "atqro_is_default": is_default,
                    "atqro_is_active": "Y",
                    "atqro_score_risk": score,
                })

    with open(output_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=[
            "atqro_code", "atq_code", "atqro_label",
            "atqro_sequence", "atqro_is_default", "atqro_is_active", "atqro_score_risk",
        ], quoting=1)
        writer.writeheader()
        writer.writerows(rows)

    print(f"Written {len(rows)} rows to {output_path}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python pivot_responses.py <input.csv> <output.csv>")
        sys.exit(1)
    pivot(Path(sys.argv[1]), Path(sys.argv[2]))
