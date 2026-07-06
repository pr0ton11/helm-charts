# Paperless-ngx

<img src="https://raw.githubusercontent.com/paperless-ngx/paperless-ngx/b948750/src-ui/src/assets/logo-notext.svg" align="right" width="92" alt="paperless-ngx logo">

![Version: 0.27.1](https://img.shields.io/badge/Version-0.27.1-informational?style=flat)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat)
![AppVersion: beta](https://img.shields.io/badge/AppVersion-beta-informational?style=flat)

A community-supported supercharged version of paperless: scan, index and archive all your physical documents

**Homepage:** <https://github.com/paperless-ngx/paperless-ngx>

**This chart is not maintained by the upstream project and any issues with the chart should be raised
in this repository.**

## Source Code

* <https://github.com/paperless-ngx/paperless-ngx>

## Requirements

Kubernetes: `>=1.22.0-0`

## Dependencies

| Repository | Name | Version |
|------------|------|---------|
| <https://bjw-s-labs.github.io/helm-charts> | common | 5.0.1 |
| <https://charts.bitnami.com/bitnami> | mariadb | 26.1.7 |
| <https://charts.bitnami.com/bitnami> | postgresql | 18.7.10 |

## Installing the Chart

To install the chart with the release name `paperless-ngx`

### OCI (Recommended)

```console
helm install paperless-ngx oci://ghcr.io/pr0ton11/charts/paperless-ngx
```

## Uninstalling the Chart

To uninstall the `paperless-ngx` deployment

```console
helm uninstall paperless-ngx
```

The command removes all the Kubernetes components associated with the chart **including persistent volumes** and deletes the release.

## Configuration

Read through the [values.yaml](./values.yaml) file. It has several commented out suggested values.
Other values may be used from the [values.yaml](https://github.com/bjw-s-labs/helm-charts/tree/main/charts/library/common/values.yaml) from the [bjw-s common library](https://github.com/bjw-s-labs/helm-charts/tree/main/charts/library/common).

Specify each parameter using the `--set key=value[,key=value]` argument to `helm install`.

```console
helm install paperless-ngx \
  --set env.TZ="America/New York" \
    oci://ghcr.io/pr0ton11/charts/paperless-ngx
```

Alternatively, a YAML file that specifies the values for the above parameters can be provided while installing the chart.

```console
helm install paperless-ngx oci://ghcr.io/pr0ton11/charts/paperless-ngx -f values.yaml
```

## Custom configuration

### Paperless-ngx v3 upgrade

Chart `0.27.x` updates Paperless-ngx to the Paperless-ngx v3 beta.
Read the upstream [Paperless-ngx v3 migration guide](https://github.com/paperless-ngx/paperless-ngx/blob/dev/docs/migration-v3.md) and this chart's [0.27.0 migration notes](./MIGRATION_0.27.0.md) before upgrading.
Paperless-ngx v3 requires `PAPERLESS_SECRET_KEY`; generate one with `python3 -c "import secrets; print(secrets.token_urlsafe(64))"` and set it under `env.PAPERLESS_SECRET_KEY`.

### Exposing Paperless-ngx

The chart supports Kubernetes Ingress through the bjw-s common chart and Gateway API through a chart-managed `HTTPRoute`.
Both can be enabled at the same time if you need to publish the app through more than one entry point.

#### Ingress

```yaml
ingress:
  main:
    enabled: true
    hosts:
      - host: paperless.example.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: paperless-example-tls
        hosts:
          - paperless.example.com
```

#### Gateway API

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
      - host: paperless.example.com
        paths:
          - path: /
            pathType: PathPrefix
```

You can also use `gateway.main.hostnames` when all hostnames should use the default `/` prefix route.
When both ingress and Gateway API are enabled, the chart renders both resources and derives `PAPERLESS_URL` from the Gateway API host.

### Database Installation

Paperless-ngx supports PostgreSQL and MariaDB.

#### External PostgreSQL

For an existing PostgreSQL server, keep `postgresql.enabled=false` and set the Paperless database settings under `env`.
The chart will pass those values through unchanged.

```yaml
postgresql:
  enabled: false

env:
  PAPERLESS_DBENGINE: postgresql
  PAPERLESS_DBHOST: postgres.example.invalid
  PAPERLESS_DBNAME: paperless
  PAPERLESS_DBUSER: paperless
  PAPERLESS_DBPASS: change-me
  PAPERLESS_DB_OPTIONS: sslmode=require
```

For external MariaDB, set `PAPERLESS_DBENGINE: mariadb`.
For compatibility with common upgrades from `0.26.x`, the chart injects `PAPERLESS_DBENGINE: postgresql` when `PAPERLESS_DBHOST` is set, no bundled database is enabled, and `PAPERLESS_DBENGINE` is not set.

#### Bundled PostgreSQL

This chart can install PostgreSQL with the optional `postgresql` subchart and configure Paperless-ngx automatically.

```yaml
postgresql:
  enabled: true
  auth:
    database: paperless
    postgresPassword: change-me
```

MariaDB is also available through the optional `mariadb` subchart.
See each database section in [`values.yaml`](./values.yaml) for more configuration.

### Redis-compatible cache

This chart manages a single Redis-compatible cache instance by default using Valkey.
Existing values under `redis.*` are still accepted for compatibility with the original chart.

## Values

**Important**: When deploying an application Helm chart you can add more values from the bjw-s common library chart [here](https://github.com/bjw-s-labs/helm-charts/tree/main/charts/library/common)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| env | object | See [values.yaml](./values.yaml) | Environment variables [[ref]](https://docs.paperless-ngx.com/configuration/) |
| env.TZ | string | `"UTC"` | Set the container timezone |
| image.pullPolicy | string | `"Always"` | Image pull policy |
| image.repository | string | `"ghcr.io/paperless-ngx/paperless-ngx"` | Image repository |
| gateway.main | object | See [values.yaml](./values.yaml) | Enable and configure Gateway API HTTPRoute settings for the chart under this key. |
| image.tag | string | `"beta"` | Image tag |
| ingress.main | object | See [values.yaml](./values.yaml) | Enable and configure ingress settings for the chart under this key. |
| mariadb | object | See [values.yaml](./values.yaml) | Enable and configure mariadb database subchart under this key.    If enabled, the app's db envs will be set for you.    [[ref]](https://github.com/bitnami/charts/tree/main/bitnami/mariadb) |
| persistence.consume | object | See [values.yaml](./values.yaml) | Configure consume volume settings for the chart under this key. |
| persistence.data | object | See [values.yaml](./values.yaml) | Configure data volume settings for the chart under this key. |
| persistence.export | object | See [values.yaml](./values.yaml) | Configure export volume settings for the chart under this key. |
| persistence.media | object | See [values.yaml](./values.yaml) | Configure media volume settings for the chart under this key. |
| postgresql | object | See [values.yaml](./values.yaml) | Enable and configure the optional PostgreSQL subchart under this key.    Leave this disabled when using an external PostgreSQL server and configure Paperless database settings directly under `env`, for example:    PAPERLESS_DBENGINE, PAPERLESS_DBHOST, PAPERLESS_DBNAME, PAPERLESS_DBUSER,    PAPERLESS_DBPASS, and PAPERLESS_DB_OPTIONS.    If enabled, the chart will inject the app's db envs for the bundled    PostgreSQL instance.    [[ref]](https://github.com/bitnami/charts/tree/main/bitnami/postgresql) |
| redis | object | See [values.yaml](./values.yaml) | Enable and configure chart-managed Redis under this key.    If enabled, the app's Redis env will be set for you. |
| service.main | object | See [values.yaml](./values.yaml) | Configures service settings for the chart. |

---
Autogenerated from chart metadata using [helm-docs](https://github.com/norwoodj/helm-docs)
