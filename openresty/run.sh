#!/bin/bash

docker build -t proxy .

# shellcheck source=/dev/null
source .env

docker run -p8080:80 \
    -p9091:9091 \
    -e MGP_API_URL="$MGP_API_URL" \
    -e OSM_API_URL="$OSM_API_URL" \
    -e HOST_URL="$HOST_URL" \
    -e API_TOKEN="$API_TOKEN" \
    proxy
