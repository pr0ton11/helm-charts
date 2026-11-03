#!/usr/bin/env bash
set -euo pipefail
repo_root="$(git rev-parse --show-toplevel)"
chart="$repo_root/charts/monoscope"
fixture="$repo_root/.github/fixtures/monoscope-values.yaml"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

helm lint --strict "$chart" -f "$fixture"
helm template monoscope "$chart" -f "$fixture" > "$test_dir/managed.yaml"
grep -F 'kind: HTTPRoute' "$test_dir/managed.yaml"
grep -F 'kind: GRPCRoute' "$test_dir/managed.yaml"
grep -F 'appProtocol: kubernetes.io/h2c' "$test_dir/managed.yaml"
grep -F 'helm.sh/resource-policy: keep' "$test_dir/managed.yaml"
grep -F 'key: DATABASE_URL' "$test_dir/managed.yaml"
grep -F 'key: TIMEFUSION_PG_URL' "$test_dir/managed.yaml"
grep -F 'key: PGWIRE_PASSWORD' "$test_dir/managed.yaml"
test "$(grep -c 'key: AWS_ACCESS_KEY_ID' "$test_dir/managed.yaml")" -eq 2
# An IPv6-primary cluster must not change the backend address family. Check
# both the family and policy, rather than only the presence of a family field.
test "$(grep -c '^kind: Service$' "$test_dir/managed.yaml")" -eq 2
test "$(grep -Fxc '  ipFamilyPolicy: SingleStack' "$test_dir/managed.yaml")" -eq 2
test "$(grep -Fxc '  ipFamilies: [IPv4]' "$test_dir/managed.yaml")" -eq 2
grep -F '127.0.0.1/8080' "$test_dir/managed.yaml"
grep -F '/usr/local/bin/timefusion, healthcheck' "$test_dir/managed.yaml"
if grep -E '^[[:space:]]*(httpGet:|tcpSocket:|ipFamilies:.*IPv6)' "$test_dir/managed.yaml"; then
  echo 'Use IPv4 Services and loopback probes, not the IPv6-primary Pod IP' >&2
  exit 1
fi
if grep -E '^kind: Secret|image: .*:latest"' "$test_dir/managed.yaml"; then
  echo 'The chart must reference existing Secrets and pin image digests' >&2
  exit 1
fi

helm template monoscope "$chart" -f "$fixture" --set timefusion.enabled=false > "$test_dir/external.yaml"
test "$(grep -c '^kind: Service$' "$test_dir/external.yaml")" -eq 1
test "$(grep -Fxc '  ipFamilyPolicy: SingleStack' "$test_dir/external.yaml")" -eq 1
test "$(grep -Fxc '  ipFamilies: [IPv4]' "$test_dir/external.yaml")" -eq 1
if grep -E 'kind: PersistentVolumeClaim|key: PGWIRE_PASSWORD|name: monoscope-timefusion' "$test_dir/external.yaml"; then
  echo 'External TimeFusion must not render managed storage or a server' >&2
  exit 1
fi

helm template monoscope "$chart" -f "$fixture" \
  --set timefusion.persistence.existingClaim=tf-existing \
  --set s3.bucket=custom-bucket --set s3.accessKeyKey=access \
  --set s3.secretKeyKey=secret > "$test_dir/custom.yaml"
grep -F 'claimName: tf-existing' "$test_dir/custom.yaml"
test "$(grep -c 'value: "custom-bucket"' "$test_dir/custom.yaml")" -eq 2
test "$(grep -c 'key: access' "$test_dir/custom.yaml")" -eq 2
test "$(grep -c 'key: secret' "$test_dir/custom.yaml")" -eq 2
if grep -F 'kind: PersistentVolumeClaim' "$test_dir/custom.yaml"; then exit 1; fi

helm template monoscope "$chart" -f "$fixture" \
  --set gateway.enabled=false --set gateway.grpc.enabled=false \
  --set ingress.enabled=true --set ingress.hostname=mono.example.invalid \
  --set s3.endpoint=http://s3.internal:9000 --set s3.allowHttp=true > "$test_dir/ingress.yaml"
grep -F 'kind: Ingress' "$test_dir/ingress.yaml"
if grep -E 'kind: HTTPRoute|kind: GRPCRoute' "$test_dir/ingress.yaml"; then exit 1; fi

# Keep the generic cluster example renderable, including its IPv4 backend policy.
helm template monoscope "$chart" --namespace observability \
  -f "$chart/examples/cluster-values.yaml" > "$test_dir/cluster.yaml"
test "$(grep -Fxc '  ipFamilyPolicy: SingleStack' "$test_dir/cluster.yaml")" -eq 2
test "$(grep -Fxc '  ipFamilies: [IPv4]' "$test_dir/cluster.yaml")" -eq 2
grep -F 'sectionName: https' "$test_dir/cluster.yaml"

for setting in 'existingSecret=' 's3.bucket=' 's3.existingSecret=' \
  's3.endpoint=http://s3.internal:9000' 'ingress.enabled=true' \
  'gateway.parentRefs=null' 'gateway.grpc.hostnames=null'; do
  if helm template monoscope "$chart" -f "$fixture" --set "$setting" > /dev/null 2>&1; then
    echo "Expected invalid configuration to fail: $setting" >&2
    exit 1
  fi
done
echo 'Monoscope template checks passed'
