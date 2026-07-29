# Grist Helm chart research

Research date: 2026-07-29

## Recommended baseline

- Ship Grist `1.7.16` from `docker.io/gristlabs/grist:1.7.16`. This is the
  current non-prerelease GitHub release, and the immutable release commit is
  [`0408b156e7e2ea30a84f49392d1984bcd2748e25`](https://github.com/gristlabs/grist-core/commit/0408b156e7e2ea30a84f49392d1984bcd2748e25).
  The image tag deliberately has no leading `v`. The official tag supports
  `linux/amd64` and `linux/arm64`; avoid the mutable `latest`, `stable`, `1`,
  and `1.7` aliases. Sources: [GitHub release](https://github.com/gristlabs/grist-core/releases/tag/v1.7.16),
  [official image tags](https://hub.docker.com/r/gristlabs/grist/tags).
- Default to one replica, a `Recreate` deployment strategy, and a retained
  `ReadWriteOnce` PVC mounted at `/persist`. A reasonable starting request is
  20 GiB, matching upstream's known-good moderate deployment size. Grist's
  document files remain on `/persist` even when the home database is moved to
  PostgreSQL. Source: [self-managed resource and storage guidance](https://support.getgrist.com/self-managed/).
- Keep SQLite as the zero-dependency default. Offer external PostgreSQL and
  Redis through environment variables. A bundled PostgreSQL dependency must
  run PostgreSQL 16 or older: Grist documents compatibility with versions
  10–16, while this repository's current Bitnami chart dependency defaults to
  PostgreSQL 18. Do not silently deploy an unsupported major. Source:
  [external home database guidance](https://support.getgrist.com/self-managed/#how-do-i-use-postgresql-as-the-home-database).
- Keep Redis disabled by default. It is optional for basic operation, but is
  required for webhooks and notifications and recommended for snapshot-backed
  cloud storage. Source: [Redis guidance](https://support.getgrist.com/self-managed/#how-do-i-use-redis).
- Expose port `8484`; set `PORT` from the chart's service port; use
  `/status` for liveness and `/status?ready=1` for readiness/startup. Source:
  [health endpoint implementation](https://github.com/gristlabs/grist-core/blob/0408b156e7e2ea30a84f49392d1984bcd2748e25/app/server/lib/FlexServer.ts#L591-L670).
- Require `GRIST_SESSION_SECRET` as a Secret-backed value, expose
  `GRIST_BOOT_KEY` as another Secret-backed value, and derive `APP_HOME_URL`
  from the first configured Ingress or Gateway API hostname unless the user
  explicitly sets it. Source: [basic self-managed configuration](https://support.getgrist.com/self-managed/#how-do-i-run-grist-on-a-server).
- Do not set a numeric `runAsUser` by default. The image starts as root, fixes
  ownership of `/persist`, and then drops to a named `grist` user whose numeric
  UID/GID is not an upstream contract. A restrictive non-root override should
  be opt-in and validated against pre-owned storage. Sources:
  [Dockerfile](https://github.com/gristlabs/grist-core/blob/0408b156e7e2ea30a84f49392d1984bcd2748e25/Dockerfile#L152-L200),
  [entrypoint](https://github.com/gristlabs/grist-core/blob/0408b156e7e2ea30a84f49392d1984bcd2748e25/sandbox/docker_entrypoint.sh#L6-L49).
- Do not enable gVisor automatically. Expose `GRIST_SANDBOX_FLAVOR` and an
  opt-in `SYS_PTRACE` capability setting, with a warning that gVisor requires
  compatible x86 hardware/XSAVE support and may not work in every Kubernetes
  runtime. Source: [sandbox guidance](https://support.getgrist.com/self-managed/#how-do-i-enable-sandboxing).

## Release and image facts

The current stable release is
[`v1.7.16`](https://github.com/gristlabs/grist-core/releases/tag/v1.7.16),
published on 2026-06-30. Its tag resolves to commit
[`0408b156e7e2ea30a84f49392d1984bcd2748e25`](https://github.com/gristlabs/grist-core/commit/0408b156e7e2ea30a84f49392d1984bcd2748e25).
The exact official image is `docker.io/gristlabs/grist:1.7.16`; Docker Hub
publishes both amd64 and arm64 manifests for it. Upstream also publishes
`gristlabs/grist-oss`, which excludes the inert source-available full-edition
extensions included in the default image. Keep the repository configurable,
but use `gristlabs/grist` as the documented upstream default. Sources:
[official tags](https://hub.docker.com/r/gristlabs/grist/tags),
[image-edition explanation](https://github.com/gristlabs/grist-core/blob/0408b156e7e2ea30a84f49392d1984bcd2748e25/README.md#available-docker-images).

Suggested chart metadata:

| Field | Recommended value |
|---|---|
| `appVersion` | `1.7.16` |
| image repository | `docker.io/gristlabs/grist` |
| image tag | `1.7.16` |
| pull policy | `IfNotPresent` |
| architectures | `amd64`, `arm64` |
| container port | `8484` |

## Container runtime contract

The stable Dockerfile uses `/grist` as its working directory and defaults:

- `GRIST_DATA_DIR=/persist/docs`
- `GRIST_INST_DIR=/persist`
- `TYPEORM_DATABASE=/persist/home.sqlite3`
- `EXPOSE 8484`
- entrypoint `./sandbox/docker_entrypoint.sh`
- command `./sandbox/run.sh`

The image creates a named `grist` user but does not pin its numeric UID/GID and
does not declare a Dockerfile `USER`. When started as root, the entrypoint
changes `/persist` ownership, creates the user's home under
`/grist_user_homes`, drops to the configured named user/group using `setpriv`,
and wraps the server with `tini`. When started non-root, it instead validates
that the required paths are readable and writable. The run script optionally
checks gVisor, then execs the Node server. The published 1.7.16 image happens
to assign UID/GID 1001 to `grist`, but that value is incidental rather than
pinned by the Dockerfile; its image user remains root and it defines no
embedded Docker health check. Sources:
[Dockerfile](https://github.com/gristlabs/grist-core/blob/0408b156e7e2ea30a84f49392d1984bcd2748e25/Dockerfile#L152-L200),
[entrypoint](https://github.com/gristlabs/grist-core/blob/0408b156e7e2ea30a84f49392d1984bcd2748e25/sandbox/docker_entrypoint.sh#L6-L49),
[run script](https://github.com/gristlabs/grist-core/blob/0408b156e7e2ea30a84f49392d1984bcd2748e25/sandbox/run.sh#L1-L19),
[official image API](https://hub.docker.com/v2/repositories/gristlabs/grist/tags/1.7.16).

Recommended runtime defaults:

| Setting | Default | Reason |
|---|---|---|
| replicas | `1` | local document SQLite files and RWO storage |
| strategy | `Recreate` | prevents two pods opening the same local state |
| pod seccomp | `RuntimeDefault` | safe baseline; test in chart CI |
| `runAsNonRoot` / numeric UID | unset | upstream does not contract a numeric UID |
| read-only root filesystem | unset | entrypoint writes user-home state |
| gVisor capability | disabled | `SYS_PTRACE` must be an explicit operator choice |
| termination grace | at least 30 seconds | allow Node and open documents to stop cleanly |

Upstream reports 8 GiB RAM, 2 CPUs, and 20 GiB disk as a known-good moderate
configuration. Minimal testing is possible around 100 MiB without sandboxing
or 200 MiB with sandboxing and one CPU, but those figures are not suitable
production requests. Start with requests around `500m` CPU/`1Gi` memory and
leave limits unset or generously configurable; document the upstream sizing
rather than promising it as a capacity guarantee. Source:
[resource guidance](https://support.getgrist.com/self-managed/#what-resources-does-grist-need).

### Health probes

`GET /status` returns HTTP 200 with an “alive” response when the process is
internally healthy and HTTP 500 otherwise. The endpoint accepts checks
including `ready=1`, `db=1`, `redis=1`, and `docWorkerRegistered=1`.

Recommended probes:

| Probe | Path | Suggested timing |
|---|---|---|
| liveness | `/status` | 10 s period, 5 s timeout, 3 failures |
| readiness | `/status?ready=1` | 5 s period, 5 s timeout, 6 failures |
| startup | `/status?ready=1` | 5 s period, 60 failures |

Do not couple liveness to PostgreSQL or Redis. Operators that want dependency
gating may override readiness with `db=1` or `redis=1`. Source:
[status route](https://github.com/gristlabs/grist-core/blob/0408b156e7e2ea30a84f49392d1984bcd2748e25/app/server/lib/FlexServer.ts#L591-L670).

## Persistence and database topology

The `/persist` volume contains:

- `/persist/docs/*.grist`: one SQLite database per Grist document.
- `/persist/grist-sessions.db`: session state unless Redis is configured.
- `/persist/home.sqlite3`: users, organizations, workspaces, and other home
  metadata unless PostgreSQL is configured.

Source: [stored-file inventory](https://support.getgrist.com/self-managed/#what-files-does-grist-store).

External PostgreSQL only replaces `home.sqlite3`; it does not move the
`.grist` document databases. Consequently:

1. Keep `/persist` enabled and durable with either database mode.
2. Default to one replica and `Recreate`.
3. Do not describe external PostgreSQL alone as HA.
4. Back up both PostgreSQL and `/persist`; if cloud snapshots are enabled,
   include the versioned object bucket in the recovery plan.

The external home database contract is:

```text
TYPEORM_TYPE=postgres
TYPEORM_DATABASE=<database>
TYPEORM_USERNAME=<username>
TYPEORM_PASSWORD=<secret>
TYPEORM_HOST=<hostname>
TYPEORM_PORT=<port>
```

`TYPEORM_EXTRA` accepts additional TypeORM properties as JSON, and
`TYPEORM_LOGGING` enables query logging. Grist documents PostgreSQL versions
10 through 16. Since Grist 1.5.0 it disables PostgreSQL JIT itself, so a chart
for 1.7.16 does not need to force `jit=off`. Sources:
[PostgreSQL setup](https://support.getgrist.com/self-managed/#how-do-i-use-postgresql-as-the-home-database),
[environment reference](https://github.com/gristlabs/grist-core/blob/0408b156e7e2ea30a84f49392d1984bcd2748e25/README.md#environment-variables).

### Redis

`REDIS_URL` moves sessions and shared state out of
`/persist/grist-sessions.db`. Upstream says basic use works without Redis, but
webhooks and notifications require it, and snapshot storage is best tested
with it. Upstream does not publish a supported Redis-version matrix, so a
chart-managed Redis/Valkey version must be treated as chart-tested rather than
upstream-certified. Keep it optional and allow an external `REDIS_URL`.
Source: [Redis setup](https://support.getgrist.com/self-managed/#how-do-i-use-redis).

## Public routing

Set `APP_HOME_URL` to the browser-visible origin, for example
`https://grist.example.com`. The reverse proxy must preserve `Host` and support
HTTP/1.1 WebSocket upgrade/connection headers. `PORT` changes the actual
listening port; changing only the Service target is not sufficient. Sources:
[public URL and reverse-proxy requirements](https://support.getgrist.com/self-managed/#how-do-i-run-grist-on-a-server),
[port behavior](https://github.com/gristlabs/grist-core/blob/0408b156e7e2ea30a84f49392d1984bcd2748e25/README.md#using-grist).

The chart should support both the repository's Ingress shape and its custom
Gateway API `HTTPRoute` template. Derive `APP_HOME_URL` only when the user has
not set it, using `https` when TLS or the Gateway protocol indicates it. Keep
the Service as `ClusterIP` by default.

## Authentication and administrator bootstrap

`GRIST_DEFAULT_EMAIL` is the initial/default identity in minimal deployments
and defaults to `you@example.com`. Changing it later can transfer installation
administrator status, so the README must call it a durable identity setting.
`GRIST_SINGLE_ORG` restricts the installation to one organization and accepts
lowercase letters, digits, and hyphens. `GRIST_BOOT_KEY` enables installation
administrator access through the boot/admin flow and must be secret-backed.
`GRIST_IN_SERVICE=true` skips Quick Setup; leave it unset by default so a new
installation can complete setup. Sources:
[administrator and organization behavior](https://support.getgrist.com/self-managed/#how-do-i-run-grist-on-a-server),
[main environment reference](https://github.com/gristlabs/grist-core/blob/0408b156e7e2ea30a84f49392d1984bcd2748e25/README.md#environment-variables).

Supported login modes are `minimal`, `oidc`, `saml`, and `forward-auth`.

### OpenID Connect

Required variables:

- `GRIST_OIDC_IDP_ISSUER`
- `GRIST_OIDC_IDP_CLIENT_ID`
- `GRIST_OIDC_IDP_CLIENT_SECRET` (secret)

Expose the optional scope, profile-attribute, logout, ACR, and protection
settings too: `GRIST_OIDC_IDP_SCOPES`, `GRIST_OIDC_SP_HOST`,
`GRIST_OIDC_IDP_END_SESSION_ENDPOINT`,
`GRIST_OIDC_IDP_SKIP_END_SESSION_ENDPOINT`,
`GRIST_OIDC_SP_PROFILE_NAME_ATTR`, `GRIST_OIDC_SP_PROFILE_EMAIL_ATTR`,
`GRIST_OIDC_IDP_ENABLED_PROTECTIONS`, `GRIST_OIDC_IDP_ACR_VALUES`,
`GRIST_OIDC_IDP_EXTRA_CLIENT_METADATA`, and
`GRIST_OIDC_SP_IGNORE_EMAIL_VERIFIED`. Keep the documented default
protections `PKCE,STATE`; ignoring email verification is an explicit unsafe
opt-in. The callback is `/oauth2/callback`. Source:
[official OIDC guide](https://support.getgrist.com/install/oidc/).

### SAML

Expose `GRIST_SAML_SP_HOST`, `GRIST_SAML_SP_KEY`, `GRIST_SAML_SP_CERT`,
`GRIST_SAML_IDP_LOGIN`, `GRIST_SAML_IDP_LOGOUT`,
`GRIST_SAML_IDP_SKIP_SLO`, `GRIST_SAML_IDP_CERTS`, and
`GRIST_SAML_IDP_UNENCRYPTED`. Provide generic extra Secret volumes/mounts for
the SP private key and certificates rather than inventing inline values.
Unencrypted assertions must remain an opt-in. The assertion callback is
`/saml/assert`. Source: [official SAML guide](https://support.getgrist.com/install/saml/).

### Forward authentication

Expose `GRIST_FORWARD_AUTH_HEADER`, `GRIST_FORWARD_AUTH_LOGIN_PATH`, and
`GRIST_FORWARD_AUTH_LOGOUT_PATH`. The ingress/proxy must remove user-supplied
copies of the trusted identity header before setting its own value.
`GRIST_IGNORE_SESSION=true` makes that boundary stricter because Grist trusts
the header on every request. Source:
[official forwarded-header guide](https://support.getgrist.com/install/forwarded-headers/).

## Email, webhooks, storage, plugins, and workers

### Email and webhooks

Email sending is a full-edition feature. It uses
`GRIST_NODEMAILER_CONFIG` (secret JSON passed to Nodemailer's transport) and
`GRIST_NODEMAILER_SENDER` (sender JSON), and requires `REDIS_URL`. Webhooks
also require Redis and `ALLOWED_WEBHOOK_DOMAINS`. Never default the latter to
`*`; unrestricted webhook targets can expose cluster-internal services. If an
operator deliberately allows broad targets, expose
`GRIST_PROXY_FOR_UNTRUSTED_URLS` and recommend egress controls. Sources:
[email configuration](https://support.getgrist.com/self-managed/#how-do-i-set-up-email),
[webhook configuration](https://support.getgrist.com/self-managed/#how-do-i-set-up-webhooks).

### S3-compatible snapshot storage

S3-compatible storage is available in all editions through:

- `GRIST_DOCS_MINIO_ACCESS_KEY` (secret)
- `GRIST_DOCS_MINIO_SECRET_KEY` (secret)
- `GRIST_DOCS_MINIO_BUCKET`
- `GRIST_DOCS_MINIO_ENDPOINT` (hostname without scheme or port)
- `GRIST_DOCS_MINIO_USE_SSL` (default `1`)
- `GRIST_DOCS_MINIO_PORT`
- `GRIST_DOCS_MINIO_PREFIX` (default `docs/`)
- `GRIST_DOCS_MINIO_BUCKET_REGION` (default `us-east-1`)

The bucket must have versioning enabled. Native AWS variables
`GRIST_DOCS_S3_BUCKET` and `GRIST_DOCS_S3_PREFIX` plus standard AWS
credentials, and Azure variables `AZURE_STORAGE_CONNECTION_STRING`,
`GRIST_AZURE_CONTAINER`, and `GRIST_AZURE_PREFIX`, are full-edition options.
`GRIST_EXTERNAL_ATTACHMENTS_MODE=snapshots` stores attachments through the
configured snapshot backend. Redis is recommended, and operators should
back up before changing an existing installation's storage mode. Source:
[official cloud-storage guide](https://support.getgrist.com/install/cloud-storage/).

### Plugins and custom widgets

`GRIST_WIDGET_LIST_URL` selects the widget manifest.
`GRIST_USER_ROOT` adds a filesystem root under which Grist scans `plugins/`;
the chart therefore needs generic persistence/volume-mount escape hatches.
`APP_UNTRUSTED_URL` or `GRIST_UNTRUSTED_PORT` isolates plugin content.
`GRIST_TRUST_PLUGINS` serves plugins in the trusted origin and must stay
unset unless the operator accepts cookie exposure. Source:
[plugin configuration](https://github.com/gristlabs/grist-core/blob/0408b156e7e2ea30a84f49392d1984bcd2748e25/README.md#plugins).

### Worker topology

The image's default `GRIST_SERVERS=home,docs,static` runs a monolith, which is
the correct first chart release. Split home/doc/static workers require
coordinated `APP_HOME_URL`, `APP_HOME_INTERNAL_URL`, `APP_DOC_URL`,
`APP_DOC_INTERNAL_URL`, `GRIST_ROUTER_URL`, `GRIST_MANAGED_WORKERS`, and Redis
service discovery. Do not expose a replica slider as if it implemented that
topology. Keep the common chart's controller escape hatch for advanced users,
but document split workers as unsupported by the chart until separately
designed and tested. Redis-backed BullMQ jobs run in the application process;
upstream does not require a separate queue-worker container. Sources:
[worker environment contract](https://github.com/gristlabs/grist-core/blob/0408b156e7e2ea30a84f49392d1984bcd2748e25/README.md#environment-variables),
[job-provider implementation](https://github.com/gristlabs/grist-core/blob/0408b156e7e2ea30a84f49392d1984bcd2748e25/app/server/lib/GristJobs.ts#L117-L185).

## Kubernetes-relevant environment contract

The chart should accept both:

1. an `env` map whose values may be strings or Kubernetes `valueFrom`
   references; and
2. `envFrom` Secret/ConfigMap references for large installations.

The following is the complete Kubernetes-relevant surface documented by Grist
1.7.16. Test-only variables are intentionally excluded. Variables marked
**secret** should be shown with Secret references in examples, never literal
defaults. Unless another source is linked above, descriptions and defaults
come from the immutable
[v1.7.16 environment table](https://github.com/gristlabs/grist-core/blob/0408b156e7e2ea30a84f49392d1984bcd2748e25/README.md#environment-variables).

### Core server, URLs, and routing

| Variables | Chart treatment |
|---|---|
| `PORT`, `HOME_PORT`, `GRIST_HOST` | derive `PORT` from Service; expose overrides |
| `APP_HOME_URL`, `APP_HOME_INTERNAL_URL`, `APP_DOC_URL`, `APP_DOC_INTERNAL_URL`, `APP_STATIC_URL`, `APP_UNTRUSTED_URL` | expose; derive only public home URL |
| `APP_STATIC_INCLUDE_CUSTOM_CSS`, `GRIST_INCLUDE_CUSTOM_SCRIPT_URL` | expose; custom script is security-sensitive |
| `GRIST_APP_ROOT`, `GRIST_INST_DIR`, `GRIST_DATA_DIR` | expose, but preserve image `/persist` defaults |
| `GRIST_SERVERS`, `GRIST_ROUTER_URL`, `GRIST_MANAGED_WORKERS` | advanced split-worker settings |
| `GRIST_ORG_IN_PATH`, `GRIST_SERVE_SAME_ORIGIN`, `GRIST_ADAPT_DOMAIN`, `GRIST_DOMAIN`, `GRIST_ID_PREFIX` | advanced routing; warn that trusted Host handling matters |
| `GRIST_UNTRUSTED_PORT`, `GRIST_PROMCLIENT_PORT` | expose extra ports only via common-chart overrides; metrics should remain internal |
| `GRIST_HEADERS_TIMEOUT_MS`, `GRIST_KEEP_ALIVE_TIMEOUT_MS`, `GRIST_REQUEST_TIMEOUT_MS` | optional Node HTTP timeouts |
| `HTTPS_PROXY`, `https_proxy` | proxy URL may contain credentials; allow Secret reference |
| `GRIST_PROXY_FOR_UNTRUSTED_URLS` | expose for controlled webhook egress |

### Sessions, access, and installation

| Variables | Chart treatment |
|---|---|
| `GRIST_SESSION_SECRET` | **secret; required chart validation** |
| `GRIST_BOOT_KEY` | **secret; strongly recommended** |
| `GRIST_SESSION_COOKIE`, `GRIST_SESSION_DOMAIN`, `COOKIE_MAX_AGE`, `GRIST_IGNORE_SESSION` | expose |
| `GRIST_DEFAULT_EMAIL`, `GRIST_DEFAULT_PRODUCT`, `GRIST_SINGLE_ORG`, `GRIST_TEMPLATE_ORG`, `GRIST_INSTALL_ADMIN_ORG` | expose; document durable admin/org effects |
| `GRIST_IN_SERVICE` | leave unset for new-install Quick Setup |
| `GRIST_FORCE_LOGIN`, `GRIST_SUPPORT_ANON`, `GRIST_ANON_PLAYGROUND` | expose |
| `GRIST_PERSONAL_ORGS`, `GRIST_ORG_CREATION_ANYONE`, `GRIST_LIST_PUBLIC_SITES` | expose |
| `GRIST_SUPPORT_EMAIL`, `GRIST_MAX_NEW_USER_INVITES_PER_ORG`, `GRIST_MAX_BILLING_MANAGERS_PER_ORG` | expose |
| `GRIST_LOGIN_SYSTEM_TYPE`, `GRIST_IDP_EXTRA_PROPS` | expose with login-provider groups |

### Database, cache, and cloud storage

| Variables | Chart treatment |
|---|---|
| `TYPEORM_TYPE`, `TYPEORM_DATABASE`, `TYPEORM_USERNAME`, `TYPEORM_PASSWORD`, `TYPEORM_HOST`, `TYPEORM_PORT`, `TYPEORM_EXTRA`, `TYPEORM_LOGGING` | inject for a compatible bundled PostgreSQL; password is **secret** |
| `REDIS_URL` | **secret-capable URL**; inject only for chart-managed Redis |
| `GRIST_SQLITE_MODE` | optional `wal` or `sync` |
| `GRIST_DOCS_MINIO_*`, `GRIST_DOCS_S3_*`, `AWS_*`, `AZURE_STORAGE_CONNECTION_STRING`, `GRIST_AZURE_*` | expose; credentials/connection string are **secret** |
| `GRIST_EXTERNAL_ATTACHMENTS_MODE` | expose; `snapshots` needs configured cloud storage |
| `GRIST_SNAPSHOT_TIME_CAP`, `GRIST_SNAPSHOT_KEEP`, `GRIST_BACKUP_DELAY_SECS` | expose retention/backup tuning |

### Features, uploads, UI, and localization

| Variables | Chart treatment |
|---|---|
| `GRIST_ACTION_HISTORY_MAX_ROWS`, `GRIST_ACTION_HISTORY_MAX_BYTES` | expose; defaults 1000 and 1 GiB |
| `GRIST_ATTACHMENT_THRESHOLD_MB`, `GRIST_MAX_UPLOAD_ATTACHMENT_MB`, `GRIST_MAX_UPLOAD_IMPORT_MB` | expose and align proxy body limits |
| `GRIST_MAX_PARALLEL_REQUESTS_PER_DOC`, `GRIST_BROADCAST_TIMEOUT_MS` | expose concurrency/timeouts |
| `GRIST_ENABLE_SERVICE_ACCOUNTS`, `GRIST_ENABLE_SCIM`, `GRIST_ENABLE_USER_PRESENCE` | expose |
| `GRIST_ENABLE_REQUEST_FUNCTION` | expose but label as high-risk outbound access |
| `GRIST_ALLOW_DEPRECATED_BARE_ORG_DELETE` | compatibility-only opt-in; leave unset |
| `GRIST_EXPERIMENTAL_PLUGINS`, `GRIST_TRUST_PLUGINS`, `GRIST_USER_ROOT`, `GRIST_WIDGET_LIST_URL`, `GRIST_SKIP_BUNDLED_WIDGETS` | expose; trusted plugins are security-sensitive |
| `GRIST_HIDE_UI_ELEMENTS`, `GRIST_UI_FEATURES`, `GRIST_PAGE_TITLE_SUFFIX`, `GRIST_OPEN_GRAPH_PREVIEW_IMAGE` | expose |
| `GRIST_DEFAULT_LOCALE`, `GRIST_OFFER_ALL_LANGUAGES`, `GRIST_TRUTHY_VALUES`, `GRIST_FALSY_VALUES` | expose |
| `GRIST_HELP_CENTER`, `GRIST_TERMS_OF_SERVICE_URL`, `FREE_COACHING_CALL_URL`, `GRIST_CONTACT_SUPPORT_URL`, `GRIST_ONBOARDING_VIDEO_ID`, `GRIST_CUSTOM_COMMON_URLS` | expose custom links; common URLs are JSON |
| `GRIST_FEATURE_FORM_FRAMING` | expose `border`/`minimal`; keep secure default |

### Observability, telemetry, and outbound integrations

| Variables | Chart treatment |
|---|---|
| `GRIST_LOG_HTTP`, `GRIST_LOG_HTTP_BODY`, `GRIST_LOG_AS_JSON`, `GRIST_LOG_API_DETAILS` | expose; warn request-body logs can leak confidential data |
| `GRIST_TELEMETRY_LEVEL` | explicitly default `off` |
| `GRIST_ALLOW_AUTOMATIC_VERSION_CHECKING` | recommend explicit `false` as a chart privacy/default-egress choice |
| `GRIST_THROTTLE_CPU` | expose |
| `ALLOWED_WEBHOOK_DOMAINS` | expose; never default wildcard |
| `GRIST_NODEMAILER_CONFIG`, `GRIST_NODEMAILER_SENDER` | expose as **secret-capable JSON** |
| `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_API_KEY`, `GOOGLE_DRIVE_SCOPE` | expose; credentials/API key are **secret** |
| `ASSISTANT_API_KEY`, `OPENAI_API_KEY`, `ASSISTANT_CHAT_COMPLETION_ENDPOINT`, `ASSISTANT_MODEL`, `ASSISTANT_LONGER_CONTEXT_MODEL` | expose; API keys are **secret** |

### Sandbox and Docker entrypoint

| Variables | Chart treatment |
|---|---|
| `GRIST_SANDBOX_FLAVOR`, `GRIST_SANDBOX` | expose; do not choose an unsafe/unportable default silently |
| `GVISOR_LIMIT_NPROC`, `GVISOR_LIMIT_MEMORY` | expose only with gVisor documentation |
| `GRIST_DOCKER_USER`, `GRIST_DOCKER_GROUP` | expose entrypoint overrides; no chart-assumed numeric UID |

Also expose the OIDC, SAML, and forward-auth variables enumerated in the
authentication section. Do not copy the upstream `GRIST_TEST_*`,
`GREP_TESTS`, TLS-offset, mock-router, or fake-login variables into production
values; they are explicitly test-only.

## Proposed repository integration

The chart can follow the established `paperless-ngx` and `documenso` layout:

```text
charts/grist/
  Chart.yaml
  values.yaml
  README_CONFIG.md.gotmpl
  templates/
    _helpers.tpl
    common.yaml
    gateway.yaml
    redis.yaml          # only if chart-managed Redis is retained
    NOTES.txt
```

Use the same bjw-s common library version as the sibling charts and declare
the Kubernetes floor that the selected common version actually supports
(`>=1.31.0-0` for common `5.0.1`), rather than copying Paperless's stale
`>=1.22.0-0` claim. Reuse these local conventions:

- map-style `env` plus `envFrom`;
- first-host derivation for `APP_HOME_URL`;
- Ingress and Gateway API `HTTPRoute`;
- Service port named `http`;
- explicit liveness/readiness/startup probes;
- retained PVC support and generic common-chart escape hatches;
- optional chart-managed Redis with external-secret support.

Grist-specific differences:

- `/persist` is a single coherent application-state volume; do not split it
  into Paperless-style data/media/export PVCs.
- Use `Recreate`, not Documenso's `RollingUpdate`.
- Do not copy Documenso's numeric `runAsUser`; Grist does not pin one.
- PostgreSQL is optional and replaces only home metadata.
- A current bundled PostgreSQL 18 default is outside Grist's documented
  support. Pin a tested 16.x database image or omit the dependency until a
  compatible packaging choice exists.
- Redis remains disabled for the basic monolith but becomes required when the
  user configures webhooks, notifications, or the documented email path.
- Validate `GRIST_SESSION_SECRET`, but permit `envFrom` to satisfy it because
  Helm cannot inspect referenced Secrets.

Suggested values shape:

```yaml
image:
  repository: docker.io/gristlabs/grist
  tag: 1.7.16
  pullPolicy: IfNotPresent

replicaCount: 1

envFrom: []
env:
  TZ: UTC
  GRIST_SESSION_SECRET: ""
  GRIST_DEFAULT_EMAIL: you@example.com
  GRIST_TELEMETRY_LEVEL: "off"
  GRIST_ALLOW_AUTOMATIC_VERSION_CHECKING: "false"
  # GRIST_BOOT_KEY:
  #   secretKeyRef: {name: grist-secrets, key: boot-key}
  # GRIST_SANDBOX_FLAVOR: gvisor

service:
  main:
    ports:
      http:
        port: 8484

persistence:
  persist:
    enabled: true
    retain: true
    mountPath: /persist
    accessMode: ReadWriteOnce
    size: 20Gi

postgresql:
  enabled: false

redis:
  enabled: false
```

## Implementation validation targets

Before releasing the chart:

1. Render the minimal SQLite configuration with a Secret-backed
   `GRIST_SESSION_SECRET`; assert one replica, `Recreate`, `/persist`, port
   8484, and all three probes.
2. Install on an empty PVC, complete Quick Setup, create a document, restart
   the pod, and verify the installation identity and document survive.
3. Render an external PostgreSQL configuration and verify `/persist` remains
   mounted.
4. If bundled PostgreSQL is included, inspect the rendered StatefulSet image
   and prove its server major is 16 or older; exercise migration and restart.
5. Exercise Redis disabled and enabled, including password injection from both
   a chart-created Secret and `existingSecret`.
6. Verify an Ingress and an `HTTPRoute` both derive the correct
   `APP_HOME_URL`, and test a live WebSocket connection through each.
7. Verify `env` values can use `secretKeyRef` and that `envFrom` works without
   leaking secret data into rendered manifests or NOTES.
8. Run the image with the chart's default security context on a fresh PVC and
   a reused PVC. Separately test a documented non-root override.
9. Test the gVisor opt-in only on a compatible node/runtime and verify the
   required capability is absent when the option is disabled.
10. Run `helm lint`, template all dependency combinations, regenerate the
    chart README, and validate against the repository's supported Kubernetes
    schema versions.

## Primary sources

- [Grist self-managed documentation](https://support.getgrist.com/self-managed/)
- [Grist 1.7.16 release](https://github.com/gristlabs/grist-core/releases/tag/v1.7.16)
- [Grist 1.7.16 source commit](https://github.com/gristlabs/grist-core/commit/0408b156e7e2ea30a84f49392d1984bcd2748e25)
- [Immutable environment-variable reference](https://github.com/gristlabs/grist-core/blob/0408b156e7e2ea30a84f49392d1984bcd2748e25/README.md#environment-variables)
- [Immutable Dockerfile](https://github.com/gristlabs/grist-core/blob/0408b156e7e2ea30a84f49392d1984bcd2748e25/Dockerfile#L152-L200)
- [Immutable container entrypoint](https://github.com/gristlabs/grist-core/blob/0408b156e7e2ea30a84f49392d1984bcd2748e25/sandbox/docker_entrypoint.sh#L6-L49)
- [Immutable health-route implementation](https://github.com/gristlabs/grist-core/blob/0408b156e7e2ea30a84f49392d1984bcd2748e25/app/server/lib/FlexServer.ts#L591-L670)
- [Official OIDC guide](https://support.getgrist.com/install/oidc/)
- [Official SAML guide](https://support.getgrist.com/install/saml/)
- [Official forwarded-auth guide](https://support.getgrist.com/install/forwarded-headers/)
- [Official cloud-storage guide](https://support.getgrist.com/install/cloud-storage/)
- [Official Docker Hub repository](https://hub.docker.com/r/gristlabs/grist/tags)
