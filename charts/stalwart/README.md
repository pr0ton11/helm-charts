# stalwart

Deploys [Stalwart Mail Server](https://stalw.art/) as a StatefulSet with persistent storage and standard mail listeners.

Imported from [kgrubb/stalwart-helm-chart](https://github.com/kgrubb/stalwart-helm-chart) `0.7.19` (Apache-2.0) and maintained here.
Values from upstream chart `0.1.0` and later render without changes.

## Upgrading from kgrubb/stalwart-helm-chart

Change the chart source and keep the existing values and release name:

```yaml
spec:
  chart: oci://ghcr.io/pr0ton11/charts/stalwart
  version: 0.8.0
```

Changes that affect running releases:

- Pods get the `app.kubernetes.io/component: server` label, and Services select on it. The StatefulSet selector does not change.
- Probes run `curl` inside the container against the management listener, and a startup probe allows up to five minutes for startup.

## Values

| Key | Default | Notes |
| --- | --- | --- |
| `nameOverride` | `""` | Override the chart name |
| `fullnameOverride` | `""` | Override the resource name prefix |
| `image.repository` | `stalwartlabs/stalwart` | Container image |
| `image.tag` | chart `appVersion` | Pin for controlled upgrades |
| `replicaCount` | `1` | Keep at `1` for local RocksDB |
| `recoveryAdmin.enabled` | `false` | Enable for first bootstrap only |
| `recoveryAdmin.existingSecret` | `""` | Pre-created Secret for recovery admin credentials |
| `recoveryAdmin.usernameKey` | `username` | Secret key for recovery admin username |
| `recoveryAdmin.passwordKey` | `password` | Secret key for recovery admin password |
| `bootstrap.enabled` | `false` | Run hook Job to provision domain, accounts, and OIDC directory |
| `bootstrap.domain` | `""` | Mail domain name for bootstrap |
| `bootstrap.oidc.issuerUrl` | `""` | OIDC provider issuer URL |
| `config` | RocksDB data store | Only DataStore belongs in `config.json` |
| `service.type` | `ClusterIP` | Main Service; use with ingress for management UI |
| `mailService.enabled` | `false` | Separate LoadBalancer for SMTP/IMAP/POP3/Sieve |
| `mailService.name` | `""` | Optional Service name (e.g. `stalwart-mail`) when adopting a hand-maintained LoadBalancer |
| `mailService.annotations` | `{}` | e.g. MetalLB `metallb.universe.tf/loadBalancerIPs` |
| `mailTls.enabled` | `false` | Load a cert-manager TLS Secret into Stalwart with the `tls-sync` sidecar |
| `mailTls.existingSecret` | `""` | Required when `mailTls.enabled` is `true` |
| `ingress.enabled` | `false` | HTTP/S management only |
| `persistence.enabled` | `true` | Disable for external DataStore backends |
| `resources` | `{}` | Set CPU/memory requests and limits per environment |
| `podSecurityContext` | non-root, `RuntimeDefault` seccomp | Runs as UID/GID 2000 |
| `containerSecurityContext` | drops all caps, keeps `NET_BIND_SERVICE` | Needed for privileged mail ports |

`bootstrap` provisions domain, accounts, and an external OIDC directory. Register the IdP app and Secrets outside the chart. Set `STALWART_PUBLIC_URL` and route ingress to `mgmt` for WebUI login.

See [values.yaml](values.yaml) and the [Stalwart Kubernetes docs](https://stalw.art/docs/cluster/orchestration/kubernetes/) for clustering, external stores, and restricted Pod Security Standards.
