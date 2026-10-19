#!/usr/bin/env python3
"""Prepare wago.tools achievement reward rows for the Excel exporter."""

import argparse
import csv
import importlib.util
import json
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path


CATEGORY_LABELS = {
    "mount": "坐骑",
    "pet": "宠物",
    "toy": "玩具",
    "decor": "装饰",
    "title": "头衔",
    "appearance": "外观",
    "other": "其他",
}
TEXT_FIELDS = {"Description_lang", "Title_lang", "Reward_lang"}
SOURCE_FIELDS = (
    "Instance_ID",
    "Faction",
    "Supercedes",
    "Category",
    "Minimum_criteria",
    "Points",
    "Flags",
    "Ui_order",
    "IconFileID",
    "Criteria_tree",
    "Shares_criteria",
    "CovenantID",
    "HiddenBeforeDisplaySeason",
    "LegacyAfterTimeEvent",
)


def load_builder(script_dir):
    path = script_dir / "build_reward_database.py"
    spec = importlib.util.spec_from_file_location("reward_builder", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def number(value):
    try:
        return int(value or 0)
    except ValueError:
        return 0


def build_payload(input_dir, build):
    builder = load_builder(Path(__file__).resolve().parent)
    records, categories, unresolved, _, _ = builder.build_database(input_dir)

    achievements = {}
    achievement_path = input_dir / "zhCN" / "Achievement.csv"
    with achievement_path.open(encoding="utf-8-sig", newline="") as handle:
        for row in csv.DictReader(handle):
            achievements[number(row["ID"])] = row

    output_rows = []
    for achievement_id in sorted(records):
        achievement = achievements[achievement_id]
        category_keys = categories[achievement_id]
        category_labels = [CATEGORY_LABELS[key] for key in category_keys]
        for direct_item_id, inferred_item_id in records[achievement_id]:
            reward_id = direct_item_id or inferred_item_id
            if direct_item_id:
                reward_source = "成就表"
            elif inferred_item_id:
                reward_source = "推导"
            else:
                reward_source = "未解析"
            output_rows.append([
                achievement_id,
                achievement.get("Title_lang", ""),
                achievement.get("Description_lang", ""),
                achievement.get("Reward_lang", ""),
                "、".join(category_labels),
                ",".join(category_keys),
                reward_id,
                reward_source,
                direct_item_id,
                inferred_item_id,
                *(number(achievement.get(field)) for field in SOURCE_FIELDS),
            ])

    category_counts = Counter()
    for category_keys in categories.values():
        category_counts.update(category_keys)

    return {
        "build": build,
        "generatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "sourceUrl": "https://wago.tools/db2/Achievement",
        "achievementCount": len(records),
        "rewardRowCount": len(output_rows),
        "unresolvedCount": len(unresolved),
        "categoryCounts": [
            [CATEGORY_LABELS[key], key, category_counts[key]]
            for key in builder.CATEGORY_ORDER
        ],
        "headers": [
            "成就ID",
            "成就中文名",
            "成就中文描述",
            "奖励中文描述",
            "分类",
            "分类键",
            "奖励ID",
            "奖励ID来源",
            "成就表RewardItemID",
            "推导奖励物品ID",
            *SOURCE_FIELDS,
        ],
        "rows": output_rows,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--build", required=True)
    args = parser.parse_args()

    payload = build_payload(args.input, args.build)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, ensure_ascii=False),
        encoding="utf-8")


if __name__ == "__main__":
    main()
