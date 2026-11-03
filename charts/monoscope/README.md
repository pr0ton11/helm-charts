# Monoscope

This chart runs one Monoscope application instance and, by default, one TimeFusion instance.
It connects to an external PostgreSQL database with TimescaleDB and TimescaleDB Toolkit.
TimeFusion stores telemetry in a configurable S3 bucket. Monoscope uses the same S3 configuration for replay objects.
The chart does not create PostgreSQL databases, S3 buckets, or credentials.

## Prepare the database and storage

Follow [the PostgreSQL setup guide](docs/postgresql.md) before installing the chart.
Replace `db.example.invalid` with your database hostname.
The chart runs migrations at startup with the database role from `DATABASE_URL`.

Create a dedicated S3 bucket and an access key with permission to list, read, write, delete, and use multipart uploads in that bucket.
Set `s3.bucket`, `s3.endpoint`, `s3.region`, and `s3.existingSecret` in your values file.
For an HTTP endpoint, also set `s3.allowHttp=true`. Use HTTPS for traffic that crosses untrusted networks.
You can change credential key names through `s3.accessKeyKey` and `s3.secretKeyKey`.

TimeFusion needs persistent local disk for its write-ahead log (WAL), which stores writes before they reach S3.
The chart defaults to a retained 50 GiB `local-path` volume. Use `timefusion.persistence` to change its size, storage class, or existing claim.
Do not use NFS for the WAL without proving its filesystem semantics and performance for TimeFusion.
A local-path volume binds the instance to one node. Loss of that disk can lose writes that are not yet stored in S3.
The chart disables the optional Foyer cache to avoid unexpected disk use on the WAL volume.

## Create Secrets

Create the following Secrets in the release namespace before installation. Replace every placeholder value.
Keep the actual manifests outside Git. The chart only renders references to these Secrets.
For the example below, the release name and namespace are both significant for the TimeFusion service hostname.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: monoscope-env
  namespace: observability
type: Opaque
stringData:
  DATABASE_URL: "postgresql://monoscope:URL_ENCODED_PASSWORD@db.example.invalid:5432/monoscope?sslmode=require"
  API_KEY_ENCRYPTION_SECRET_KEY: "REPLACE_WITH_32_ASCII_CHARACTERS!!"
  BASIC_AUTH_PASSWORD: "REPLACE_WITH_A_STRONG_PASSWORD"
  PGWIRE_PASSWORD: "REPLACE_WITH_A_DIFFERENT_STRONG_PASSWORD"
  TIMEFUSION_PG_URL: "postgresql://postgres:URL_ENCODED_PGWIRE_PASSWORD@monoscope-timefusion.observability.svc.cluster.local:5432/postgres?sslmode=disable"
---
apiVersion: v1
kind: Secret
metadata:
  name: monoscope-s3
  namespace: observability
type: Opaque
stringData:
  AWS_ACCESS_KEY_ID: "REPLACE_WITH_ACCESS_KEY"
  AWS_SECRET_ACCESS_KEY: "REPLACE_WITH_SECRET_KEY"
```

Use the same TimeFusion password in `PGWIRE_PASSWORD` and `TIMEFUSION_PG_URL`.
Percent-encode passwords in URLs. Use 32 ASCII characters for the API encryption key, such as the output of `openssl rand -hex 16`.
Keep this encryption key stable across upgrades. Changing it can make stored credentials and API keys unusable.
If you rename the release, set `fullnameOverride: monoscope` or update the TimeFusion hostname in the Secret.

The app uses Basic authentication with `basicAuthUsername`, which defaults to `admin`.
`extraEnv` accepts Kubernetes environment variable entries, including `valueFrom` references.
`extraEnvFrom` accepts standard Kubernetes Secret and ConfigMap references for optional SMTP, LLM, and other integrations.
Do not duplicate chart-managed environment variables through `extraEnv`.
Restart the affected workloads after changing Secrets because environment variables do not refresh in running containers.

## Install and connect

The [cluster example](examples/cluster-values.yaml) uses placeholder hostnames and Gateway references.
Replace the hostnames, S3 endpoint, bucket, Gateway name, namespace, and listener with your own values.
Make sure that the Gateway listener permits routes from the release namespace and provides certificates for your hostnames.
Create DNS records that point to your Gateway before installation.

Inspect the rendered configuration, then install when the database, bucket, Secrets, and DNS are ready:

```sh
helm lint charts/monoscope -f charts/monoscope/examples/cluster-values.yaml
helm template monoscope charts/monoscope -n observability -f charts/monoscope/examples/cluster-values.yaml
helm upgrade --install monoscope charts/monoscope -n observability \
  -f charts/monoscope/examples/cluster-values.yaml --wait --timeout 15m
```

`gateway.enabled` creates an HTTPRoute for the UI, API, and OTLP/HTTP traffic on port 8080.
For external OTLP/gRPC, enable `gateway.grpc.enabled` and configure a separate hostname, such as `otlp.example.invalid`.
The chart creates a GRPCRoute with an HTTP/2 cleartext backend on port 4317. Clients use TLS to the gateway on port 443.
For internal gRPC clients, use `monoscope.observability.svc.cluster.local:4317` with plaintext transport and the Monoscope project authentication headers.
Standard Ingress is also available through `ingress`, but its configuration covers HTTP only.

Both Services use `ipFamilyPolicy: SingleStack` and `ipFamilies: [IPv4]`.
This policy is fixed in the chart because the upstream listeners bind IPv4. No proxy sidecars or custom images are required.
Pods keep their cluster-assigned addresses. Kubernetes selects their IPv4 addresses for these Services.
The shared gateway can still accept IPv4 and IPv6 clients and forward requests to the IPv4 backends.
Health probes use loopback commands to avoid a probe against an unsupported IPv6 pod address.
TimeFusion's health command accepts its temporary startup response during WAL recovery. A ready pod alone does not prove SQL queries are ready.
Check a real authenticated query and telemetry ingestion after startup.

## Operation and validation

Both workloads use one replica and the `Recreate` update strategy. This prevents overlapping migrations, background jobs, and writers to the same WAL.
TimeFusion requires `io_uring`, which the standard container seccomp filter can block.
Its default container configuration uses `Unconfined` seccomp, drops all Linux capabilities, and runs as UID 65532.
If your cluster provides a compatible local seccomp profile, configure it through `timefusion.securityContext`.
The cluster must allow that security configuration. No privileged container is requested.

To use an external TimeFusion instance, set `timefusion.enabled=false` and point `TIMEFUSION_PG_URL` at it.
Configure the external service's bucket and credentials separately. The chart's S3 values still configure Monoscope replay storage.
The application reads and writes telemetry through TimeFusion. PostgreSQL still stores application state and migration-required tables.
SQL transport to chart-managed TimeFusion is plaintext inside the cluster. Keep its service internal and restrict network access according to your cluster policy.

The defaults pin publicly readable amd64 images by digest. Set `image.digest` and `timefusion.image.digest` when upgrading.
If you choose tags instead, clear the corresponding digest value. Changing a tag alone does not override a digest.
Resources are initial estimates, not workload measurements. Tune memory, CPU, WAL capacity, and startup time for your ingestion rate.
Back up PostgreSQL, the S3 bucket, and the WAL volume. The retained claim survives Helm uninstall and needs an explicit recovery plan on reinstall.

Run the local chart checks with:

```sh
bash charts/monoscope/tests/template_test.sh
```

Template checks cover secret references, S3 configuration, persistence, routes, external TimeFusion, and invalid configurations.
They do not prove that database migrations, S3 access, or telemetry ingestion work in your environment.

See [Monoscope](https://github.com/monoscope-tech/monoscope) and [TimeFusion](https://github.com/monoscope-tech/timefusion) for application documentation.
