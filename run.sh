#!/bin/sh

echo "this is the deal $MGP_API_URL"

docker run -it -p8080:80 -p8081:2019 -v $(pwd)/Caddyfile:/app/Caddyfile \
    -e MGP_API_URL=$MGP_API_URL \
    -e OSM_API_URL=$OSM_API_URL \
    ghcr.io/sillygod/cdp-cache/caddy:v0.5.0
