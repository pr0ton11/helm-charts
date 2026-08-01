# Grist

![Version: 0.1.1](https://img.shields.io/badge/Version-0.1.1-informational?style=flat)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat)
![AppVersion: 1.7.17](https://img.shields.io/badge/AppVersion-1.7.17-informational?style=flat)

A modern relational spreadsheet

**Homepage:** <https://www.getgrist.com>

**This chart is not maintained by the upstream project and any issues with the chart should be raised
in this repository.**

## Source Code

* <https://github.com/gristlabs/grist-core>

## Requirements

Kubernetes: `>=1.31.0-0`

## Dependencies

| Repository | Name | Version |
|------------|------|---------|
| <https://bjw-s-labs.github.io/helm-charts> | common | 5.0.1 |

## Installing the Chart

```console
helm install grist oci://ghcr.io/pr0ton11/charts/grist -f values.yaml
```

## Uninstalling the Chart

```console
helm uninstall grist
```

The command removes Kubernetes components created by the chart. Retained
persistent volumes remain subject to their configured resource policy.

## Custom configuration

### Required configuration

Grist requires a stable session secret. Keep it in a Kubernetes Secret:

```yaml
env:
  GRIST_SESSION_SECRET:
    secretKeyRef:
      name: grist-env
      key: GRIST_SESSION_SECRET
  GRIST_DEFAULT_EMAIL: admin@example.com
```

You can alternatively load a complete Secret or ConfigMap:

```yaml
envFrom:
  - secret: grist-env
```

Required-variable validation is skipped when `envFrom` is configured because Helm cannot inspect referenced objects.
Explicit `env` values take precedence over variables loaded through `envFrom`.

`GRIST_DEFAULT_EMAIL` identifies the initial installation owner. Change the default before completing first-run setup.

### Persistence

The `/persist` volume contains documents, the default SQLite home database, sessions, and instance configuration.
It is enabled and retained by default:

```yaml
persistence:
  data:
    enabled: true
    retain: true
    size: 20Gi
```

Do not disable this volume unless all durable data has been deliberately moved to external services.
The default `ReadWriteOnce` volume and SQLite databases support one Grist replica, so the chart uses a `Recreate` deployment strategy.

### PostgreSQL

Grist uses SQLite for its home metadata database by default.
To use an external PostgreSQL 10–16 database, set the documented TypeORM values under `env`:

```yaml
env:
  TYPEORM_TYPE: postgres
  TYPEORM_DATABASE: grist
  TYPEORM_USERNAME: grist
  TYPEORM_PASSWORD:
    secretKeyRef:
      name: grist-postgresql
      key: password
  TYPEORM_HOST: postgresql.example.com
  TYPEORM_PORT: "5432"
```

PostgreSQL replaces only the home metadata database; Grist documents still require `/persist` or external snapshot storage.
The chart does not bundle PostgreSQL because the current dependency available in this repository runs PostgreSQL 18, outside Grist's documented compatibility range.

### Redis

Redis is optional for basic Grist use, required for webhooks and notifications, and recommended for snapshots.
Enable the chart-managed Redis instance with:

```yaml
redis:
  enabled: true
  master:
    persistence:
      enabled: true
      size: 1Gi
```

The chart injects `REDIS_URL`.
For an external Redis service, leave `redis.enabled=false` and set `REDIS_URL` through `env` or `envFrom`.
Use a URL-safe `redis.auth.password`; when an existing Secret contains reserved URL characters, provide a complete encoded `REDIS_URL` explicitly.

### Exposing Grist

The chart supports Kubernetes Ingress through the bjw-s common chart and Gateway API through a chart-managed `HTTPRoute`.
Both derive `APP_HOME_URL` from the configured host unless it is set explicitly.
Ingress controllers and gateways must preserve WebSocket upgrade traffic.

```yaml
ingress:
  main:
    enabled: true
    hosts:
      - host: grist.example.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: grist-example-tls
        hosts:
          - grist.example.com
```

```yaml
gateway:
  main:
    enabled: true
    protocol: https
    parentRefs:
      - name: gateway
        namespace: gateway-system
        sectionName: https
    hosts:
      - host: grist.example.com
        paths:
          - path: /
            pathType: PathPrefix
```

### Formula sandboxing

The chart defaults `GRIST_SANDBOX_FLAVOR=pyodide`, which does not require extra Linux capabilities and supports both published image architectures.
Upstream recommends gVisor when compatible x86 hardware and `SYS_PTRACE` are available; enable it explicitly only after checking the node and runtime.

See the [self-managed Grist guide](https://support.getgrist.com/self-managed/) and the commented entries in [`values.yaml`](./values.yaml) for database, Redis, S3-compatible snapshots, email, OIDC, SAML, forward-auth, webhook, and UI settings.

## Values

**Important**: This chart inherits additional values from the [bjw-s common library chart](https://github.com/bjw-s-labs/helm-charts/tree/main/charts/library/common).

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| env | object | See [values.yaml](./values.yaml) | Grist environment variables. |
| envFrom | list | `[]` | Secrets and ConfigMaps loaded as environment variables. |
| gateway.main | object | See [values.yaml](./values.yaml) | Enable and configure Gateway API HTTPRoute. |
| image.pullPolicy | string | `"IfNotPresent"` | Image pull policy |
| image.repository | string | `"docker.io/gristlabs/grist"` | Image repository |
| image.tag | string | `"1.7.17"` | Image tag |
| ingress.main | object | See [values.yaml](./values.yaml) | Enable and configure Kubernetes Ingress. |
| persistence | object | See [values.yaml](./values.yaml) | Persistent Grist instance storage. |
| redis | object | See [values.yaml](./values.yaml) | Optional chart-managed Redis. |
| replicaCount | int | `1` | Number of Grist replicas. |
| resources | object | See [values.yaml](./values.yaml) | Grist container resources. |
| service.main | object | See [values.yaml](./values.yaml) | Configures the Grist service. |
