import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


class BencherTests(unittest.TestCase):
    def convert(self, rows):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            results = directory / "benchres.csv"
            results.write_text(rows)
            subprocess.run(
                [sys.executable, str(Path(__file__).with_name("bencher.dev.py")), str(results)],
                cwd=directory,
                check=True,
                capture_output=True,
                text=True,
            )
            return {
                path.name: json.loads(path.read_text())
                for path in directory.glob("bencher.dev.*.json")
            }

    def test_statistics_are_per_allocator(self):
        output = self.convert(
            "cfrac sys 1.00 100 0 0 0 0\n"
            "cfrac mi 10.00 1000 0 0 0 0\n"
            "cfrac sys 3.00 300 0 0 0 0\n"
            "cfrac mi 14.00 1400 0 0 0 0\n"
        )
        self.assertEqual(output, {
            "bencher.dev.sys.json": {"cfrac": {
                "memory": {"value": 200.0, "high-value": 300.0, "low-value": 100.0},
                "time": {"value": 2.0, "high-value": 3.0, "low-value": 1.0},
            }},
            "bencher.dev.mi.json": {"cfrac": {
                "memory": {"value": 1200.0, "high-value": 1400.0, "low-value": 1000.0},
                "time": {"value": 12.0, "high-value": 14.0, "low-value": 10.0},
            }},
        })

    def test_allocators_can_run_different_benchmarks(self):
        output = self.convert(
            "cfrac sys 1.00 100 0 0 0 0\n"
            "espresso mi 2.00 200 0 0 0 0\n"
        )
        self.assertEqual(set(output), {"bencher.dev.sys.json", "bencher.dev.mi.json"})
        self.assertEqual(set(output["bencher.dev.sys.json"]), {"cfrac"})
        self.assertEqual(set(output["bencher.dev.mi.json"]), {"espresso"})


if __name__ == "__main__":
    unittest.main()
