# Blocky

Blocky filters DNS with blocklists that refresh every four hours. The chart uses Init7's IPv6 DNS-over-TLS resolvers and enables DNSSEC validation in Blocky. Init7 restricts its resolvers to customers. Set `upstreams.groups.default` to reachable resolvers when you deploy outside Init7's network.

The cache uses the upstream TTL with a one-hour ceiling and holds up to 10,000 entries. Set `caching` and `blocking` in your values file to change the cache policy, lists, or client groups.

The default Service provides plain DNS inside the cluster. It uses the cluster's preferred IP family and requests a second family when available. Set `service.ipFamilyPolicy` and `service.ipFamilies` to select a specific family.

## DoH and HTTP/3

For a shared Gateway, attach the chart's HTTPRoute to its HTTPS listener. The route exposes `/dns-query` and its client-ID paths. The Gateway must terminate QUIC and publish UDP port 443 to serve HTTP/3. An Envoy Gateway can enable this with a [ClientTrafficPolicy](https://gateway.envoyproxy.io/v1.10/tasks/traffic/http3/). On an IPv6-primary dual-stack cluster, set the EnvoyProxy's `spec.ipFamily` to `DualStack`.

```yaml
gateway:
  enabled: true
  parentRefs:
    - name: shared-https
      namespace: gateway-system
      sectionName: https
  hostnames:
    - dns.example.net
```

When TCP and QUIC reach separate Gateways on the same public address, list both listeners under `gateway.parentRefs`. Use the same hostname and a valid certificate on both Gateways. After you test public QUIC on port 443, set `gateway.advertiseHTTP3: true` to advertise it on TCP DoH responses.

For native HTTP/3, set `nativeDoH.enabled: true` and supply `nativeDoH.tlsSecretName`. Use a `kubernetes.io/tls` Secret in the release namespace. The native Service carries TLS on TCP and QUIC on UDP, both on port 443. Set `nativeDoH.service.type: LoadBalancer` to expose that Service to the CIDRs in `nativeDoH.service.loadBalancerSourceRanges`. The native listener also serves Blocky's management endpoints. Limit access to a trusted network and use a path-filtering Gateway for a public DoH endpoint.

Test the selected endpoint with a curl build that supports HTTP/3. This query asks for the A record of `example.com`.

```sh
curl --http3-only --fail --silent --show-error \
  -H 'Accept: application/dns-message' \
  -o /dev/null -w 'HTTP/%{http_version}\n' \
  'https://dns.example.net/dns-query/iphone?dns=AAABAAABAAAAAAAAB2V4YW1wbGUDY29tAAABAAE'
```

## iOS client IDs and query log retention

Set a device's DNS Settings profile to HTTPS. Set `ServerURL` to a URL such as `https://dns.example.net/dns-query/iphone`. Blocky records `iphone` in the client name field. Choose a distinct path segment for each device. A client can choose its own ID, so use the ID as a log label.

SQLite keeps seven days of query logs by default. The chart records the client name, question, and response reason. It skips special-use domain queries. Set `queryLog.ignore.domains` or `queryLog.ignore.clients` to omit other high-volume traffic. A resolver cache hit can still produce a log row.

SQLite uses WAL and one replica on a local `ReadWriteOnce` volume. Use a local filesystem and set `queryLog.sqlite.storageClassName` or `queryLog.sqlite.existingClaim`. The chart keeps its PVC after uninstall. Retention deletes old rows, but the SQLite file can retain space for reuse.

For PostgreSQL or TimescaleDB, create a Secret whose `dsn` key contains the connection string. Set `queryLog.type` to `postgresql` or `timescale` and set `queryLog.databaseSecret.name` to the Secret name. Enable the TimescaleDB extension in the target database before using `timescale`. Blocky creates a hypertable and retention policy in this mode. With PostgreSQL, Blocky deletes old rows on its retention schedule.

Each backend stores one row per logged query. Batching reduces write overhead. A TimescaleDB retention policy removes old chunks, and a continuous aggregate can summarize rows by time, client, and domain. Blocky does not create aggregates or deduplicate repeated queries. A storage limit needs separate monitoring because retention bounds age.

[Blocky v0.37.0 configuration](https://github.com/0xERR0R/blocky/blob/v0.37.0/docs/config.yml) · [Blocky database writer](https://github.com/0xERR0R/blocky/blob/v0.37.0/querylog/database_writer.go) · [Apple DNS settings](https://developer.apple.com/documentation/devicemanagement/networkdnssettings)
