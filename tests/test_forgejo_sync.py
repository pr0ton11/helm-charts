import importlib.util
from pathlib import Path
import tempfile
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("forgejo_sync", ROOT / "scripts/sync_forgejo_upstream.py")
sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync)


class UpstreamSyncTests(unittest.TestCase):
    def test_merge_preserves_local_and_upstream_edits(self):
        base = b"local: old\n\n\n\n\nupstream: old\n"
        ours = base.replace(b"local: old", b"local: custom")
        theirs = base.replace(b"upstream: old", b"upstream: new")
        self.assertEqual(sync.merge_file(ours, base, theirs, "values.yaml"),
                         b"local: custom\n\n\n\n\nupstream: new\n")

    def test_overlapping_edits_fail(self):
        with self.assertRaisesRegex(ValueError, "conflict"):
            sync.merge_file(b"local\n", b"base\n", b"upstream\n", "values.yaml")

    def test_modified_deleted_file_fails(self):
        with self.assertRaisesRegex(ValueError, "conflict"):
            sync.merge_file(b"local\n", b"base\n", None, "templates/example.yaml")

    def test_file_inventory_and_local_docs(self):
        with tempfile.TemporaryDirectory() as directory:
            chart, base, candidate = [Path(directory) / p for p in ("chart", "base", "candidate")]
            for p in (chart, base, candidate):
                (p / "templates").mkdir(parents=True)
            (base / "templates/removed.yaml").write_text("old")
            (chart / "templates/removed.yaml").write_text("old")
            (candidate / "templates/added.yaml").write_text("new")
            (chart / "README.md").write_text("local instructions")
            (candidate / "README.md").write_text("upstream instructions")
            plan = sync.plan_sync(chart, base, candidate)
            self.assertEqual(plan[Path("templates/removed.yaml")], None)
            self.assertEqual(plan[Path("templates/added.yaml")], b"new")
            self.assertEqual(plan[Path("UPSTREAM.md")], b"upstream instructions")
            self.assertNotIn(Path("README.md"), plan)
            self.assertTrue((chart / "templates/removed.yaml").exists())

    def test_upstream_cannot_pin_an_older_application_image(self):
        with tempfile.TemporaryDirectory() as directory:
            chart, base, candidate = [Path(directory) / p for p in ("chart", "base", "candidate")]
            for p in (chart, base, candidate):
                p.mkdir()
            for p in (chart, base):
                (p / "values.yaml").write_text("image:\n  tag: ''\n")
            (candidate / "values.yaml").write_text("image:\n  tag: '15.0.11'\n")
            with self.assertRaisesRegex(ValueError, "override"):
                sync.plan_sync(chart, base, candidate)
            self.assertEqual((chart / "values.yaml").read_text(), "image:\n  tag: ''\n")

    def test_chart_metadata_preserves_application_tracking(self):
        text = (ROOT / "charts/forgejo/Chart.yaml").read_text()
        before = yaml.safe_load(text)
        upstream = {"dependencies": [{"name": "common", "version": "99.0.0", "repository": "oci://example.invalid"}]}
        updated = sync.update_metadata(text, upstream, "17.4.0", "sha256:" + "a" * 64)
        after = yaml.safe_load(updated)
        self.assertEqual(after["appVersion"], before["appVersion"])
        self.assertEqual(after["name"], before["name"])
        self.assertEqual(after["dependencies"], upstream["dependencies"])
        self.assertEqual(after["annotations"][sync.VERSION_KEY], "17.4.0")
        self.assertEqual(after["annotations"][sync.DIGEST_KEY], "sha256:" + "a" * 64)
        self.assertIn("# renovate: datasource=docker", updated)
        current = sync.version_tuple(before["version"])
        self.assertEqual(after["version"], f"{current[0]}.{current[1]}.{current[2] + 1}")

    def test_prerelease_baselines_are_rejected(self):
        with self.assertRaises(ValueError):
            sync.version_tuple("18.0.0-rc1")


if __name__ == "__main__":
    unittest.main()
