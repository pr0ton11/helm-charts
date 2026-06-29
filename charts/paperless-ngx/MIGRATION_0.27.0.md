# Migrating to chart 0.27.0

Chart `0.27.0` updates Paperless-ngx to `3.0.0-beta.rc1`. Before upgrading, read the upstream [Paperless-ngx v3 migration guide](https://github.com/paperless-ngx/paperless-ngx/blob/dev/docs/migration-v3.md).

Paperless-ngx v3 upgrades are only supported from Paperless-ngx `2.20.15`. If your deployment is running an older app version, upgrade to chart `0.25.1` or another chart release that runs Paperless-ngx `2.20.15` first.

## Secret key

Paperless-ngx v3 requires `PAPERLESS_SECRET_KEY`. Chart `0.27.0` fails rendering when `env.PAPERLESS_SECRET_KEY` is not configured.

Generate a new secret key with:

```console
python3 -c "import secrets; print(secrets.token_urlsafe(64))"
```

Set it directly in values:

```yaml
env:
  PAPERLESS_SECRET_KEY: change-me
```

Or reference an existing Kubernetes Secret:

```yaml
env:
  PAPERLESS_SECRET_KEY:
    secretKeyRef:
      name: paperless-secret
      key: PAPERLESS_SECRET_KEY
```

Existing installations may keep their previous secret key to preserve existing sessions and signed tokens. Using a new key improves security if you previously relied on the old built-in default, but it invalidates existing sessions and other signed tokens.

## External databases

Paperless-ngx v3 requires `PAPERLESS_DBENGINE` for PostgreSQL and MariaDB.

External PostgreSQL example:

```yaml
postgresql:
  enabled: false

env:
  PAPERLESS_DBENGINE: postgresql
  PAPERLESS_DBHOST: postgres.example.invalid
  PAPERLESS_DBNAME: paperless
  PAPERLESS_DBUSER: paperless
  PAPERLESS_DBPASS: change-me
```

External MariaDB example:

```yaml
mariadb:
  enabled: false

env:
  PAPERLESS_DBENGINE: mariadb
  PAPERLESS_DBHOST: mariadb.example.invalid
  PAPERLESS_DBNAME: paperless
  PAPERLESS_DBUSER: paperless
  PAPERLESS_DBPASS: change-me
```

For compatibility with common `0.26.x` external PostgreSQL deployments, the chart injects `PAPERLESS_DBENGINE: postgresql` when `env.PAPERLESS_DBHOST` is set, neither bundled database is enabled, and `env.PAPERLESS_DBENGINE` is not set. Set `PAPERLESS_DBENGINE` explicitly when using MariaDB or when you want the value to be obvious in your own values file.

## Database advanced options

Paperless-ngx v3 deprecates individual database SSL, timeout, and pooling variables in favor of `PAPERLESS_DB_OPTIONS`.

Example:

```yaml
env:
  PAPERLESS_DB_OPTIONS: sslmode=require,sslrootcert=/certs/ca.pem,pool.max_size=10
```

Deprecated database variables such as `PAPERLESS_DBSSLMODE` still pass through the chart, but Paperless-ngx v3 may log startup warnings for them and remove them in a future release.
