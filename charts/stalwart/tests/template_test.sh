#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
chart="$repo_root/charts/stalwart"
fixture="$repo_root/.github/fixtures/stalwart-values.yaml"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

helm lint --strict "$chart"
helm lint --strict "$chart" --values "$fixture"

# Values from an upstream 0.1.0 release keep the existing resource names.
helm template stalwart "$chart" --values "$fixture" >"$test_dir/existing.yaml"
grep -Fx '  name: stalwart' "$test_dir/existing.yaml"
grep -Fx '  name: stalwart-env' "$test_dir/existing.yaml"
grep -Fx '  name: stalwart-config' "$test_dir/existing.yaml"
grep -Fx '  name: stalwart-headless' "$test_dir/existing.yaml"
grep -F '"@type": "PostgreSql"' "$test_dir/existing.yaml"
grep -F 'image: "stalwartlabs/stalwart:v0.16.20"' "$test_dir/existing.yaml"
if grep -E 'kind: PersistentVolumeClaim|volumeClaimTemplates' "$test_dir/existing.yaml"; then
  echo "Disabled persistence must not create a volume claim" >&2
  exit 1
fi

# The tls-sync sidecar renders only when mailTls is enabled.
for values in "--values $fixture" ""; do
  # shellcheck disable=SC2086
  helm template stalwart "$chart" $values >"$test_dir/no-tls.yaml"
  if grep -E 'tls-sync|mail-tls|secretName: *$' "$test_dir/no-tls.yaml"; then
    echo "mailTls is disabled, but the chart renders the tls-sync sidecar" >&2
    exit 1
  fi
done

# mailTls with an existing recovery admin Secret.
helm template stalwart "$chart" --values "$fixture" \
  --set 'mailTls.enabled=true' \
  --set 'mailTls.existingSecret=mail-tls' \
  --set 'mailTls.hostname=mail.example.invalid' \
  --set 'mailTls.domain=example.invalid' \
  --set 'recoveryAdmin.existingSecret=stalwart-admin' >"$test_dir/tls-existing.yaml"
grep -F 'name: tls-sync' "$test_dir/tls-existing.yaml"
grep -F 'secretName: mail-tls' "$test_dir/tls-existing.yaml"
grep -F 'name: stalwart-admin' "$test_dir/tls-existing.yaml"

# mailTls with an inline recovery admin password uses the chart-managed Secret.
helm template stalwart "$chart" --values "$fixture" \
  --set 'mailTls.enabled=true' \
  --set 'mailTls.existingSecret=mail-tls' \
  --set 'mailTls.hostname=mail.example.invalid' \
  --set 'mailTls.domain=example.invalid' \
  --set-string 'recoveryAdmin.password=ci-password' >"$test_dir/tls-inline.yaml"
grep -F 'STALWART_RECOVERY_ADMIN: "admin:ci-password"' "$test_dir/tls-inline.yaml"
if grep -E 'secretKeyRef:' -A1 "$test_dir/tls-inline.yaml" | grep -E 'name: *$'; then
  echo "tls-sync must not reference a Secret without a name" >&2
  exit 1
fi

# mailTls without a certificate Secret fails.
if helm template stalwart "$chart" --set 'mailTls.enabled=true' >/dev/null 2>&1; then
  echo "Expected mailTls without existingSecret to fail" >&2
  exit 1
fi

# Bootstrap with an inline password renders the Secret that the Job reads.
helm template stalwart "$chart" \
  --set 'bootstrap.enabled=true' \
  --set 'bootstrap.domain=example.invalid' \
  --set 'bootstrap.oidc.issuerUrl=https://sso.example.invalid' \
  --set-string 'recoveryAdmin.password=ci-password' >"$test_dir/bootstrap.yaml"
grep -F 'kind: Job' "$test_dir/bootstrap.yaml"
grep -F '# Source: stalwart/templates/secret.yaml' "$test_dir/bootstrap.yaml"

# Enabled recovery admin without credentials fails.
if helm template stalwart "$chart" --set 'recoveryAdmin.enabled=true' >/dev/null 2>&1; then
  echo "Expected recoveryAdmin without credentials to fail" >&2
  exit 1
fi

# The dedicated mail LoadBalancer Service.
helm template stalwart "$chart" --values "$fixture" \
  --set 'mailService.enabled=true' \
  --set 'mailService.name=stalwart-mail' \
  --set 'mailService.externalTrafficPolicy=Local' >"$test_dir/mail-service.yaml"
grep -Fx '  name: stalwart-mail' "$test_dir/mail-service.yaml"
grep -F 'externalTrafficPolicy: "Local"' "$test_dir/mail-service.yaml"

# Ingress for the management listener.
helm template stalwart "$chart" --values "$fixture" \
  --set 'ingress.enabled=true' \
  --set 'ingress.hosts[0].host=mail.example.invalid' \
  --set 'ingress.hosts[0].paths[0].path=/' \
  --set 'ingress.hosts[0].paths[0].pathType=Prefix' \
  --set 'ingress.hosts[0].paths[0].portName=mgmt' >"$test_dir/ingress.yaml"
grep -F 'kind: Ingress' "$test_dir/ingress.yaml"
