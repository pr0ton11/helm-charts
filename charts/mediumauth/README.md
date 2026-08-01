# Mediumauth

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat)
![AppVersion: 0.1.0](https://img.shields.io/badge/AppVersion-0.1.0-informational?style=flat)

A small authentication server with dynamic local-user management

**Homepage:** <https://github.com/pr0ton11/mediumauth>

The upstream project does not maintain this chart.
Report chart errors in this repository.

## Source Code

* <https://github.com/pr0ton11/mediumauth>

## Requirements

Kubernetes: `>=1.31.0-0`

## Dependencies

| Repository | Name | Version |
|------------|------|---------|
| <https://bjw-s-labs.github.io/helm-charts> | common | 5.0.1 |

## Install the chart

Create a Secret that contains the bootstrap administrator:

```console
kubectl create secret generic mediumauth-env \
  --from-literal='TINYAUTH_AUTH_USERS=admin:$2a$10$REPLACE_WITH_A_BCRYPT_HASH'
```

Create a values file:

```yaml
envFrom:
  - secret: mediumauth-env
ingress:
  main:
    enabled: true
    hosts:
      - host: auth.example.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: mediumauth-example-tls
        hosts:
          - auth.example.com
```

Install the chart:

```console
helm install mediumauth oci://ghcr.io/pr0ton11/charts/mediumauth -f values.yaml
```

## Uninstall the chart

```console
helm uninstall mediumauth
```

This command removes the Kubernetes objects that the chart created.
The retained persistent volume remains in the cluster.

## Custom configuration

### Bootstrap administrator

Mediumauth requires one bootstrap administrator at the first startup.
The value uses the `username:bcrypt_hash` format.

Mediumauth imports a new bootstrap user as an administrator.
It does not replace an existing database record.

After the first administrator signs in, remove the bootstrap credential if it is not necessary.
This configuration change does not delete the database user.

### Persistence

The `/data` volume contains the SQLite database, OIDC keys, and resources.
The chart enables and retains this volume by default.

The default SQLite database and `ReadWriteOnce` volume support one replica.
The chart uses a `Recreate` deployment strategy.

### Public URL

The chart derives `TINYAUTH_APPURL` from the first Ingress or Gateway API host.
An explicit `env.TINYAUTH_APPURL` value has priority.

### Ingress discovery

Mediumauth can read ACL annotations from all Kubernetes Ingress resources.
Set `ingressDiscovery.enabled=true` only if you use these annotations.

This value creates a `ClusterRole` and a `ClusterRoleBinding`.
The role permits `get`, `list`, and `watch` operations on Ingress resources.

### External PostgreSQL

Set `TINYAUTH_DATABASE_DRIVER=postgres` to use an external PostgreSQL database.
Store the connection URL in a Kubernetes Secret through `env` or `envFrom`.

See the [Mediumauth environment example](https://github.com/pr0ton11/mediumauth/blob/v0.1.0/.env.example) for all configuration variables.

## Values

This chart inherits more values from the [bjw-s common library chart](https://github.com/bjw-s-labs/helm-charts/tree/main/charts/library/common).

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| env | object | See [values.yaml](./values.yaml) | Mediumauth environment variables. |
| envFrom | list | `[]` | Secrets and ConfigMaps that provide environment variables. |
| gateway.main | object | See [values.yaml](./values.yaml) | Gateway API HTTPRoute configuration. |
| image.pullPolicy | string | `"IfNotPresent"` | Image pull policy. |
| image.repository | string | `"ghcr.io/pr0ton11/mediumauth"` | Image repository. |
| image.tag | string | `"0.1.0"` | Image tag. |
| ingress.main | object | See [values.yaml](./values.yaml) | Kubernetes Ingress configuration. |
| ingressDiscovery.enabled | bool | `false` | Cluster-wide Ingress annotation discovery. |
| persistence | object | See [values.yaml](./values.yaml) | Persistent `/data` storage. |
| replicaCount | int | `1` | Number of Mediumauth replicas. |
| resources | object | See [values.yaml](./values.yaml) | Container resource requests and limits. |
| service.main | object | See [values.yaml](./values.yaml) | Mediumauth service configuration. |
