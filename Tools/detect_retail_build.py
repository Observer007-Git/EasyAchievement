#!/usr/bin/env python3
"""Read the installed retail client build from World of Warcraft/.build.info."""

import csv
import re
import sys
from pathlib import Path


VERSION = re.compile(r"^\d+\.\d+\.\d+\.\d+$")


def detect_retail_build(path):
    with path.open(encoding="utf-8-sig", newline="") as handle:
        rows = csv.reader(handle, delimiter="|")
        fields = [field.split("!", 1)[0] for field in next(rows)]
        versions = set()
        for values in rows:
            row = dict(zip(fields, values))
            if row.get("Product") == "wow" and row.get("Active") == "1":
                versions.add(row.get("Version", ""))
    if len(versions) != 1 or not VERSION.fullmatch(next(iter(versions))):
        raise ValueError("active retail 'wow' build is missing or ambiguous")
    return versions.pop()


if __name__ == "__main__":
    try:
        print(detect_retail_build(Path(sys.argv[1])))
    except (IndexError, OSError, StopIteration, ValueError) as error:
        raise SystemExit(f"Unable to read retail build: {error}")
