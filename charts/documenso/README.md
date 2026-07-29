# Documenso

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat)
![AppVersion: 2.16.0](https://img.shields.io/badge/AppVersion-2.16.0-informational?style=flat)

The open source DocuSign alternative

**Homepage:** <https://documenso.com>

**This chart is not maintained by the upstream project and any issues with the chart should be raised
in this repository.**

## Source Code

* <https://github.com/documenso/documenso>

## Requirements

Kubernetes: `>=1.31.0-0`

## Dependencies

| Repository | Name | Version |
|------------|------|---------|
| <https://bjw-s-labs.github.io/helm-charts> | common | 5.0.1 |
| <https://charts.bitnami.com/bitnami> | postgresql | 18.8.2 |

## Installing the Chart

To install the chart with the release name `documenso`:

```console
helm install documenso oci://ghcr.io/pr0ton11/charts/documenso -f values.yaml
```

## Uninstalling the Chart

```console
helm uninstall documenso
```

The command removes the Kubernetes components created by the chart. Retained
persistent volumes remain subject to their configured resource policy.

## Custom configuration

### Required configuration

Documenso requires authentication and encryption keys, a public URL, PostgreSQL, and an email sender identity.
The chart derives the public URL from Ingress or Gateway API and injects database URLs when bundled PostgreSQL is enabled.

Keep secrets in Kubernetes Secrets by using `secretKeyRef` values:

```yaml
env:
  NEXTAUTH_SECRET:
    secretKeyRef:
      name: documenso-env
      key: NEXTAUTH_SECRET
  NEXT_PRIVATE_ENCRYPTION_KEY:
    secretKeyRef:
      name: documenso-env
      key: NEXT_PRIVATE_ENCRYPTION_KEY
  NEXT_PRIVATE_ENCRYPTION_SECONDARY_KEY:
    secretKeyRef:
      name: documenso-env
      key: NEXT_PRIVATE_ENCRYPTION_SECONDARY_KEY
  NEXT_PRIVATE_SMTP_FROM_ADDRESS: noreply@example.com
  NEXT_PRIVATE_SMTP_FROM_NAME: Documenso
```

You can alternatively load a complete Secret or ConfigMap:

```yaml
envFrom:
  - secret: documenso-env
```

Required-variable validation is skipped when `envFrom` is configured because Helm cannot inspect referenced objects.
Explicit `env` values take precedence over variables loaded through `envFrom`.

See the [Documenso environment reference](https://docs.documenso.com/docs/self-hosting/configuration/environment) and the commented `env` entries in [`values.yaml`](./values.yaml) for the complete supported configuration surface.

### Database

Documenso requires PostgreSQL 14 or newer.
For production, use an external managed PostgreSQL service and configure:

```yaml
postgresql:
  enabled: false

env:
  NEXT_PRIVATE_DATABASE_URL: postgresql://documenso:password@postgres.example.com:5432/documenso
  # Set a direct connection when the primary URL uses a connection pooler.
  NEXT_PRIVATE_DIRECT_DATABASE_URL: postgresql://documenso:password@postgres-direct.example.com:5432/documenso
```

For development or smaller installations, enable the bundled PostgreSQL chart:

```yaml
postgresql:
  enabled: true
  auth:
    database: documenso
    username: documenso
    password: replace-me
  primary:
    persistence:
      enabled: true
      size: 10Gi
```

The chart injects `NEXT_PRIVATE_DATABASE_URL` and `NEXT_PRIVATE_DIRECT_DATABASE_URL` when bundled PostgreSQL uses chart-managed credentials.
Use a URL-safe `postgresql.auth.password`. When `postgresql.auth.existingSecret` is set, provide the complete database URL through `env` or `envFrom` because Helm cannot URL-encode the referenced password.

### Signing certificate

For local document signing, create a Secret containing the PKCS#12 certificate:

```console
kubectl create secret generic documenso-signing-cert \
  --from-file=cert.p12=/path/to/cert.p12
```

Mount it and provide its passphrase:

```yaml
signingCertificate:
  existingSecret: documenso-signing-cert

env:
  NEXT_PRIVATE_SIGNING_PASSPHRASE:
    secretKeyRef:
      name: documenso-env
      key: NEXT_PRIVATE_SIGNING_PASSPHRASE
```

Documenso starts without a certificate, but document signing remains unavailable until a supported signing transport is configured.

### Exposing Documenso

The chart supports Kubernetes Ingress through the bjw-s common chart and Gateway API through a chart-managed `HTTPRoute`.
Both derive `NEXT_PUBLIC_WEBAPP_URL` from the configured host.

```yaml
ingress:
  main:
    enabled: true
    hosts:
      - host: sign.example.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: sign-example-tls
        hosts:
          - sign.example.com
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
      - host: sign.example.com
        paths:
          - path: /
            pathType: PathPrefix
```

### Background jobs

Documenso uses PostgreSQL-backed local jobs by default.
To use BullMQ, enable the chart-managed Redis instance:

```yaml
redis:
  enabled: true
  master:
    persistence:
      enabled: true
      size: 1Gi
```

The chart injects `NEXT_PRIVATE_JOBS_PROVIDER=bullmq` and `NEXT_PRIVATE_REDIS_URL`.
Use a URL-safe `redis.auth.password`. When `redis.auth.existingSecret` is set, provide the complete Redis URL through `env` or `envFrom`.
For an external Redis-compatible service, leave `redis.enabled=false` and set those variables under `env`.

## Values

**Important**: This chart inherits additional values from the [bjw-s common library chart](https://github.com/bjw-s-labs/helm-charts/tree/main/charts/library/common).

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| env | object | See [values.yaml](./values.yaml) | Documenso environment variables. |
| envFrom | list | `[]` | Secrets and ConfigMaps loaded as environment variables. |
| gateway.main | object | See [values.yaml](./values.yaml) | Enable and configure Gateway API HTTPRoute. |
| image.pullPolicy | string | `"IfNotPresent"` | Image pull policy |
| image.repository | string | `"ghcr.io/documenso/documenso"` | Image repository |
| image.tag | string | `"v2.16.0"` | Image tag |
| ingress.main | object | See [values.yaml](./values.yaml) | Enable and configure Kubernetes Ingress. |
| postgresql | object | See [values.yaml](./values.yaml) | Optional bundled PostgreSQL. |
| redis | object | See [values.yaml](./values.yaml) | Optional chart-managed Redis for BullMQ. |
| replicaCount | int | `1` | Number of Documenso replicas. |
| resources | object | See [values.yaml](./values.yaml) | Documenso container resources. |
| service.main | object | See [values.yaml](./values.yaml) | Configures the Documenso service. |
| signingCertificate | object | See [values.yaml](./values.yaml) | Mount an existing Secret containing the local signing certificate. |
