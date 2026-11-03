# Prepare PostgreSQL for Monoscope

Run these steps on your PostgreSQL server. Replace `db.example.invalid` with its hostname.
The examples assume PostgreSQL 18 from the PostgreSQL Apt repository and a Debian cluster named `main`.
An extension adds features to an existing PostgreSQL server. These steps keep your current databases and PostgreSQL installation.

Monoscope requires both TimescaleDB and TimescaleDB Toolkit. Its migrations create hypertables and call Toolkit functions.
Plain PostgreSQL cannot run these migrations. Installing TimeFusion does not remove this database requirement.

## Identify the installed server

Run these commands on your PostgreSQL server before installing packages. Use the running server version, not only the `psql` client version.
If the major version or cluster name differs, replace `18` and `main` throughout this guide.
Take a current database backup and schedule a maintenance window before package installation or restart.

```sh
cat /etc/os-release
pg_lsclusters
sudo -u postgres psql -X -p 5432 -c 'SELECT version();'
sudo -u postgres psql -X -p 5432 -c 'SHOW config_file;'
sudo -u postgres psql -X -p 5432 -c 'SHOW shared_preload_libraries;'
sudo -u postgres psql -X -p 5432 -c 'SHOW max_connections;'
```

## Install matching packages

These package examples require the PostgreSQL Apt repository. Make sure that it is configured for your Debian release.
Add the Timescale repository for the same release.
Do not change the distribution codename to force an unsupported package to install.
These commands use a dedicated keyring for the Timescale repository.

```sh
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://packagecloud.io/timescale/timescaledb/gpgkey |
  sudo gpg --dearmor -o /etc/apt/keyrings/timescaledb.gpg
sudo chmod 0644 /etc/apt/keyrings/timescaledb.gpg
. /etc/os-release
printf 'deb [signed-by=/etc/apt/keyrings/timescaledb.gpg] https://packagecloud.io/timescale/timescaledb/debian/ %s main\n' "$VERSION_CODENAME" |
  sudo tee /etc/apt/sources.list.d/timescaledb.list
sudo apt-get update
apt-cache policy timescaledb-2-postgresql-18 timescaledb-toolkit-postgresql-18
sudo apt-get -s install timescaledb-2-postgresql-18 timescaledb-toolkit-postgresql-18
```

Make sure that both packages have candidates and that the simulated installation preserves your PostgreSQL server.
If both conditions hold, install the packages during the maintenance window:

```sh
sudo apt-get install timescaledb-2-postgresql-18 timescaledb-toolkit-postgresql-18
```

Use the full TimescaleDB package. Monoscope uses compression features beyond the Apache-only edition.
The Toolkit package is separate and must also be installed.
If the packages are unavailable, stop and consult the vendor's supported-platform instructions.

## Configure preload libraries and restart

In the configuration file reported earlier, add `timescaledb` and `pg_stat_statements` to `shared_preload_libraries`.
Keep every existing library. For example, an existing `pg_cron` entry becomes:

```conf
shared_preload_libraries = 'timescaledb,pg_stat_statements,pg_cron'
```

If the existing list is empty, use:

```conf
shared_preload_libraries = 'timescaledb,pg_stat_statements'
```

Make sure that `postgresql.auto.conf` or another included file does not override this value.
`pg_settings` reports the active source file. `pg_file_settings` reports parsed entries and errors:

```sh
sudo -u postgres psql -X -c "SELECT name, setting, sourcefile FROM pg_settings WHERE name = 'shared_preload_libraries';"
sudo -u postgres psql -X -c "SELECT sourcefile, name, setting, applied, error FROM pg_file_settings WHERE name = 'shared_preload_libraries' OR error IS NOT NULL;"
```

Review `max_connections` for the combined workload. Upstream Compose sets 200 for Monoscope alone.
The application opens several connection pools. Reserve capacity for the other applications on this shared server.
Do not run `timescaledb-tune --yes` without reviewing its changes to memory and connection limits for the existing workload.

Restart the identified PostgreSQL cluster during the maintenance window. This interrupts all databases in that cluster:

```sh
sudo pg_ctlcluster 18 main restart
sudo -u postgres psql -X -c 'SHOW shared_preload_libraries;'
sudo -u postgres psql -X -c "SELECT name, default_version FROM pg_available_extensions WHERE name IN ('timescaledb', 'timescaledb_toolkit', 'pg_stat_statements');"
```

## Create the Monoscope database

Use a dedicated role and database. Run the following in an interactive `sudo -u postgres psql -X` session.
The `\password` command prompts for the password without storing it in shell history.
If the role or database already exists, inspect it before reusing it.

```sql
CREATE ROLE monoscope LOGIN;
\password monoscope
CREATE DATABASE monoscope OWNER monoscope;
\connect monoscope
CREATE EXTENSION IF NOT EXISTS timescaledb;
CREATE EXTENSION IF NOT EXISTS timescaledb_toolkit;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS hstore;
CREATE EXTENSION IF NOT EXISTS tablefunc;
\dx
```

An administrator creates these extensions before Monoscope starts. Keep the application role without server superuser privileges.
The application role owns its database and runs application migrations at startup.
Make sure that a connection as `monoscope` can call the required Toolkit and Timescale functions:

```sql
SET ROLE monoscope;
SELECT approx_percentile(0.5, percentile_agg(v)) FROM (VALUES (1.0), (2.0)) AS sample(v);
SELECT extname, extversion FROM pg_extension ORDER BY extname;
RESET ROLE;
```

Allow connections from the Kubernetes pod network in the PostgreSQL firewall and `pg_hba.conf`.
Use a rule limited to database `monoscope`, role `monoscope`, and the actual source network.
If your network translates pod addresses, use the source addresses seen by the database server.
Keep password authentication and configure TLS before using the connection string below.

```text
postgresql://monoscope:URL_ENCODED_PASSWORD@db.example.invalid:5432/monoscope?sslmode=require
```

`sslmode=require` encrypts traffic but does not verify the server identity by itself.
Use `verify-full` when the container trusts the server certificate chain through your PostgreSQL client configuration.
Store this URL under `DATABASE_URL` in the chart's existing Secret.
Make sure that application migrations finish successfully before sending production telemetry.

## References

These instructions follow the vendor's [Debian package installation guide](https://www.tigerdata.com/docs/get-started/choose-your-path/install-timescaledb).
The [Toolkit documentation](https://github.com/timescale/timescaledb-toolkit) describes the separate extension.
Monoscope's [initial migration](https://github.com/monoscope-tech/monoscope/blob/c0f99a928de19d44b1326404c20a4eb5e320087b/static/migrations/0001_create_monoscope_tables.sql) lists the required extensions.
