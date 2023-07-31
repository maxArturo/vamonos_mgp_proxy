#!/bin/bash

docker build -t test .

# shellcheck source=/dev/null
source .env

docker run -it -p8080:8080 \
    -p2019:2019 \
    -e MGP_API_URL="$MGP_API_URL" \
    -e OSM_API_URL="$OSM_API_URL" \
    -e HOST_URL="$HOST_URL" \
    -e API_TOKEN="$API_TOKEN" \
    test
