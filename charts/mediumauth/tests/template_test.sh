#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
chart="$repo_root/charts/mediumauth"
fixture="$repo_root/.github/fixtures/mediumauth-values.yaml"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

helm lint --strict "$chart" --values "$fixture"

# SQLite with persistence and a chart-managed Secret.
helm template mediumauth "$chart" --values "$fixture" >"$test_dir/sqlite.yaml"
rg -F 'kind: PersistentVolumeClaim' "$test_dir/sqlite.yaml"
rg -F 'stringData:' "$test_dir/sqlite.yaml"
rg -F 'TINYAUTH_CONFIG_ENCRYPTION_KEY: "MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY="' "$test_dir/sqlite.yaml"
rg -F 'path: /api/healthz' "$test_dir/sqlite.yaml"
rg -F 'path: /api/readyz' "$test_dir/sqlite.yaml"

# The normal Deployment must use the current key only.
if rg -F 'TINYAUTH_CONFIG_NEW_ENCRYPTION_KEY' "$test_dir/sqlite.yaml"; then
  echo "The Deployment must not contain TINYAUTH_CONFIG_NEW_ENCRYPTION_KEY" >&2
  exit 1
fi

# Existing Secret and key.
helm template mediumauth "$chart" \
  --set 'configEncryptionKey.existingSecret=mediumauth-config' \
  --set 'configEncryptionKey.existingSecretKey=managed-key' \
  --set 'envFrom[0].secret=mediumauth-env' >"$test_dir/existing-secret.yaml"
rg -F 'name: mediumauth-config' "$test_dir/existing-secret.yaml"
rg -F 'key: managed-key' "$test_dir/existing-secret.yaml"
if rg -F '# Source: mediumauth/templates/secret.yaml' "$test_dir/existing-secret.yaml"; then
  echo "The chart must not create a Secret when existingSecret is configured" >&2
  exit 1
fi

# PostgreSQL without a PersistentVolume and with multiple replicas.
helm template mediumauth "$chart" --values "$fixture" \
  --set 'env.TINYAUTH_DATABASE_DRIVER=postgres' \
  --set 'env.TINYAUTH_DATABASE_PATH=postgres://mediumauth@example.invalid/mediumauth' \
  --set 'persistence.data.enabled=false' \
  --set 'replicaCount=2' >"$test_dir/postgresql.yaml"
rg -F 'replicas: 2' "$test_dir/postgresql.yaml"
if rg -F 'kind: PersistentVolumeClaim' "$test_dir/postgresql.yaml"; then
  echo "PostgreSQL without persistence must not create a PersistentVolumeClaim" >&2
  exit 1
fi

# Ingress and Gateway API exposure remain supported.
helm template mediumauth "$chart" --values "$fixture" \
  --set-string 'env.TINYAUTH_APPURL=' \
  --set 'ingress.main.enabled=true' \
  --set 'ingress.main.hosts[0].host=auth.example.invalid' \
  --set 'ingress.main.hosts[0].paths[0].path=/' \
  --set 'ingress.main.hosts[0].paths[0].pathType=Prefix' >"$test_dir/ingress.yaml"
rg -F 'value: http://auth.example.invalid' "$test_dir/ingress.yaml"

helm template mediumauth "$chart" --values "$fixture" \
  --api-versions gateway.networking.k8s.io/v1/HTTPRoute \
  --set-string 'env.TINYAUTH_APPURL=' \
  --set 'gateway.main.enabled=true' \
  --set 'gateway.main.parentRefs[0].name=public' \
  --set 'gateway.main.hosts[0].host=auth.example.invalid' \
  --set 'ingressDiscovery.enabled=true' >"$test_dir/gateway.yaml"
rg -F 'kind: HTTPRoute' "$test_dir/gateway.yaml"
rg -F 'kind: ClusterRole' "$test_dir/gateway.yaml"
rg -F 'value: https://auth.example.invalid' "$test_dir/gateway.yaml"

# Missing or malformed keys must fail.
if helm template mediumauth "$chart" \
  --set 'envFrom[0].secret=mediumauth-env' >"$test_dir/missing-key.out" 2>"$test_dir/missing-key.err"; then
  echo "The chart must reject a missing configuration encryption key" >&2
  exit 1
fi
rg -F 'configEncryptionKey' "$test_dir/missing-key.err"

if helm template mediumauth "$chart" \
  --set-string 'configEncryptionKey.value=not-base64' \
  --set 'envFrom[0].secret=mediumauth-env' >"$test_dir/invalid-key.out" 2>"$test_dir/invalid-key.err"; then
  echo "The chart must reject a malformed configuration encryption key" >&2
  exit 1
fi
rg -F '/configEncryptionKey/value' "$test_dir/invalid-key.err"

if helm template mediumauth "$chart" --values "$fixture" \
  --set-string 'env.TINYAUTH_CONFIG_NEW_ENCRYPTION_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=' \
  >"$test_dir/new-key.out" 2>"$test_dir/new-key.err"; then
  echo "The chart must reject the offline rotation key in the Deployment" >&2
  exit 1
fi
rg -F 'Do not set TINYAUTH_CONFIG_NEW_ENCRYPTION_KEY' "$test_dir/new-key.err"

# SQLite must retain persistent storage and a single replica.
if helm template mediumauth "$chart" --values "$fixture" \
  --set 'persistence.data.enabled=false' >"$test_dir/sqlite-storage.out" 2>"$test_dir/sqlite-storage.err"; then
  echo "The chart must reject SQLite without persistence" >&2
  exit 1
fi
rg -F 'SQLite requires persistence.data.enabled=true' "$test_dir/sqlite-storage.err"

if helm template mediumauth "$chart" --values "$fixture" \
  --set 'replicaCount=2' >"$test_dir/sqlite-replicas.out" 2>"$test_dir/sqlite-replicas.err"; then
  echo "The chart must reject multiple SQLite replicas" >&2
  exit 1
fi
rg -F 'replicaCount greater than 1 requires a shared PostgreSQL database' "$test_dir/sqlite-replicas.err"
