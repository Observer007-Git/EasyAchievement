import importlib.util
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "retail_build_detector", ROOT / "Tools" / "detect_retail_build.py")
DETECTOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(DETECTOR)


class RetailBuildDetectorTests(unittest.TestCase):
    def test_selects_active_retail_product(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / ".build.info"
            path.write_text(
                "Product!STRING:0|Active!DEC:1|Version!STRING:0\n"
                "wow_classic|1|1.15.8.99999\n"
                "wow|0|12.1.5.70000\n"
                "wow|1|12.1.5.70575\n", encoding="utf-8")
            self.assertEqual(DETECTOR.detect_retail_build(path),
                "12.1.5.70575")

    def test_rejects_ambiguous_retail_build(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / ".build.info"
            path.write_text(
                "Product!STRING:0|Active!DEC:1|Version!STRING:0\n"
                "wow|1|12.1.5.70575\n"
                "wow|1|12.1.5.70600\n", encoding="utf-8")
            with self.assertRaises(ValueError):
                DETECTOR.detect_retail_build(path)


if __name__ == "__main__":
    unittest.main()
