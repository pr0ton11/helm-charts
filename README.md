# Helm Charts

Personal Helm chart repository for charts that are no longer maintained upstream.

## Charts

| Chart | App Version | Notes |
| --- | --- | --- |
| `paperless-ngx` | `2.20.15` | Based on `gabe565/charts` `paperless-ngx` and kept values-compatible for existing deployments. |

## OCI Usage

Charts are published to GitHub Container Registry by CI:

```console
helm install paperless-ngx oci://ghcr.io/pr0ton11/charts/paperless-ngx
```

For Rancher `HelmChart` resources, use:

```yaml
spec:
  chart: oci://ghcr.io/pr0ton11/charts/paperless-ngx
```

## Renovate Updates

Renovate watches chart application image tags and opens pull requests when upstream images publish new versions.
For `paperless-ngx`, the Renovate PR should update:

- `charts/paperless-ngx/values.yaml` `image.tag`
- `charts/paperless-ngx/Chart.yaml` `appVersion`
- `charts/paperless-ngx/Chart.yaml` chart `version`

The PR must pass the `Charts` CI check before merging into `main`.
After merge, the release workflow packages the chart and pushes it to GitHub Container Registry.
