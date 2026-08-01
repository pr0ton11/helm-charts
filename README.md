# Helm Charts

Personal Helm chart repository for self-hosted applications without an actively maintained upstream chart.

## Charts

| Chart | App Version | Notes |
| --- | --- | --- |
| `documenso` | `2.16.0` | Documenso with external or bundled PostgreSQL and optional Redis-backed jobs. |
| `grist` | `1.7.17` | Grist with persistent document storage, external PostgreSQL support, and optional Redis state. |
| `mediumauth` | `0.2.0` | Mediumauth with encrypted database-managed configuration, forward authentication, OAuth, LDAP, and OIDC support. |
| `paperless-ngx` | `3.0.4` | Based on `gabe565/charts` `paperless-ngx` and kept values-compatible for existing deployments. |

## OCI Usage

Charts are published to GitHub Container Registry by CI:

```console
helm install paperless-ngx oci://ghcr.io/pr0ton11/charts/paperless-ngx
helm install documenso oci://ghcr.io/pr0ton11/charts/documenso -f values.yaml
helm install grist oci://ghcr.io/pr0ton11/charts/grist -f values.yaml
helm install mediumauth oci://ghcr.io/pr0ton11/charts/mediumauth -f values.yaml
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
