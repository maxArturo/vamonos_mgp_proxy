FROM openresty/openresty:1.21.4.2-0-alpine-apk

# Add the configuration file
RUN rm /etc/nginx/conf.d/*
RUN mkdir -p /var/cache/nginx/main_cache

COPY nginx.conf /usr/local/openresty/nginx/conf
COPY default.conf /etc/nginx/conf.d/default.conf
COPY scripts /scripts
