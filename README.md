# Helm Charts

Personal Helm chart repository for self-hosted applications without an actively maintained upstream chart.

## Charts

| Chart | App Version | Notes |
| --- | --- | --- |
| `mediumauth` | `0.2.0` | Mediumauth with encrypted database-managed configuration, forward authentication, OAuth, LDAP, and OIDC support. |
| `paperless-ngx` | `3.2.1` | Based on `gabe565/charts` `paperless-ngx` and kept values-compatible for existing deployments. |
| `stalwart` | `v0.16.23` | Based on `kgrubb/stalwart-helm-chart` and kept values-compatible for existing deployments. |

### Deprecated

These charts are no longer maintained or updated. The last published versions remain available.

| Chart | Last Version | App Version |
| --- | --- | --- |
| `documenso` | `0.1.2` | `2.18.0` |
| `grist` | `0.1.3` | `1.7.19` |

## OCI Usage

Charts are published to GitHub Container Registry by CI:

```console
helm install paperless-ngx oci://ghcr.io/pr0ton11/charts/paperless-ngx
helm install mediumauth oci://ghcr.io/pr0ton11/charts/mediumauth -f values.yaml
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

- the chart's `values.yaml` `image.tag`
- the chart's `Chart.yaml` `appVersion`
- the chart's `Chart.yaml` chart `version`

The PR must pass the `Charts` CI check before merging into `main`.
After merge, the release workflow packages the chart and pushes it to GitHub Container Registry.
