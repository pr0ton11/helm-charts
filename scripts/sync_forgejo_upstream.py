#!/usr/bin/env python3
"""Merge published upstream Forgejo chart changes without changing the app version."""
import argparse
from pathlib import Path
import re
import subprocess
import tempfile

import yaml

UPSTREAM = "oci://code.forgejo.org/forgejo-helm/forgejo"
VERSION_KEY = "helm-charts.pr0ton11/upstream-chart-version"
DIGEST_KEY = "helm-charts.pr0ton11/upstream-chart-digest"
ROOT = Path(__file__).resolve().parents[1]


def version_tuple(version):
    if not re.fullmatch(r"\d+\.\d+\.\d+", str(version)):
        raise ValueError(f"Expected a stable semantic version: {version}")
    return tuple(map(int, version.split(".")))


def managed_files(root):
    """Map upstream paths to fork paths. Local-only files remain untouched."""
    files = {}
    for path in root.rglob("*"):
        relative = path.relative_to(root)
        if relative.parts[0] not in {"templates", "scripts", "docs"} and str(relative) not in {
            "values.yaml", "values.schema.json", "Chart.lock", "LICENSE", "README.md"
        }:
            continue
        if path.is_symlink():
            raise ValueError(f"Upstream symlink is not supported: {relative}")
        if path.is_file():
            target = Path("UPSTREAM.md") if str(relative) == "README.md" else relative
            files[target] = path.read_bytes()
    return files


def merge_file(ours, base, theirs, name):
    if ours == base:
        return theirs
    if theirs == base or ours == theirs:
        return ours
    if None in (ours, base, theirs):
        raise ValueError(f"Upstream add/delete conflicts with local changes: {name}")
    with tempfile.TemporaryDirectory(prefix="forgejo-merge-") as directory:
        paths = [Path(directory) / x for x in ("ours", "base", "theirs")]
        for path, data in zip(paths, (ours, base, theirs)):
            path.write_bytes(data)
        result = subprocess.run(
            ["git", "merge-file", "-p", *map(str, paths)], capture_output=True
        )
    if result.returncode:
        raise ValueError(f"Upstream changes conflict with local changes: {name}")
    return result.stdout


def plan_sync(chart, base, candidate):
    old = managed_files(base)
    new = managed_files(candidate)
    plan = {}
    for name in sorted(old.keys() | new.keys()):
        path = chart / name
        ours = path.read_bytes() if path.exists() else None
        merged = merge_file(ours, old.get(name), new.get(name), name)
        if merged != ours:
            plan[name] = merged
    # appVersion remains authoritative even if upstream starts pinning an image.
    values = plan.get(Path("values.yaml"))
    if values is not None:
        image = yaml.safe_load(values).get("image", {})
        if any(image.get(key) for key in ("tag", "digest", "fullOverride")):
            raise ValueError("Upstream values would override the fork's application version")
    return plan


def download(version, directory):
    result = subprocess.run(
        ["helm", "pull", UPSTREAM, "--version", version, "--untar", "--untardir", str(directory)],
        check=True, capture_output=True, text=True,
    )
    match = re.search(r"Digest: (sha256:[a-f0-9]{64})", result.stderr + result.stdout)
    if not match:
        raise ValueError("Helm did not report the upstream OCI digest")
    return directory / "forgejo", match[1]


def update_metadata(text, upstream, version, digest):
    metadata = yaml.safe_load(text)
    current = metadata["version"]
    major, minor, patch = version_tuple(current)
    # Replace only fork-owned fields. Keep comments, appVersion and tracking intact.
    text = re.sub(r"^version: .+$", f"version: {major}.{minor}.{patch + 1}", text, flags=re.M)
    text = re.sub(rf"^(  {re.escape(VERSION_KEY)}:) .+$", rf"\1 {version}", text, flags=re.M)
    text = re.sub(rf"^(  {re.escape(DIGEST_KEY)}:) .+$", rf"\1 {digest}", text, flags=re.M)
    # Chart.yaml owns fork metadata; dependencies follow the upstream lock file.
    text = re.sub(r"^dependencies:\n[\s\S]*\Z", "", text, flags=re.M)
    text += yaml.safe_dump({"dependencies": upstream.get("dependencies", [])}, sort_keys=False)
    return text


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--upstream-version", help="Published stable chart version; defaults to the latest")
    args = parser.parse_args()
    chart = ROOT / "charts/forgejo"
    metadata_path = chart / "Chart.yaml"
    original = metadata_path.read_text()
    metadata = yaml.safe_load(original)
    annotations = metadata["annotations"]
    previous = annotations[VERSION_KEY]
    latest = args.upstream_version
    if latest is None:
        latest = yaml.safe_load(subprocess.check_output(
            ["helm", "show", "chart", UPSTREAM], text=True
        ))["version"]
    if version_tuple(latest) < version_tuple(previous):
        raise ValueError("Refusing to move the upstream baseline backwards")
    if latest == previous:
        print(f"Forgejo upstream chart {latest} is already integrated")
        return
    with tempfile.TemporaryDirectory(prefix="forgejo-upstream-") as directory:
        base, base_digest = download(previous, Path(directory) / "base")
        if base_digest != annotations[DIGEST_KEY]:
            raise ValueError("The previous upstream artifact no longer matches its recorded digest")
        candidate, digest = download(latest, Path(directory) / "candidate")
        upstream = yaml.safe_load((candidate / "Chart.yaml").read_text())
        if upstream["name"] != "forgejo" or upstream["version"] != latest:
            raise ValueError("Unexpected upstream chart identity")
        # Compute all merges first. A conflict leaves the working tree unchanged.
        plan = plan_sync(chart, base, candidate)
        updated = update_metadata(original, upstream, latest, digest)
        assert yaml.safe_load(updated)["appVersion"] == metadata["appVersion"]
        for name, contents in plan.items():
            path = chart / name
            if contents is None:
                path.unlink()
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(contents)
        metadata_path.write_text(updated)
    print(f"Integrated upstream chart {previous} -> {latest}; application version remains {metadata['appVersion']}")


if __name__ == "__main__":
    main()
