metric_requests:inc(1, {ngx.var.upstream_provider, ngx.var.status, ngx.var.upstream_cache_status})
metric_latency:observe(tonumber(ngx.var.request_time), {ngx.var.upstream_provider})
