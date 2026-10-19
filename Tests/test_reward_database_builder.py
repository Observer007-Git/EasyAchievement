import csv
import importlib.util
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "reward_builder", ROOT / "Tools" / "build_reward_database.py")
BUILDER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILDER)
EXPORT_SPEC = importlib.util.spec_from_file_location(
    "reward_workbook_exporter",
    ROOT / "Tools" / "export_reward_workbook_data.py")
EXPORTER = importlib.util.module_from_spec(EXPORT_SPEC)
EXPORT_SPEC.loader.exec_module(EXPORTER)


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


class RewardDatabaseBuilderTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.input_dir = Path(self.temporary.name)
        achievements = [
            (1, 100, "Mount Direct", "Mount: Sky Steed", 0),
            (2, 0, "Pet Prize", "Pet: Tiny Friend", 1),
            (3, 100, "Two Rewards", "Mount: Sky Steed\nDecor: Cozy Chair", -1),
            (4, 0, "Title Prize", "Title: Keeper", -1),
            (5, 0, "Missing Mount", "Mount: Missing", -1),
            (6, 0, "Currency Prize", "Currency: Token", -1),
            (7, 0, "Toy Prize", "Toy: Fun Box", -1),
            (8, 0, "Appearance Prize", "Appearance: Hero Set", -1),
            (9, 0, "Decor Prize", "Decor: Retro Chair", -1),
            (10, 999, "Item Prize", "Reward: Token", -1),
        ]
        for locale in BUILDER.LOCALES:
            write_csv(self.input_dir / locale / "Achievement.csv",
                ("ID", "RewardItemID", "Title_lang", "Reward_lang",
                 "Faction"),
                ({"ID": row[0], "RewardItemID": row[1],
                  "Title_lang": row[2], "Reward_lang": row[3],
                  "Faction": row[4]}
                 for row in achievements))
            write_csv(self.input_dir / locale / "Creature.csv",
                ("ID", "Name_lang"),
                ({"ID": 20, "Name_lang": "Tiny Friend"},))
            write_csv(self.input_dir / locale / "BattlePetSpecies.csv",
                ("SummonSpellID", "SourceText_lang", "CreatureID"),
                ({"SummonSpellID": 2000,
                  "SourceText_lang": "Achievement: Pet Prize",
                  "CreatureID": 20},))
            write_csv(self.input_dir / locale / "Mount.csv",
                ("SourceSpellID", "SourceText_lang", "Name_lang"),
                ({"SourceSpellID": 1000,
                  "SourceText_lang": "Achievement: Mount Direct",
                  "Name_lang": "Sky Steed"},))
            write_csv(self.input_dir / locale / "Toy.csv",
                ("ItemID", "SourceText_lang"),
                ({"ItemID": 400,
                  "SourceText_lang": "Achievement: Toy Prize"},))
            write_csv(self.input_dir / locale / "HouseDecor.csv",
                ("ID", "ItemID", "Name_lang"),
                ({"ID": 30, "ItemID": 300,
                  "Name_lang": "Cozy Chair"},))
            write_csv(self.input_dir / locale / "ItemSparse.csv",
                ("ID", "Display_lang"), (
                    {"ID": 100, "Display_lang": "Sky Steed"},
                    {"ID": 200, "Display_lang": "Tiny Friend"},
                    {"ID": 300, "Display_lang": "Cozy Chair"},
                    {"ID": 400, "Display_lang": "Fun Box"},
                    {"ID": 500, "Display_lang": "Hero Armor"},
                    {"ID": 999, "Display_lang": "Token"},
                ))
            write_csv(self.input_dir / locale / "TransmogSet.csv",
                ("ID", "Name_lang"),
                ({"ID": 60, "Name_lang": "Hero Set"},))

        write_csv(self.input_dir / "common" / "ItemEffect.csv",
            ("ID", "SpellID"), (
                {"ID": 1, "SpellID": 1000},
                {"ID": 2, "SpellID": 2000},
            ))
        write_csv(self.input_dir / "common" / "ItemXItemEffect.csv",
            ("ItemEffectID", "ItemID"), (
                {"ItemEffectID": 1, "ItemID": 100},
                {"ItemEffectID": 2, "ItemID": 200},
            ))
        write_csv(self.input_dir / "common" / "ItemModifiedAppearance.csv",
            ("ID", "ItemID"), ({"ID": 50, "ItemID": 500},))
        write_csv(self.input_dir / "common" / "TransmogSetItem.csv",
            ("ItemModifiedAppearanceID", "TransmogSetID"),
            ({"ItemModifiedAppearanceID": 50, "TransmogSetID": 60},))
        write_csv(self.input_dir / "common" / "RetroactiveDecorReward.csv",
            ("HouseDecorID", "AchievementID"),
            ({"HouseDecorID": 30, "AchievementID": 9},))

    def tearDown(self):
        self.temporary.cleanup()

    def test_categories_combine_structured_tables_and_reward_text(self):
        records, categories, unresolved, inferred_count, factions = \
            BUILDER.build_database(self.input_dir)

        self.assertEqual(categories[1], ["mount"])
        self.assertEqual(categories[2], ["pet"])
        self.assertEqual(categories[3], ["mount", "decor"])
        self.assertEqual(categories[4], ["title"])
        self.assertEqual(categories[5], ["mount"])
        self.assertEqual(categories[6], ["other"])
        self.assertEqual(categories[7], ["toy"])
        self.assertEqual(categories[8], ["appearance"])
        self.assertEqual(categories[9], ["decor"])
        self.assertEqual(categories[10], ["other"])
        self.assertIn((0, 200), records[2])
        self.assertIn((0, 300), records[3])
        self.assertIn((0, 400), records[7])
        self.assertIn((0, 500), records[8])
        self.assertIn((0, 300), records[9])
        self.assertGreaterEqual(inferred_count, 5)
        self.assertTrue(any(row[0] == 5 for row in unresolved))
        self.assertEqual(factions, {1: 0, 2: 1})

    def test_lua_output_uses_compact_schema_without_losing_semantics(self):
        records, categories, _, _, factions = BUILDER.build_database(
            self.input_dir)
        compact = BUILDER.compact_reward_values(records[3], categories[3])
        self.assertEqual(compact, [9, 100, -300])
        output = self.input_dir / "database.lua"
        BUILDER.write_lua(output, "test", records, categories, factions)
        source = output.read_text(encoding="utf-8")
        self.assertIn("schema=2", source)
        self.assertIn("rewards={", source)
        self.assertNotIn("records={", source)
        self.assertNotIn("categories={", source)
        self.assertIn("[3]={9,100,-300},", source)
        self.assertIn("factions={", source)
        self.assertIn("[1]=0,", source)

    def test_workbook_export_rows_keep_source_fields_and_all_rewards(self):
        payload = EXPORTER.build_payload(self.input_dir, "test-build")
        rows = payload["rows"]
        achievement_three = [row for row in rows if row[0] == 3]

        self.assertEqual(payload["achievementCount"], 10)
        self.assertEqual(payload["rewardRowCount"], len(rows))
        self.assertEqual(len(achievement_three), 2)
        self.assertEqual(achievement_three[0][4], "坐骑、装饰")
        self.assertEqual(achievement_three[0][5], "mount,decor")
        self.assertEqual({row[6] for row in achievement_three}, {100, 300})
        self.assertIn("IconFileID", payload["headers"])
        self.assertIn("LegacyAfterTimeEvent", payload["headers"])


if __name__ == "__main__":
    unittest.main()
