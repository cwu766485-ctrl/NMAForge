#!/usr/bin/env python3
"""Check that the Compute Cluster Execution RTM has all 38 requirement rows."""

import argparse
import re
import sys
from collections import Counter
from pathlib import Path
from typing import List


EXPECTED = {
    "REQ-CL execution matrix": {f"REQ-CL-{i:03d}" for i in range(1, 29)},
    "REQ-PC execution matrix": {f"REQ-PC-{i:03d}" for i in range(1, 11)},
}
ALLOWED_DISPOSITIONS = {
    "PASS",
    "PASS-SCOPED",
    "PASS-SCOPED*",
    "PASS-SCOPED (unchanged)",
    "PARTIAL",
    "FAIL",
    "WAIVED",
    "BLOCKED_SPEC",
    "BLOCKED_ENV",
    "NOT_RUN",
}
REQUIRE_EVIDENCE_COLUMNS = (2, 3, 4, 5)


def read_matrix(lines: List[str], heading: str) -> List[List[str]]:
    marker = f"## {heading}"
    try:
        start = lines.index(marker) + 1
    except ValueError as exc:
        raise ValueError(f"missing section: {marker}") from exc

    rows: List[List[str]] = []
    for line in lines[start:]:
        if line.startswith("## "):
            break
        if not re.match(r"^\|\s*REQ-(?:CL|PC)-\d+\s*\|", line):
            continue
        columns = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(columns) != 6:
            raise ValueError(
                f"{heading}: expected six RTM columns, got {len(columns)}: {line[:120]}"
            )
        rows.append(columns)
    return rows


def validate(path: Path) -> List[str]:
    lines = path.read_text(encoding="utf-8").splitlines()
    errors: List[str] = []
    counts = Counter()

    for heading, expected_ids in EXPECTED.items():
        try:
            rows = read_matrix(lines, heading)
        except ValueError as exc:
            errors.append(str(exc))
            continue

        ids = [row[0].strip("`") for row in rows]
        duplicates = sorted(item for item, count in Counter(ids).items() if count > 1)
        missing = sorted(expected_ids - set(ids))
        extra = sorted(set(ids) - expected_ids)
        if duplicates:
            errors.append(f"{heading}: duplicate IDs: {', '.join(duplicates)}")
        if missing:
            errors.append(f"{heading}: missing IDs: {', '.join(missing)}")
        if extra:
            errors.append(f"{heading}: unexpected IDs: {', '.join(extra)}")

        for row in rows:
            requirement, disposition = row[0].strip("`"), row[1].strip("`")
            if disposition not in ALLOWED_DISPOSITIONS:
                errors.append(f"{requirement}: unknown disposition {disposition!r}")
            for index in REQUIRE_EVIDENCE_COLUMNS:
                if not row[index] or row[index] in {"—", "-"}:
                    errors.append(
                        f"{requirement}: empty required evidence field in RTM column {index + 1}"
                    )
            counts[disposition] += 1

        print(f"{heading}: {len(rows)}/{len(expected_ids)} rows")

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return errors

    print(f"dispositions: {dict(sorted(counts.items()))}")
    print("COMPUTE_CLUSTER_RTM_INTEGRITY_PASS: 38/38 IDs; checker, coverage, run/seed, and evidence fields present")
    return []


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "rtm",
        nargs="?",
        type=Path,
        default=Path("docs/verification/COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md"),
    )
    args = parser.parse_args()
    return 1 if validate(args.rtm) else 0


if __name__ == "__main__":
    raise SystemExit(main())
