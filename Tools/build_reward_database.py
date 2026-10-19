#!/usr/bin/env python3
"""Build the addon's achievement reward database from wago.tools CSV files."""

import argparse
import csv
import re
from collections import defaultdict
from pathlib import Path


LOCALIZED_TABLES = (
    "Achievement",
    "BattlePetSpecies",
    "Creature",
    "Mount",
    "Toy",
    "HouseDecor",
    "ItemSparse",
    "TransmogSet",
)
COMMON_TABLES = (
    "RetroactiveDecorReward",
    "ItemEffect",
    "ItemXItemEffect",
    "ItemModifiedAppearance",
    "TransmogSetItem",
)
LOCALES = ("enUS", "zhCN")

COLOR_CODE = re.compile(r"\|c[0-9a-fA-F]{8}")
LINK_CODE = re.compile(r"\|H[^|]*\|h(.*?)\|h")
SPACE = re.compile(r"\s+")
SOURCE_LABELS = ("achievement:", "achievement：", "成就:", "成就：")
TYPE_MARKERS = {
    "mount": ("mount:", "mount reward:", "坐骑：", "坐骑:", "坐骑奖励："),
    "pet": ("pet:", "pet reward:", "宠物：", "宠物:", "宠物奖励："),
    "toy": ("toy:", "toy reward:", "玩具：", "玩具:", "玩具奖励："),
    "decor": ("decor:", "decor reward:", "housing decor:", "装饰：",
        "装饰:", "装饰奖励：", "装饰奖励:"),
    "appearance": ("appearance:", "appearance reward:", "transmog:",
        "transmog reward:", "arsenal:", "illusion:", "外观：", "外观:",
        "幻化奖励：", "幻化奖励:", "军械：", "军械:", "幻象：", "幻象:"),
}
TITLE_MARKERS = ("title:", "title reward:", "头衔：", "头衔:",
    "称号：", "称号:")
CATEGORY_ORDER = ("mount", "pet", "toy", "decor", "title",
    "appearance", "other")
CATEGORY_BITS = {
    category: 1 << index for index, category in enumerate(CATEGORY_ORDER)
}


def integer(value):
    try:
        return int(value or 0)
    except ValueError:
        return 0


def plain_text(value):
    value = value or ""
    value = LINK_CODE.sub(r"\1", value)
    value = COLOR_CODE.sub("", value)
    return value.replace("|r", "").replace("|n", "\n")


def normalized(value):
    value = plain_text(value).replace("’", "'").replace("‘", "'")
    value = value.replace("“", '"').replace("”", '"')
    return SPACE.sub(" ", value).strip().casefold()


def source_achievement_name(source_text):
    text = plain_text(source_text)
    folded = text.casefold()
    for label in SOURCE_LABELS:
        position = folded.find(label)
        if position >= 0:
            value = text[position + len(label):].splitlines()[0].strip()
            return normalized(value)
    return ""


def reward_types(reward_text):
    text = normalized(reward_text)
    return {
        reward_type for reward_type, markers in TYPE_MARKERS.items()
        if any(marker in text for marker in markers)
    }


def reward_payload(reward_text):
    text = normalized(reward_text)
    positions = [position for position in
        (text.find(":"), text.find("：")) if position >= 0]
    return text[min(positions) + 1:].strip() if positions else ""


def read_rows(path):
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        yield from csv.DictReader(handle)


def add(index, key, values):
    if key:
        index[key].update(value for value in values if value > 0)


def load_localized(input_dir, table, locale):
    return input_dir / locale / f"{table}.csv"


def load_common(input_dir, table):
    return input_dir / "common" / f"{table}.csv"


def build_database(input_dir):
    achievements = {}
    for locale in LOCALES:
        for row in read_rows(load_localized(input_dir, "Achievement", locale)):
            achievement_id = integer(row["ID"])
            entry = achievements.setdefault(achievement_id, {
                "reward_item_id": integer(row["RewardItemID"]),
                "faction": integer(row.get("Faction", "-1")),
                "titles": {},
                "rewards": {},
            })
            entry["titles"][locale] = row.get("Title_lang", "")
            entry["rewards"][locale] = row.get("Reward_lang", "")

    effect_to_spell = {}
    for row in read_rows(load_common(input_dir, "ItemEffect")):
        effect_to_spell[integer(row["ID"])] = integer(row["SpellID"])
    spell_to_items = defaultdict(set)
    for row in read_rows(load_common(input_dir, "ItemXItemEffect")):
        spell_id = effect_to_spell.get(integer(row["ItemEffectID"]), 0)
        item_id = integer(row["ItemID"])
        if spell_id and item_id:
            spell_to_items[spell_id].add(item_id)

    appearance_to_item = {}
    appearance_item_ids = set()
    for row in read_rows(load_common(input_dir, "ItemModifiedAppearance")):
        appearance_id = integer(row["ID"])
        item_id = integer(row["ItemID"])
        if appearance_id and item_id:
            appearance_to_item[appearance_id] = item_id
            appearance_item_ids.add(item_id)

    set_to_items = defaultdict(set)
    for row in read_rows(load_common(input_dir, "TransmogSetItem")):
        item_id = appearance_to_item.get(
            integer(row["ItemModifiedAppearanceID"]), 0)
        if item_id:
            set_to_items[integer(row["TransmogSetID"])].add(item_id)

    source_indexes = {
        reward_type: defaultdict(set)
        for reward_type in ("mount", "pet", "toy")
    }
    name_indexes = {
        reward_type: defaultdict(set)
        for reward_type in ("mount", "pet", "toy", "decor", "appearance")
    }
    toy_item_ids = set()
    decor_item_ids = set()
    pet_item_ids = set()
    mount_item_ids = set()
    set_names = defaultdict(set)

    for locale in LOCALES:
        creatures = {}
        for row in read_rows(load_localized(input_dir, "Creature", locale)):
            creatures[integer(row["ID"])] = row.get("Name_lang", "")

        for row in read_rows(
            load_localized(input_dir, "BattlePetSpecies", locale)
        ):
            item_ids = spell_to_items.get(integer(row["SummonSpellID"]), set())
            if not item_ids:
                continue
            pet_item_ids.update(item_ids)
            add(source_indexes["pet"],
                source_achievement_name(row.get("SourceText_lang")), item_ids)
            add(name_indexes["pet"],
                normalized(creatures.get(integer(row["CreatureID"]))), item_ids)

        for row in read_rows(load_localized(input_dir, "Mount", locale)):
            item_ids = spell_to_items.get(integer(row["SourceSpellID"]), set())
            if not item_ids:
                continue
            mount_item_ids.update(item_ids)
            add(source_indexes["mount"],
                source_achievement_name(row.get("SourceText_lang")), item_ids)
            add(name_indexes["mount"], normalized(row.get("Name_lang")), item_ids)

        for row in read_rows(load_localized(input_dir, "Toy", locale)):
            item_id = integer(row["ItemID"])
            if not item_id:
                continue
            toy_item_ids.add(item_id)
            add(source_indexes["toy"],
                source_achievement_name(row.get("SourceText_lang")), {item_id})

        for row in read_rows(load_localized(input_dir, "HouseDecor", locale)):
            item_id = integer(row["ItemID"])
            if not item_id:
                continue
            decor_item_ids.add(item_id)
            add(name_indexes["decor"], normalized(row.get("Name_lang")), {item_id})

        for row in read_rows(load_localized(input_dir, "TransmogSet", locale)):
            item_ids = set_to_items.get(integer(row["ID"]), set())
            if item_ids:
                add(set_names, normalized(row.get("Name_lang")), item_ids)

    direct_decor = defaultdict(set)
    decor_by_id = {}
    for row in read_rows(load_localized(input_dir, "HouseDecor", "enUS")):
        decor_by_id[integer(row["ID"])] = integer(row["ItemID"])
    for row in read_rows(load_common(input_dir, "RetroactiveDecorReward")):
        item_id = decor_by_id.get(integer(row["HouseDecorID"]), 0)
        if item_id:
            direct_decor[integer(row["AchievementID"])].add(item_id)

    named_item_types = {
        "mount": mount_item_ids,
        "pet": pet_item_ids,
        "toy": toy_item_ids,
        "decor": decor_item_ids,
        "appearance": appearance_item_ids,
    }
    typed_payloads = {locale: defaultdict(set) for locale in LOCALES}
    for achievement in achievements.values():
        for locale, reward_text in achievement["rewards"].items():
            payload = reward_payload(reward_text)
            if payload:
                typed_payloads[locale][payload].update(
                    reward_types(reward_text))
    for locale in LOCALES:
        wanted_ids = set().union(*named_item_types.values())
        for row in read_rows(load_localized(input_dir, "ItemSparse", locale)):
            item_id = integer(row["ID"])
            item_name = normalized(row.get("Display_lang"))
            if not item_name:
                continue
            if item_id in wanted_ids:
                for reward_type, item_ids in named_item_types.items():
                    if item_id in item_ids:
                        add(name_indexes[reward_type], item_name, {item_id})
            payloads = {item_name}
            positions = [position for position in
                (item_name.find(":"), item_name.find("：")) if position >= 0]
            if positions:
                payloads.add(item_name[min(positions) + 1:].strip())
            for payload in payloads:
                for reward_type in typed_payloads[locale].get(payload, set()):
                    add(name_indexes[reward_type], payload, {item_id})

    for name, item_ids in set_names.items():
        add(name_indexes["appearance"], name, item_ids)

    sorted_names = {
        reward_type: sorted(index, key=len, reverse=True)
        for reward_type, index in name_indexes.items()
    }

    factions = {
        achievement_id: achievement["faction"]
        for achievement_id, achievement in achievements.items()
        if achievement["faction"] in (0, 1)
    }
    records = {}
    categories = {}
    unresolved = []
    inferred_count = 0
    for achievement_id in sorted(achievements):
        achievement = achievements[achievement_id]
        direct_item_id = achievement["reward_item_id"]
        has_reward_text = any(value.strip()
            for value in achievement["rewards"].values())
        if not direct_item_id and not has_reward_text:
            continue

        inferred_by_type = {
            reward_type: set() for reward_type in TYPE_MARKERS
        }
        inferred_by_type["decor"].update(
            direct_decor.get(achievement_id, set()))
        for reward_type in ("mount", "pet", "toy"):
            for title in achievement["titles"].values():
                inferred_by_type[reward_type].update(
                    source_indexes[reward_type].get(
                        normalized(title), set()))

        detected_types = set()
        normalized_rewards = [normalized(value)
            for value in achievement["rewards"].values() if value.strip()]
        for reward_type, markers in TYPE_MARKERS.items():
            if any(any(marker in text for marker in markers)
                for text in normalized_rewards):
                detected_types.add(reward_type)
                for item_name in sorted_names[reward_type]:
                    if len(item_name) >= 2 and any(
                        item_name in text for text in normalized_rewards
                    ):
                        inferred_by_type[reward_type].update(
                            name_indexes[reward_type][item_name])

        category_types = set(detected_types)
        if any(any(marker in text for marker in TITLE_MARKERS)
            for text in normalized_rewards):
            category_types.add("title")

        if direct_item_id:
            direct_types = {
                reward_type for reward_type, item_ids
                in named_item_types.items() if direct_item_id in item_ids
            }
            category_types.update(direct_types)
            if len(detected_types) <= 1:
                for reward_type in inferred_by_type:
                    if (reward_type != "decor"
                        or achievement_id not in direct_decor):
                        inferred_by_type[reward_type].clear()
            else:
                for reward_type in direct_types.intersection(detected_types):
                    inferred_by_type[reward_type].clear()

        category_types.update(reward_type
            for reward_type, item_ids in inferred_by_type.items()
            if item_ids)
        if not category_types:
            category_types.add("other")
        categories[achievement_id] = [category
            for category in CATEGORY_ORDER if category in category_types]

        inferred = set().union(*inferred_by_type.values())
        inferred.discard(0)
        inferred.discard(direct_item_id)
        reward_rows = []
        if direct_item_id:
            reward_rows.append((direct_item_id, 0))
        reward_rows.extend((0, item_id) for item_id in sorted(inferred))
        if reward_rows:
            records[achievement_id] = reward_rows
            inferred_count += len(inferred)
        else:
            records[achievement_id] = [(0, 0)]
            if detected_types:
                unresolved.append((achievement_id,
                    achievement["titles"].get("zhCN", ""),
                    achievement["rewards"].get("zhCN", ""),
                    ",".join(sorted(detected_types))))

    return records, categories, unresolved, inferred_count, factions


def compact_reward_values(reward_rows, reward_categories):
    category_mask = sum(CATEGORY_BITS[category]
        for category in reward_categories)
    encoded_rewards = [reward_item_id
        if reward_item_id else -inferred_item_id
        for reward_item_id, inferred_item_id in reward_rows]
    return [category_mask, *encoded_rewards]


def build_mount_items(input_dir, records):
    effect_spells = {integer(row["ID"]): integer(row["SpellID"])
        for row in read_rows(load_common(input_dir, "ItemEffect"))}
    spell_mounts = {integer(row["SourceSpellID"]): integer(row["ID"])
        for row in read_rows(load_localized(input_dir, "Mount", "enUS"))
        if integer(row.get("SourceTypeEnum")) == 5}
    reward_items = {direct or inferred for rows in records.values()
        for direct, inferred in rows if direct or inferred}
    mount_items = {}
    for row in read_rows(load_common(input_dir, "ItemXItemEffect")):
        item_id = integer(row["ItemID"])
        mount_id = spell_mounts.get(
            effect_spells.get(integer(row["ItemEffectID"])))
        if item_id in reward_items and mount_id:
            mount_items[item_id] = mount_id
    return mount_items


def build_preview_items(input_dir, records):
    reward_items = {direct or inferred for rows in records.values()
        for direct, inferred in rows if direct or inferred}
    effect_spells = {integer(row["ID"]): integer(row["SpellID"])
        for row in read_rows(load_common(input_dir, "ItemEffect"))}
    spell_items = defaultdict(set)
    for row in read_rows(load_common(input_dir, "ItemXItemEffect")):
        item_id = integer(row["ItemID"])
        if item_id in reward_items:
            spell_items[effect_spells.get(integer(row["ItemEffectID"]))].add(
                item_id)
    creatures = {integer(row["ID"]): row for row in read_rows(
        load_localized(input_dir, "Creature", "enUS"))}
    previews = {key: {} for key in
        ("petItems", "decorItems", "toyItems", "appearanceItems")}
    for row in read_rows(load_localized(input_dir, "BattlePetSpecies", "enUS")):
        species_id = integer(row.get("ID"))
        if not species_id:
            continue
        creature = creatures.get(integer(row["CreatureID"]), {})
        values = [species_id, integer(creature.get("DisplayID_0")),
            integer(row.get("CardUIModelSceneID")),
            integer(row.get("IconFileDataID"))]
        for item_id in spell_items.get(integer(row["SummonSpellID"]), ()):
            previews["petItems"][item_id] = values
    for row in read_rows(load_localized(input_dir, "HouseDecor", "enUS")):
        item_id = integer(row["ItemID"])
        if item_id in reward_items:
            previews["decorItems"][item_id] = [integer(row["ID"]),
                integer(row.get("ModelFileDataID")),
                integer(row.get("UiModelSceneID"))]
    for row in read_rows(load_localized(input_dir, "Toy", "enUS")):
        item_id = integer(row["ItemID"])
        if item_id in reward_items:
            previews["toyItems"][item_id] = 1
    appearances = sorted((row for row in read_rows(load_common(input_dir,
        "ItemModifiedAppearance")) if integer(row["ItemID"]) in reward_items),
        key=lambda row: (
            integer(row.get("ItemAppearanceModifierID")),
            integer(row.get("OrderIndex")), integer(row["ID"])))
    for row in appearances:
        item_id = integer(row["ItemID"])
        if item_id in reward_items:
            previews["appearanceItems"].setdefault(item_id, integer(row["ID"]))
    return previews


def write_lua(output, build, records, categories, factions, mount_items=None,
    preview_items=None):
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write("local _, Addon = ...\n\n")
        handle.write("-- Generated by Tools/update_reward_database.sh; do not edit.\n")
        handle.write("Addon.AchievementRewardDatabase={\n")
        handle.write("schema=2,\n")
        handle.write(f'build="{build}",\n')
        handle.write("rewards={\n")
        for achievement_id, reward_rows in records.items():
            values = ",".join(str(value)
                for value in compact_reward_values(reward_rows,
                    categories[achievement_id]))
            handle.write(f"[{achievement_id}]={{{values}}},\n")
        handle.write("},\n")
        handle.write("mountItems={\n")
        for item_id, mount_id in sorted((mount_items or {}).items()):
            handle.write(f"[{item_id}]={mount_id},\n")
        handle.write("},\n")
        for table_name, entries in (preview_items or {}).items():
            handle.write(f"{table_name}={{\n")
            for item_id, values in sorted(entries.items()):
                encoded = ("{" + ",".join(map(str, values)) + "}"
                    if isinstance(values, list) else str(values))
                handle.write(f"[{item_id}]={encoded},\n")
            handle.write("},\n")
        handle.write("factions={\n")
        for achievement_id in sorted(factions):
            handle.write(f"[{achievement_id}]={factions[achievement_id]},\n")
        handle.write("},\n")
        handle.write("}\n")


def write_unresolved(path, unresolved):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(("achievementID", "title_zhCN", "reward_zhCN", "types"))
        writer.writerows(unresolved)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--unresolved", required=True, type=Path)
    parser.add_argument("--build", required=True)
    args = parser.parse_args()

    records, categories, unresolved, inferred_count, factions = \
        build_database(args.input)
    mount_items = build_mount_items(args.input, records)
    preview_items = build_preview_items(args.input, records)
    write_lua(args.output, args.build, records, categories, factions,
        mount_items, preview_items)
    write_unresolved(args.unresolved, unresolved)
    direct_count = sum(rows[0][0] > 0 for rows in records.values())
    print(f"build={args.build}")
    print(f"reward achievements={len(records)}")
    print(f"direct item IDs={direct_count}")
    print(f"inferred item IDs={inferred_count}")
    print(f"unresolved model rewards={len(unresolved)}")


if __name__ == "__main__":
    main()
