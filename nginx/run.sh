#!/bin/bash

docker build -t proxy -f openresty.Dockerfile .

docker run -p8080:80 \
    proxy
