#!/usr/bin/env bash
set -euo pipefail
repo_root="$(git rev-parse --show-toplevel)"
chart="$repo_root/charts/forgejo"
fixture="$repo_root/.github/fixtures/forgejo-values.yaml"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

helm lint --strict "$chart" -f "$fixture"
helm template forgejo "$chart" --namespace example -f "$fixture" > "$test_dir/default.yaml"
app_version="$(helm show chart "$chart" | sed -n 's/^appVersion: //p' | tr -d '\"')"
# Check every application and init container. The HTTP hook uses a separate image.
test "$(grep -Fc "image: \"code.forgejo.org/forgejo/forgejo:${app_version}-rootless\"" "$test_dir/default.yaml")" -eq 4
grep -Fq 'claimName: gitea-shared-storage' "$test_dir/default.yaml"
grep -Fq 'name: forgejo-http' "$test_dir/default.yaml"
grep -Fq 'name: forgejo-ssh' "$test_dir/default.yaml"
grep -Fq 'kind: HTTPRoute' "$test_dir/default.yaml"
grep -Fq 'kind: TCPRoute' "$test_dir/default.yaml"
grep -Fq 'name: forgejo-admin' "$test_dir/default.yaml"
grep -Fq 'name: forgejo-database' "$test_dir/default.yaml"
grep -Fq 'type: Recreate' "$test_dir/default.yaml"
if grep -Fq 'name: forgejo-admin' <(sed -n '/^kind: Secret$/,/^---$/p' "$test_dir/default.yaml"); then
  echo 'An existing admin Secret must not be replaced' >&2
  exit 1
fi

# Existing installs can pin the application without receiving duplicate suffixes.
helm template forgejo "$chart" -f "$fixture" --set image.tag=16.0.6-rootless > "$test_dir/pinned.yaml"
test "$(grep -Fc 'image: "code.forgejo.org/forgejo/forgejo:16.0.6-rootless"' "$test_dir/pinned.yaml")" -eq 4
helm template forgejo "$chart" -f "$fixture" --set image.rootless=false > "$test_dir/rootful.yaml"
test "$(grep -Fc "image: \"code.forgejo.org/forgejo/forgejo:${app_version}\"" "$test_dir/rootful.yaml")" -eq 4
helm template forgejo "$chart" -f "$fixture" --set persistence.create=false > "$test_dir/existing.yaml"
grep -Fq 'claimName: gitea-shared-storage' "$test_dir/existing.yaml"
if grep -Fq 'kind: PersistentVolumeClaim' "$test_dir/existing.yaml"; then
  echo 'Existing storage must be reused without creating a claim' >&2
  exit 1
fi

# Prove the image follows appVersion when Renovate changes it.
cp -R "$chart" "$test_dir/chart"
sed -i 's/^appVersion: .*/appVersion: 99.0.1/' "$test_dir/chart/Chart.yaml"
helm template forgejo "$test_dir/chart" -f "$fixture" > "$test_dir/updated.yaml"
test "$(grep -Fc 'image: "code.forgejo.org/forgejo/forgejo:99.0.1-rootless"' "$test_dir/updated.yaml")" -eq 4
echo 'Forgejo template checks passed'
