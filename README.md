# vamonos-mgp-proxy

A small caching reverse proxy that sits between the [vamonos_mgp](https://github.com/maxArturo/vamonos_mgp)
Flutter app and the upstream services it depends on.

The app shows public transit arrival times for Mar del Plata, Argentina. Its two upstreams — the
Municipio de General Pueyrredón transit API and the OpenStreetMap tile server — are both services
that should not be hit directly by every client on every screen refresh. This proxy fronts them so
that many app instances asking the same question collapse into a single upstream request.

## What it does

- **Caches responses**, including `POST` bodies, so repeated lookups for the same stop or route are
  served from memory rather than forwarded upstream.
- **Collapses concurrent requests** — when several clients ask for the same uncached resource, the
  first request populates the cache while the rest wait on it, instead of stampeding the upstream.
- **Serves stale content on upstream errors**, so a flaky or briefly-down upstream degrades into
  slightly old data rather than a failure.
- **Gates access with a shared token**, so the deployment isn't an open relay for anyone who finds
  the URL.
- **Exports Prometheus metrics**, including a per-build-ID request counter for tracking which app
  versions are live.

## Routes

| Route | Upstream | Cache TTL |
|---|---|---|
| `/providers/mgp/*` | `https://appsl.mardelplata.gob.ar` | 1 minute |
| `/map_tiles/osm/*` | `https://tile.openstreetmap.org` | 7 days |
| `/metrics` (port `9091`) | — | not cached |

The route prefix is stripped before forwarding, so `/providers/mgp/app_cuando_llega/webWS.php`
reaches the upstream as `/app_cuando_llega/webWS.php`.

Arrival data is only useful while it's fresh, hence the one-minute TTL; map tiles effectively never
change, so they're held for a week.

Responses carry an `X-Vamonos-Mgp-Cache-Status` header (`HIT`, `MISS`, `EXPIRED`, …) to make cache
behaviour visible from the client.

## Authentication

Every proxied request must send both headers:

| Header | Meaning |
|---|---|
| `X-Auth-Token` | Must equal the `API_TOKEN` the proxy was deployed with. |
| `X-Build-Id` | Identifier for the calling app build. Must be non-empty; recorded as a metric label. |

A request missing or mismatching either header gets a `401` and is never forwarded upstream.

Both headers — along with `X-Forwarded-*`, `Via`, `Fly-*`, `Cache-Control` and `Pragma` — are
stripped before the request reaches the upstream, so the token never leaves the proxy and the
upstream sees a clean request.

This is a shared secret for keeping casual traffic out, not a per-user auth system. Anyone holding
the token can use the proxy.

## Caching POST requests

The transit API is driven by form-encoded `POST` bodies, so caching on URL alone would be useless —
every lookup hits the same path. The proxy instead builds its cache key from the request body:

```
$proxy_host$request_uri$cache_body_key
```

where `cache_body_key` is an MD5 of the request body (falling back to the buffered body file, then
to the path, when the body isn't available in memory). Two clients requesting arrivals for the same
bus line therefore share a cache entry, while different lines stay separate.

## Layout

```
openresty/            # current implementation — OpenResty (nginx + Lua)
  nginx.conf          #   top-level config, Prometheus setup, env passthrough
  default.conf        #   server blocks, routes, cache and proxy rules
  scripts/
    check_api_key.lua #   auth + build-ID metric + inbound header scrubbing
    log_metrics.lua   #   per-request counters and latency histogram
  test_requests.http  #   sample requests for manual testing
  fly.toml            #   Fly.io deployment config
  Dockerfile
  run.sh              #   build and run locally

Caddyfile             # earlier Caddy-based implementation, kept for reference
Dockerfile            #
fly.toml              #
run.sh                #
```

The OpenResty setup under `openresty/` is what's deployed. The Caddy configuration at the repo root
is the previous implementation, superseded because caching `POST` bodies and exporting custom
metrics were both easier to express in Lua.

## Configuration

All configuration is by environment variable:

| Variable | Purpose |
|---|---|
| `API_TOKEN` | Shared secret clients must send as `X-Auth-Token`. |
| `MGP_API_URL` | Transit API upstream. |
| `OSM_API_URL` | Tile server upstream. |
| `HOST_URL` | Public URL the proxy answers on. |

## Running locally

```sh
cd openresty
cp ../.env.sample .env    # then edit: set API_TOKEN to any value you like
./run.sh
```

This builds the image and runs it with the proxy on `localhost:8080` and metrics on
`localhost:9091`. `.env` is gitignored — keep real tokens out of the repo.

To send a request:

```sh
curl -X POST http://localhost:8080/providers/mgp/app_cuando_llega/webWS.php \
  -H "X-Auth-Token: $API_TOKEN" \
  -H "X-Build-Id: local-dev" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d 'accion=RecuperarParadasConBanderaYDestinoPorLinea&codLinea=93&isSublinea=0' \
  -i
```

Check `X-Vamonos-Mgp-Cache-Status` in the response — the first call should report `MISS` and the
next one `HIT`. `openresty/test_requests.http` holds the same request in a format editors with an
HTTP client can run directly.

## Deploying

Deployment targets [Fly.io](https://fly.io):

```sh
cd openresty
fly secrets set API_TOKEN=<your-token>
fly deploy
```

`MGP_API_URL`, `OSM_API_URL` and `HOST_URL` are set in `fly.toml` under `[env]`. `API_TOKEN` is
deliberately not — set it as a secret so it stays out of version control.

## Metrics

Prometheus metrics are exposed on port `9091` at `/metrics`, on a separate `server` block from the
proxy so they aren't publicly routed by the Fly service definition:

| Metric | Type | Labels |
|---|---|---|
| `nginx_http_requests_total` | counter | `provider`, `status`, `cache` |
| `nginx_http_requests_by_build_id` | counter | `build_id`, `provider` |
| `nginx_http_request_duration_seconds` | histogram | `provider` |
| `nginx_http_connections` | gauge | `state` |

The `cache` label on `nginx_http_requests_total` carries the upstream cache status, which makes hit
rate per provider directly queryable.
