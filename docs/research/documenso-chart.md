# Documenso Helm chart research

Research date: 2026-07-29

This note is an implementation input for a Documenso chart in this repository. It uses only Documenso's official documentation and source, Documenso's official image registries, and the official upstream chart sources/indexes for proposed dependencies.

## Executive decisions

- Use `ghcr.io/documenso/documenso:v2.16.0` (or the equivalent Docker Hub image) as the application image. `v2.16.0` is the newest stable tag published by Documenso to both official registries for Linux `amd64` and `arm64`, and the upstream repository has a corresponding [`v2.16.0` commit](https://github.com/documenso/documenso/commit/3cf2963cd03d8b24770b7490bdb20e596baa5d65). The official [GHCR package currently marks it Latest](https://github.com/documenso/documenso/pkgs/container/documenso).
- There is a release-metadata lag: the newest GitHub Release object is still [`v2.15.0`](https://github.com/documenso/documenso/releases/tag/v2.15.0), published 2026-07-21. This does not make the already-published `v2.16.0` image a beta or prerelease; upstream's [publish workflow only applies the stable version tag and `latest` to non-prerelease builds](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/.github/workflows/publish.yml#L102-L182).
- PostgreSQL is required. Documenso supports PostgreSQL `14+`; its production Compose and Kubernetes examples currently use PostgreSQL 15 ([database requirement](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/apps/docs/content/docs/self-hosting/configuration/database.mdx#L8-L13), [production Compose](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/docker/production/compose.yml#L3-L22)).
- Redis is optional. The default `local` jobs provider stores jobs in PostgreSQL. Redis `6.2+` is needed only for the optional `bullmq` provider ([background-job requirements](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/apps/docs/content/docs/self-hosting/configuration/background-jobs.mdx#L68-L113)).
- The application does not need a general-purpose data PVC. Documents are stored in PostgreSQL by default or in S3-compatible storage when configured. The local signing certificate is a read-only secret mount, not application data storage ([official storage guidance](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/apps/docs/content/docs/self-hosting/deployment/kubernetes.mdx#L475-L492), [official certificate mount](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/docker/production/compose.yml#L73-L82)).
- Preserve the image's command. The upstream startup script checks the signing certificate, applies Prisma migrations, and then starts the server. Overriding it would skip migrations ([startup script](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/docker/start.sh#L9-L31)).

## Container and Kubernetes contract

| Concern | Upstream contract | Chart implication | Source |
| --- | --- | --- | --- |
| Repository/tag | `ghcr.io/documenso/documenso:v2.16.0`; Docker Hub also publishes `documenso/documenso:v2.16.0` | Pin `v2.16.0`, not `latest`; retain a configurable repository and tag | [GHCR package](https://github.com/documenso/documenso/pkgs/container/documenso), [publish workflow](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/.github/workflows/publish.yml#L102-L182) |
| Architectures | Linux `amd64` and `arm64` manifests are published | No node selector is required for those two architectures | [GHCR package](https://github.com/documenso/documenso/pkgs/container/documenso) |
| Runtime user | UID/GID `1001`; workdir `/app/apps/remix` | Default `runAsUser`, `runAsGroup`, and `fsGroup` to `1001` and run non-root | [Dockerfile](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/docker/Dockerfile#L101-L135), [Kubernetes example](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/apps/docs/content/docs/self-hosting/deployment/kubernetes.mdx#L168-L184) |
| Command | Image `CMD` is `sh start.sh`; startup runs `prisma migrate deploy` before `node build/server/main.js` | Do not set a chart command/args by default. Every starting replica can attempt idempotent Prisma deployment, so rollout behavior must tolerate this | [Dockerfile](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/docker/Dockerfile#L127-L135), [start script](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/docker/start.sh#L27-L31) |
| Bind address/port | `HOSTNAME=0.0.0.0`; `PORT` defaults to `3000` | Service target port and named container port should default to `3000` | [start script](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/docker/start.sh#L27-L31), [environment reference](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/apps/docs/content/docs/self-hosting/configuration/environment.mdx#L22-L27) |
| Service | Official sample uses ClusterIP port `80` targeting named port `http` on `3000` | A chart following the Paperless pattern may expose service port `3000`; ingress/routes should target its named `http` port | [Kubernetes example](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/apps/docs/content/docs/self-hosting/deployment/kubernetes.mdx#L236-L260) |
| Probes | Startup, readiness, and liveness probes all issue HTTP GET `/api/health` | Use upstream timings as safe initial defaults: liveness `30s/10s/5s/3`, readiness `10s/5s/3s/3`, startup `10s/5s/3s/30` (initial delay/period/timeout/failures) | [Kubernetes example](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/apps/docs/content/docs/self-hosting/deployment/kubernetes.mdx#L188-L227) |
| Probe semantics | The endpoint runs `SELECT 1`. A missing signing certificate is a warning and still returns HTTP 200; database or certificate-check exceptions return HTTP 500 | Readiness/liveness include database health. Lack of a signing certificate does not block pod readiness | [health handler](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/apps/remix/app/routes/api%2B/health.ts#L6-L48) |
| Resources | Official sample requests `250m` CPU / `512Mi`, limits `1000m` / `1Gi` | Good documented defaults or README recommendations; allow override | [Kubernetes example](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/apps/docs/content/docs/self-hosting/deployment/kubernetes.mdx#L181-L187) |
| Replicas/rollout | Official sample uses 2 replicas, RollingUpdate, `maxSurge: 1`, `maxUnavailable: 0` | Expose replicas and strategy. A conservative chart default of one replica avoids simultaneous first-install migrations; users can scale after validating shared DB/S3 configuration | [Kubernetes example](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/apps/docs/content/docs/self-hosting/deployment/kubernetes.mdx#L138-L168) |
| HPA/PDB | Official examples use HPA `2..10`, CPU 70%, memory 80%, and PDB `minAvailable: 1` | Common-library autoscaling and PDB values can expose these without enabling them by default | [Kubernetes example](https://docs.documenso.com/docs/self-hosting/deployment/kubernetes#scaling) |
| Ingress | Official nginx example sets body size `50m` and read/send timeout `300`; TLS is expected | Carry these as example/default annotations while keeping ingress class and TLS user-controlled; support Gateway API consistently with Paperless | [Kubernetes example](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/apps/docs/content/docs/self-hosting/deployment/kubernetes.mdx#L261-L329) |
| Kubernetes baseline | Documenso documentation says Kubernetes `1.24+` | If using `bjw-s/common` `5.0.1`, the effective minimum is instead Kubernetes `1.31+`; the parent chart must not claim a lower `kubeVersion` | [Documenso prerequisite](https://docs.documenso.com/docs/self-hosting/deployment/kubernetes#prerequisites), [common Chart.yaml](https://github.com/bjw-s-labs/helm-charts/blob/main/charts/library/common/Chart.yaml) |

## Persistence and signing

Documenso stores documents in PostgreSQL by default. S3-compatible storage is the supported alternative for higher volume; this is selected with `NEXT_PUBLIC_UPLOAD_TRANSPORT=s3` and its conditional S3 variables. Consequently, a Documenso application PVC should not be enabled by default ([storage environment reference](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/apps/docs/content/docs/self-hosting/configuration/environment.mdx#L164-L194)).

The local signing transport looks for a `.p12` certificate, with the upstream container default at `/opt/documenso/cert.p12`. The application still starts without the certificate, but signing remains unavailable. The chart should support:

1. a referenced Kubernetes Secret mounted read-only at `/opt/documenso/cert.p12` with `subPath`;
2. `NEXT_PRIVATE_SIGNING_LOCAL_FILE_CONTENTS` supplied from a Secret as a mount-free alternative; and
3. `NEXT_PRIVATE_SIGNING_PASSPHRASE` supplied only from a Secret.

The certificate path/contents/passphrase contract is documented in the [official environment reference](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/apps/docs/content/docs/self-hosting/configuration/environment.mdx#L198-L226), while the image's non-fatal missing-certificate behavior is explicit in the [startup script](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/docker/start.sh#L9-L25).

`NEXT_PRIVATE_LOGGER_FILE_PATH` is the only documented configuration that introduces an optional writable application path; setting it disables stdout. The chart should not create log persistence automatically, but its generic persistence/volume values must permit one when a user deliberately chooses file logging ([logging reference](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/apps/docs/content/docs/self-hosting/configuration/environment.mdx#L434-L440)).

## Dependencies

### Common library

The repository's Paperless chart uses `bjw-s/common`. The latest official chart index on the research date exposes `common` `5.0.1`, which is also the version already used here. Its own `Chart.yaml` requires Kubernetes `>=1.31.0-0`; use that effective minimum if the Documenso chart takes this dependency ([official chart source](https://github.com/bjw-s-labs/helm-charts/blob/main/charts/library/common/Chart.yaml)).

### PostgreSQL

PostgreSQL is mandatory, but the subchart should remain conditional so users can supply an external managed database, which upstream recommends for production. Upstream requires PostgreSQL 14+, and both URLs use the form `postgres://user:password@host:port/database`. `NEXT_PRIVATE_DIRECT_DATABASE_URL` is required when the primary URL uses a pooler and otherwise defaults to the primary URL ([database variables](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/apps/docs/content/docs/self-hosting/configuration/environment.mdx#L31-L46), [managed-database recommendation](https://docs.documenso.com/docs/self-hosting/deployment/kubernetes#database-options)).

The official Bitnami repository index exposed `postgresql` chart `18.8.2` (`appVersion: 18.4.0`) on 2026-07-29. Proposed dependency:

```yaml
- name: postgresql
  version: 18.8.2
  repository: https://charts.bitnami.com/bitnami
  condition: postgresql.enabled
```

The relevant supported integration values are `auth.username`, `auth.password`, `auth.database`, `auth.existingSecret`, and `primary.persistence`; PostgreSQL data is persisted by that chart rather than by the Documenso pod ([official PostgreSQL chart documentation](https://github.com/bitnami/charts/tree/main/bitnami/postgresql), [official chart index](https://charts.bitnami.com/bitnami/index.yaml)).

Implementation caveat: Documenso accepts a complete URL, not separate database host/user/password variables. Building a URL from subchart credentials requires URL-encoding reserved characters. With `postgresql.auth.existingSecret`, Helm cannot read the Secret value, so the user must also provide a prebuilt `NEXT_PRIVATE_DATABASE_URL` (and, when needed, direct URL) through a Documenso Secret. Do not copy a plaintext database password into a ConfigMap.

### Redis / BullMQ

Redis is not required in the default installation. `NEXT_PRIVATE_JOBS_PROVIDER=local` uses PostgreSQL and needs no Redis. For `bullmq`, upstream requires Redis 6.2+, `NEXT_PRIVATE_REDIS_URL`, and optionally accepts prefix `documenso` and concurrency `10`. Upstream's example uses `redis:8-alpine` and persists `/data` ([background-job reference](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/apps/docs/content/docs/self-hosting/configuration/background-jobs.mdx#L68-L113), [development Compose](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/docker/development/compose.yml#L29-L35)).

The official Bitnami repository index exposed `redis` chart `27.0.18` (`appVersion: 8.8.1`) on 2026-07-29, but the packaged chart defaults its runtime image to the mutable `bitnami/redis:latest` tag. That makes it unsuitable for this repository's pinned-release contract.

The implemented optional dependency instead follows the existing Paperless pattern: a small chart-managed standalone Redis deployment pinned to the official [`redis:8.8.1-alpine`](https://hub.docker.com/_/redis) image, with optional authentication and persistence. The verified image index supports Linux `amd64`, `arm64`, `arm/v6`, `arm/v7`, `386`, `ppc64le`, `riscv64`, and `s390x`. A Valkey substitution may be protocol-compatible, but Documenso's owned documentation explicitly specifies Redis and sets a minimum Redis version, so the chart does not substitute Valkey.

### Other optional external services

- S3-compatible object storage is optional and replaces database document blobs; it is not a bundled chart dependency ([storage reference](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/apps/docs/content/docs/self-hosting/configuration/environment.mdx#L164-L194)).
- Gotenberg is optional. It enables DOCX-to-PDF conversion; without its URL, Documenso accepts PDFs only. It should be represented by environment values, not enabled as a mandatory subchart ([document-conversion reference](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/apps/docs/content/docs/self-hosting/configuration/environment.mdx#L366-L379)).
- SMTP credentials or one of the supported API transports are operationally required because the sender name/address are mandatory. Upstream's Kubernetes prerequisites explicitly call for SMTP credentials ([environment reference](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/apps/docs/content/docs/self-hosting/configuration/environment.mdx#L106-L160), [Kubernetes prerequisite](https://docs.documenso.com/docs/self-hosting/deployment/kubernetes#prerequisites)).

## Environment value contract

The user's requested [official environment-variable page](https://docs.documenso.com/docs/self-hosting/configuration/environment) is captured below against the pinned `v2.16.0` source.

Kubernetes environment values are strings even when their semantic type is boolean or integer. The chart should therefore quote rendered values and support `valueFrom.secretKeyRef`, plus `envFrom`/existing Secret injection. The **Secret** classification below is a chart-design security classification inferred from the data carried by the variable; the required/default/type facts come from the cited upstream source.

Legend:

- `secret`: render only from a Kubernetes Secret or user-provided Secret reference in examples/default flows.
- `config`: safe for a ConfigMap/plain environment value in normal usage.
- `conditional`: required only when the corresponding transport/provider is selected.

### Core, server, database, and authentication

Source: [required/server/database variables](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/apps/docs/content/docs/self-hosting/configuration/environment.mdx#L6-L46), [authentication variables](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/apps/docs/content/docs/self-hosting/configuration/environment.mdx#L50-L102).

| Variable | Required/default | Semantic type | Secret | Notes |
| --- | --- | --- | --- | --- |
| `NEXTAUTH_SECRET` | required; min 32 chars | string | yes | Generate with `openssl rand -base64 32` |
| `NEXT_PRIVATE_ENCRYPTION_KEY` | required; min 32 chars | string | yes | Primary encryption key |
| `NEXT_PRIVATE_ENCRYPTION_SECONDARY_KEY` | required; min 32 chars | string | yes | Secondary/rotation key |
| `NEXT_PUBLIC_WEBAPP_URL` | required | URL | no | Public base URL |
| `NEXT_PRIVATE_INTERNAL_WEBAPP_URL` | default: public URL | URL | no | Internal self-request URL |
| `PORT` | `3000` | integer string | no | Container listen port |
| `NEXT_PRIVATE_DATABASE_URL` | required | PostgreSQL URL | yes | May point to a pooler |
| `NEXT_PRIVATE_DIRECT_DATABASE_URL` | conditional when pooling; otherwise DB URL | PostgreSQL URL | yes | Used for migrations |
| `NEXT_PRIVATE_GOOGLE_CLIENT_ID` | optional | string | no | OAuth client ID |
| `NEXT_PRIVATE_GOOGLE_CLIENT_SECRET` | optional | string | yes | OAuth client secret |
| `NEXT_PRIVATE_MICROSOFT_CLIENT_ID` | optional | string | no | OAuth client ID |
| `NEXT_PRIVATE_MICROSOFT_CLIENT_SECRET` | optional | string | yes | OAuth client secret |
| `NEXT_PRIVATE_OIDC_WELL_KNOWN` | optional | URL | no | Provider discovery URL |
| `NEXT_PRIVATE_OIDC_CLIENT_ID` | optional | string | no | OIDC client ID |
| `NEXT_PRIVATE_OIDC_CLIENT_SECRET` | optional | string | yes | OIDC client secret |
| `NEXT_PRIVATE_OIDC_PROVIDER_LABEL` | `OIDC` | string | no | Button label |
| `NEXT_PRIVATE_OIDC_SKIP_VERIFY` | `false` | boolean string | no | Skips OIDC-account email verification |
| `NEXT_PRIVATE_OIDC_PROMPT` | `login` | string | no | Empty string omits prompt |
| `NEXT_PRIVATE_WEBHOOK_SSRF_BYPASS_HOSTS` | optional | comma-separated list | no | Security-sensitive allowlist; document prominently |

### Email

Source: [email variables](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/apps/docs/content/docs/self-hosting/configuration/environment.mdx#L106-L160).

| Variable | Required/default | Semantic type | Secret | Notes |
| --- | --- | --- | --- | --- |
| `NEXT_PRIVATE_SMTP_TRANSPORT` | `smtp-auth` | enum | no | `smtp-auth`, `smtp-api`, `resend`, `mailchannels` |
| `NEXT_PRIVATE_SMTP_HOST` | `127.0.0.1` for smtp-auth | hostname | no | Conditional on SMTP transports |
| `NEXT_PRIVATE_SMTP_PORT` | `587` | integer string | no | Conditional on SMTP transports |
| `NEXT_PRIVATE_SMTP_USERNAME` | optional | string | yes | Credential |
| `NEXT_PRIVATE_SMTP_PASSWORD` | optional | string | yes | Credential |
| `NEXT_PRIVATE_SMTP_SECURE` | `false` | boolean string | no | Force TLS |
| `NEXT_PRIVATE_SMTP_UNSAFE_IGNORE_TLS` | `false` | boolean string | no | Disables TLS; unsafe |
| `NEXT_PRIVATE_SMTP_SERVICE` | optional | string | no | Nodemailer service name |
| `NEXT_PRIVATE_SMTP_APIKEY_USER` | `apikey` | string | yes | Conditional on `smtp-api` |
| `NEXT_PRIVATE_SMTP_APIKEY` | conditional | string | yes | SMTP API credential |
| `NEXT_PRIVATE_RESEND_API_KEY` | conditional | string | yes | Resend transport credential |
| `NEXT_PRIVATE_MAILCHANNELS_API_KEY` | conditional | string | yes | MailChannels credential |
| `NEXT_PRIVATE_MAILCHANNELS_ENDPOINT` | `https://api.mailchannels.net/tx/v1/send` | URL | no | Optional proxy endpoint |
| `NEXT_PRIVATE_MAILCHANNELS_DKIM_DOMAIN` | optional | hostname | no | DKIM domain |
| `NEXT_PRIVATE_MAILCHANNELS_DKIM_SELECTOR` | optional | string | no | DKIM selector |
| `NEXT_PRIVATE_MAILCHANNELS_DKIM_PRIVATE_KEY` | conditional | PEM/string | yes | DKIM private key |
| `NEXT_PRIVATE_SMTP_FROM_ADDRESS` | required | email | no | Sender address |
| `NEXT_PRIVATE_SMTP_FROM_NAME` | required | string | no | Sender display name |

### Storage

Source: [storage variables](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/apps/docs/content/docs/self-hosting/configuration/environment.mdx#L164-L194).

| Variable | Required/default | Semantic type | Secret | Notes |
| --- | --- | --- | --- | --- |
| `NEXT_PUBLIC_UPLOAD_TRANSPORT` | `database` | enum | no | `database` or `s3` |
| `NEXT_PUBLIC_DOCUMENT_SIZE_UPLOAD_LIMIT` | `5` | integer string (MB) | no | Displayed maximum |
| `NEXT_PRIVATE_UPLOAD_BUCKET` | conditional for S3 | string | no | S3 bucket |
| `NEXT_PRIVATE_UPLOAD_REGION` | `us-east-1` | string | no | S3 region |
| `NEXT_PRIVATE_UPLOAD_ACCESS_KEY_ID` | conditional for S3 | string | yes | Credential |
| `NEXT_PRIVATE_UPLOAD_SECRET_ACCESS_KEY` | conditional for S3 | string | yes | Credential |
| `NEXT_PRIVATE_UPLOAD_ENDPOINT` | optional | URL | no | S3-compatible endpoint |
| `NEXT_PRIVATE_UPLOAD_FORCE_PATH_STYLE` | `false` | boolean string | no | S3 path-style addressing |
| `NEXT_PRIVATE_UPLOAD_DISTRIBUTION_DOMAIN` | optional | hostname | no | CloudFront domain |
| `NEXT_PRIVATE_UPLOAD_DISTRIBUTION_KEY_ID` | optional | string | no | CloudFront key-pair identifier |
| `NEXT_PRIVATE_UPLOAD_DISTRIBUTION_KEY_CONTENTS` | optional | PEM/string | yes | CloudFront private key |

### Signing

Source: [signing variables](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/apps/docs/content/docs/self-hosting/configuration/environment.mdx#L198-L261).

| Variable | Required/default | Semantic type | Secret | Notes |
| --- | --- | --- | --- | --- |
| `NEXT_PRIVATE_SIGNING_TRANSPORT` | `local` | enum | no | `local`, `gcloud-hsm`, `csc` |
| `NEXT_PRIVATE_SIGNING_LOCAL_FILE_PATH` | conditional for local | path | no | Default container convention: `/opt/documenso/cert.p12` |
| `NEXT_PRIVATE_SIGNING_LOCAL_FILE_CONTENTS` | alternative to path | base64 string | yes | PKCS#12 contents |
| `NEXT_PRIVATE_SIGNING_PASSPHRASE` | conditional for local | string | yes | Certificate passphrase |
| `NEXT_PRIVATE_SIGNING_GCLOUD_HSM_KEY_PATH` | conditional | string | no | HSM resource path |
| `NEXT_PRIVATE_SIGNING_GCLOUD_HSM_PUBLIC_CRT_FILE_PATH` | conditional | path | no | Mounted public certificate |
| `NEXT_PRIVATE_SIGNING_GCLOUD_HSM_PUBLIC_CRT_FILE_CONTENTS` | alternative to path | base64 string | no | Public certificate |
| `NEXT_PRIVATE_SIGNING_GCLOUD_APPLICATION_CREDENTIALS_CONTENTS` | conditional | base64 JSON | yes | Google credentials |
| `NEXT_PRIVATE_SIGNING_GCLOUD_HSM_CERT_CHAIN_FILE_PATH` | optional | path | no | Mounted chain |
| `NEXT_PRIVATE_SIGNING_GCLOUD_HSM_CERT_CHAIN_CONTENTS` | alternative to path | base64 string | no | Public chain |
| `NEXT_PRIVATE_SIGNING_GCLOUD_HSM_SECRET_MANAGER_CERT_PATH` | optional | string | no | Secret Manager resource path |
| `NEXT_PRIVATE_SIGNING_CSC_PROVIDER_BASE_URL` | conditional for CSC | URL | no | Enterprise-only provider |
| `NEXT_PRIVATE_SIGNING_CSC_OAUTH_CLIENT_ID` | conditional for CSC | string | no | OAuth client ID |
| `NEXT_PRIVATE_SIGNING_CSC_OAUTH_CLIENT_SECRET` | conditional for CSC | string | yes | OAuth client secret |
| `NEXT_PRIVATE_SIGNING_CSC_SIGNATURE_LEVEL` | `AES` | enum | no | `AES` or `QES` |
| `NEXT_PRIVATE_SIGNING_TIMESTAMP_AUTHORITY` | required for CSC; optional otherwise | comma-separated URLs | no | Instance refuses CSC startup without it |
| `NEXT_PUBLIC_SIGNING_CONTACT_INFO` | webapp URL | string | no | Embedded in PDF signatures |
| `NEXT_PRIVATE_USE_LEGACY_SIGNING_SUBFILTER` | `false` | boolean string | no | Legacy PDF signature subfilter |

Do **not** expose `NEXT_PUBLIC_SIGNING_TRANSPORT_IS_CSC` as a user value; the server derives and overwrites it ([derived-variable warning](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/apps/docs/content/docs/self-hosting/configuration/environment.mdx#L243-L251)).

### Feature flags, AI, and document conversion

Source: [feature flags](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/apps/docs/content/docs/self-hosting/configuration/environment.mdx#L265-L348), [AI and conversion](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/apps/docs/content/docs/self-hosting/configuration/environment.mdx#L352-L379).

| Variable | Required/default | Semantic type | Secret | Notes |
| --- | --- | --- | --- | --- |
| `NEXT_PUBLIC_DISABLE_SIGNUP` | `false` | boolean string | no | Master signup switch |
| `NEXT_PUBLIC_DISABLE_EMAIL_PASSWORD_SIGNUP` | `false` | boolean string | no | Email/password signup only |
| `NEXT_PUBLIC_DISABLE_GOOGLE_SIGNUP` | `false` | boolean string | no | Google signup |
| `NEXT_PUBLIC_DISABLE_MICROSOFT_SIGNUP` | `false` | boolean string | no | Microsoft signup |
| `NEXT_PUBLIC_DISABLE_OIDC_SIGNUP` | `false` | boolean string | no | OIDC signup |
| `NEXT_PRIVATE_ALLOWED_SIGNUP_DOMAINS` | optional | comma-separated list | no | Signup domain allowlist |
| `NEXT_PUBLIC_DISABLE_SIGNIN` | `false` | boolean string | no | Master signin switch |
| `NEXT_PUBLIC_DISABLE_EMAIL_PASSWORD_SIGNIN` | `false` | boolean string | no | Email/password signin |
| `NEXT_PUBLIC_DISABLE_GOOGLE_SIGNIN` | `false` | boolean string | no | Google signin |
| `NEXT_PUBLIC_DISABLE_MICROSOFT_SIGNIN` | `false` | boolean string | no | Microsoft signin |
| `NEXT_PUBLIC_DISABLE_OIDC_SIGNIN` | `false` | boolean string | no | OIDC signin |
| `NEXT_PUBLIC_DISABLE_OIDC_AUTO_REDIRECT` | `false` | boolean string | no | OIDC-only redirect opt-out |
| `NEXT_PUBLIC_POSTHOG_KEY` | optional | string | no | Public analytics key |
| `NEXT_PUBLIC_FEATURE_BILLING_ENABLED` | `false` | boolean string | no | Billing feature flag |
| `GOOGLE_VERTEX_PROJECT_ID` | optional | string | no | Vertex project |
| `GOOGLE_VERTEX_API_KEY` | optional | string | yes | Vertex credential |
| `GOOGLE_VERTEX_LOCATION` | `global` | string | no | Vertex region |
| `NEXT_PRIVATE_DOCUMENT_CONVERSION_URL` | optional | URL | no | Unset disables DOCX conversion |
| `NEXT_PRIVATE_DOCUMENT_CONVERSION_USERNAME` | conditional | string | yes | Gotenberg Basic auth |
| `NEXT_PRIVATE_DOCUMENT_CONVERSION_PASSWORD` | conditional | string | yes | Gotenberg Basic auth |
| `NEXT_PRIVATE_DOCUMENT_CONVERSION_TIMEOUT_MS` | `30000` | integer string (ms) | no | Request timeout |

Do **not** expose `NEXT_PUBLIC_DOCUMENT_CONVERSION_ENABLED`; the server derives it from the private conversion URL ([derived-variable warning](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/apps/docs/content/docs/self-hosting/configuration/environment.mdx#L366-L379)).

### Jobs, telemetry, logging, and enterprise

Source: [jobs variables](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/apps/docs/content/docs/self-hosting/configuration/environment.mdx#L383-L418), [telemetry/logging/enterprise](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/apps/docs/content/docs/self-hosting/configuration/environment.mdx#L422-L455).

| Variable | Required/default | Semantic type | Secret | Notes |
| --- | --- | --- | --- | --- |
| `NEXT_PRIVATE_JOBS_PROVIDER` | `local` | enum | no | `local`, `bullmq`, `inngest` |
| `NEXT_PRIVATE_REDIS_URL` | required for BullMQ | Redis URL | yes | URL may contain credentials |
| `NEXT_PRIVATE_REDIS_PREFIX` | `documenso` | string | no | Queue namespace |
| `NEXT_PRIVATE_BULLMQ_CONCURRENCY` | `10` | integer string | no | Worker concurrency |
| `NEXT_PRIVATE_INNGEST_EVENT_KEY` | required for Inngest | string | yes | Managed service credential |
| `INNGEST_EVENT_KEY` | optional alternative | string | yes | Managed service credential |
| `INNGEST_SIGNING_KEY` | required for Inngest | string | yes | Webhook-verification credential |
| `NEXT_PRIVATE_INNGEST_APP_ID` | optional | string | no | Custom app ID |
| `DOCUMENSO_DISABLE_TELEMETRY` | `false` | boolean string | no | License also auto-disables telemetry |
| `NEXT_PRIVATE_LOGGER_FILE_PATH` | optional | path | no | Disables stdout when set |
| `NEXT_PRIVATE_BROWSERLESS_URL` | optional | URL | yes | Treat as secret because URLs commonly embed credentials |
| `NEXT_PUBLIC_USE_INTERNAL_URL_BROWSERLESS` | optional | boolean string | no | Browserless routing |
| `NEXT_PRIVATE_DOCUMENSO_LICENSE_KEY` | optional/enterprise | string | yes | Enterprise license |
| `NEXT_PRIVATE_STRIPE_API_KEY` | optional/enterprise | string | yes | Billing credential |
| `NEXT_PRIVATE_STRIPE_WEBHOOK_SECRET` | optional/enterprise | string | yes | Webhook verification secret |
| `NEXT_PRIVATE_SES_ACCESS_KEY_ID` | optional/enterprise | string | yes | AWS credential |
| `NEXT_PRIVATE_SES_SECRET_ACCESS_KEY` | optional/enterprise | string | yes | AWS credential |
| `NEXT_PRIVATE_SES_REGION` | optional/enterprise | string | no | AWS region |

## Source-versus-docs drift

The official environment page calls itself the complete self-hosting reference, but the pinned `v2.16.0` [`.env.example`](https://github.com/documenso/documenso/blob/3cf2963cd03d8b24770b7490bdb20e596baa5d65/.env.example) additionally contains:

- `NEXT_PUBLIC_TURNSTILE_SITE_KEY` and secret `NEXT_PRIVATE_TURNSTILE_SECRET_KEY`;
- `NEXT_PRIVATE_PLAIN_API_KEY`;
- test-only `E2E_TEST_*` values and `DANGEROUS_BYPASS_RATE_LIMITS`.

The chart's generic `env`/`envFrom` surface will already permit these without hard-coding them. The user-facing values documentation should emphasize the official environment-page variables above and should not promote test-only variables as supported production chart settings.

## Validation targets for the implementation

1. `helm dependency build` resolves common `5.0.1` and PostgreSQL `18.8.2`; chart-managed Redis renders the pinned official `redis:8.8.1-alpine` image only when enabled.
2. `helm lint` and default rendering succeed only when a valid source is supplied for every genuinely required secret/value, or the README clearly documents deliberate placeholder behavior.
3. Render with external PostgreSQL and chart-managed PostgreSQL; inspect both database URLs and ensure password material is never emitted into a ConfigMap.
4. Render default local jobs with no Redis resources, then BullMQ with chart-managed Redis and external Redis.
5. Render local signing with a certificate Secret/subPath mount, local signing with base64 contents, and no certificate; the last case should render because upstream permits startup without signing.
6. Render database and S3 storage modes and verify no application data PVC is introduced.
7. Verify service port `3000`, all three `/api/health` probes, UID/GID `1001`, and absence of command override.
8. Render Ingress and Gateway API examples with a public URL consistent with `NEXT_PUBLIC_WEBAPP_URL`.
9. Ensure derived variables (`NEXT_PUBLIC_SIGNING_TRANSPORT_IS_CSC`, `NEXT_PUBLIC_DOCUMENT_CONVERSION_ENABLED`) are absent from documented user values.
10. Package the chart and verify `appVersion: 2.16.0` while the image tag remains `v2.16.0`.
