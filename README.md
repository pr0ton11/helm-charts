# Helm Charts

Personal Helm chart repository for charts that are no longer maintained upstream.

## Charts

| Chart | App Version | Notes |
| --- | --- | --- |
| `paperless-ngx` | `2.20.15` | Based on `gabe565/charts` `paperless-ngx` and kept values-compatible for existing deployments. |

## OCI Usage

Charts are published to GitHub Container Registry by CI:

```console
helm install paperless-ngx oci://ghcr.io/<owner>/charts/paperless-ngx
```

For Rancher `HelmChart` resources, use:

```yaml
spec:
  chart: oci://ghcr.io/<owner>/charts/paperless-ngx
```

