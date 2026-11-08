# Helm Charts

Personal Helm chart repository for self-hosted applications with independently managed chart and application updates.

## Charts

| Chart | App Version | Notes |
| --- | --- | --- |
| `paperless-ngx` | `3.2.1` | Based on `gabe565/charts` `paperless-ngx` and kept values-compatible for existing deployments. |
| [`forgejo`](charts/forgejo/README.md) | `17.0.1` | Based on upstream chart `17.3.2`, with stable application updates independent of its LTS default. |
| `stalwart` | `v1.0.0` | Based on `kgrubb/stalwart-helm-chart` and kept values-compatible for existing deployments. |

### Deprecated

These charts are no longer maintained or updated. The last published versions remain available.

| Chart | Last Version | App Version |
| --- | --- | --- |
| `documenso` | `0.1.2` | `2.18.0` |
| `grist` | `0.1.3` | `1.7.19` |
| `mediumauth` | `0.2.2` | `0.2.0` |

## OCI Usage

Charts are published to GitHub Container Registry by CI:

```console
helm install paperless-ngx oci://ghcr.io/pr0ton11/charts/paperless-ngx
helm install forgejo oci://ghcr.io/pr0ton11/charts/forgejo -f values.yaml
helm install stalwart oci://ghcr.io/pr0ton11/charts/stalwart -f values.yaml
```

For Rancher `HelmChart` resources, use:

```yaml
spec:
  chart: oci://ghcr.io/pr0ton11/charts/paperless-ngx
```

## Renovate Updates

Renovate watches chart application image tags and opens pull requests when upstream images publish new versions.
For application updates, the Renovate PR should update:

- the chart's `values.yaml` `image.tag` when the chart pins it there (Forgejo uses `appVersion` as its single default)
- the chart's `Chart.yaml` `appVersion`
- the chart's `Chart.yaml` chart `version`

The PR must pass the `Charts` CI check before merging into `main`.
After merge, the release workflow packages the chart and pushes it to GitHub Container Registry.
