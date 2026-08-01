# Mediumauth

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat)
![AppVersion: 0.2.0](https://img.shields.io/badge/AppVersion-0.2.0-informational?style=flat)

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

Generate the required configuration encryption key:

```console
openssl rand -base64 32
```

Store the output in a Kubernetes Secret:

```console
kubectl create secret generic mediumauth-config \
  --from-literal='TINYAUTH_CONFIG_ENCRYPTION_KEY=REPLACE_WITH_OPENSSL_OUTPUT'
```

Create a values file:

```yaml
configEncryptionKey:
  existingSecret: mediumauth-config
  existingSecretKey: TINYAUTH_CONFIG_ENCRYPTION_KEY
env:
  TINYAUTH_AUTH_USERS:
    secretKeyRef:
      name: mediumauth-env
      key: TINYAUTH_AUTH_USERS
ingress:
  main:
    enabled: true
    hosts:
      - host: auth.example.com
        paths:
          - path: /
            pathType: Prefix
```

Install the chart:

```console
helm install mediumauth oci://ghcr.io/pr0ton11/charts/mediumauth -f values.yaml
```

## Configuration encryption key

Mediumauth requires `TINYAUTH_CONFIG_ENCRYPTION_KEY` at each startup.
The value must use standard base64 encoding of exactly 32 bytes.
All replicas must use the same value.

CAUTION: Keep this key unchanged during normal upgrades.
A new key cannot decrypt the stored configuration document.

The recommended mode uses an existing Secret, as shown in the installation procedure.
The chart can also create the Secret from a protected values file:

```yaml
configEncryptionKey:
  value: MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=
```

The inline value is stored in Helm release metadata.
When possible, use an existing Secret.

This value is application-level base64.
The generated Secret uses `stringData`, which accepts the application-level value directly.
When Kubernetes stores the value in `Secret.data`, it applies another base64 layer.
If you write `Secret.data` directly, base64-encode the application-level value again.

The chart never generates or rotates this key.
It does not add `TINYAUTH_CONFIG_NEW_ENCRYPTION_KEY` to the Deployment.

## Bootstrap administrator

Mediumauth requires one bootstrap administrator at the first startup.
The value uses the `username:bcrypt_hash` format.

Mediumauth imports each new bootstrap user as an administrator.
It does not replace an existing database record.

If the bootstrap credential is not necessary, remove it after the first administrator signs in.
This change does not delete the database user.

## Persistence and replicas

SQLite stores its database at `/data/tinyauth.db` by default.
Keep `persistence.data.enabled=true` for SQLite.
SQLite supports one replica only.

PostgreSQL stores users, sessions, managed configuration, and the OIDC signing key in the shared database.
A PostgreSQL deployment can disable the PersistentVolume:

```yaml
replicaCount: 2
persistence:
  data:
    enabled: false
env:
  TINYAUTH_DATABASE_DRIVER: postgres
  TINYAUTH_DATABASE_PATH:
    secretKeyRef:
      name: mediumauth-postgresql
      key: url
```

More than one replica requires a shared PostgreSQL database.
All replicas must use the same configuration encryption key.

The legacy OIDC private-key file is optional and import-only.
When the database has no OIDC signing key, Mediumauth imports the legacy private key.
The deprecated public-key path is not a persistence requirement.

## Database-managed configuration

Mediumauth v0.2.0 stores these values in one encrypted database document:

- applications
- global OAuth values and providers
- OIDC clients
- authentication IP rules and the ACL policy
- session expiry, session maximum lifetime, login timeout, and login limits
- UI appearance

The first v0.2.0 startup imports these values from the existing environment or YAML configuration.
When the database has no managed configuration, Mediumauth imports the legacy values.

Keep the legacy values during the first upgrade.
After the import, edit the managed configuration at `/admin`.
Later environment changes do not replace the database document.
Removing legacy values does not delete database-managed configuration.

Deployment-managed values remain active in the chart:

- application URL
- database and server listener
- cookie, subdomain, and trusted-proxy values
- file paths and resources
- label provider
- logging and analytics
- LDAP and Tailscale
- experimental values
- bootstrap users and user attributes
- legacy OIDC key paths

## Upgrade to v0.2.0

Read [UPGRADING_0.2.0.md](./UPGRADING_0.2.0.md) before the first v0.2.0 upgrade.
The procedure covers the database backup, encryption key, one-time import, and post-upgrade administration.

## Rotate the configuration key

Do not rotate the key through Helm.
Use the offline application command:

1. Stop all Mediumauth replicas.
2. Generate and store a new base64-encoded 32-byte key.
3. Run the rotation command against the configured database:

```console
TINYAUTH_CONFIG_ENCRYPTION_KEY="$OLD_KEY" \
TINYAUTH_CONFIG_NEW_ENCRYPTION_KEY="$NEW_KEY" \
tinyauth configuration rotate-key
```

4. Update the Kubernetes Secret with the new key.
5. Restart Mediumauth.

## Public URL and routes

The chart derives `TINYAUTH_APPURL` from the first Ingress or Gateway API host.
An explicit `env.TINYAUTH_APPURL` value has priority.

Mediumauth can read ACL annotations from all Kubernetes Ingress resources.
If you use these annotations, set `ingressDiscovery.enabled=true`.

This value creates a `ClusterRole` and a `ClusterRoleBinding`.
The role permits `get`, `list`, and `watch` operations on Ingress resources.

See the [Mediumauth environment example](https://github.com/pr0ton11/mediumauth/blob/d9e6240/.env.example) for deployment-managed variables.

## Uninstall the chart

```console
helm uninstall mediumauth
```

This command removes the Kubernetes objects that the chart created.
The retained PersistentVolume remains in the cluster.

## Values

This chart inherits more values from the [bjw-s common library chart](https://github.com/bjw-s-labs/helm-charts/tree/main/charts/library/common).

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| configEncryptionKey.existingSecret | string | `""` | Existing Secret that contains the configuration encryption key. |
| configEncryptionKey.existingSecretKey | string | `"TINYAUTH_CONFIG_ENCRYPTION_KEY"` | Key in the existing Secret. |
| configEncryptionKey.value | string | `""` | Application-level base64 value for a chart-managed Secret. |
| env | object | See [values.yaml](./values.yaml) | Deployment-managed and legacy import-only environment values. |
| envFrom | list | `[]` | Secrets and ConfigMaps that provide environment variables. |
| gateway.main | object | See [values.yaml](./values.yaml) | Gateway API HTTPRoute configuration. |
| image.pullPolicy | string | `"IfNotPresent"` | Image pull policy. |
| image.repository | string | `"ghcr.io/pr0ton11/mediumauth"` | Image repository. |
| image.tag | string | `"0.2.0"` | Image tag. |
| ingress.main | object | See [values.yaml](./values.yaml) | Kubernetes Ingress configuration. |
| ingressDiscovery.enabled | bool | `false` | Cluster-wide Ingress annotation discovery. |
| persistence | object | See [values.yaml](./values.yaml) | Persistent `/data` storage for SQLite and optional resources. |
| replicaCount | int | `1` | Number of Mediumauth replicas. |
| resources | object | See [values.yaml](./values.yaml) | Container resource requests and limits. |
| service.main | object | See [values.yaml](./values.yaml) | Mediumauth service configuration. |
