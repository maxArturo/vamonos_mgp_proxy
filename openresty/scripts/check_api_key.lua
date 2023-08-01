local function isempty(s)
    return s == nil or s == ''
end

local api_key = ngx.req.get_headers()['X-Auth-Token']
local build_id = ngx.req.get_headers()['X-Build-Id']
if api_key ~= os.getenv("API_TOKEN") or isempty(build_id) then
    ngx.exit(ngx.HTTP_UNAUTHORIZED)
end

-- make sure to log the build ids
metric_build_id:inc(1, {ngx.req.get_headers()['X-Build-Id'], ngx.var.upstream_provider})

-- clear headers here
headers = {'X-Forwarded-By', 'Via', 'Fly', 'X-Auth-Token', 'X-Build-Id', 'Cache-Congrol', 'pragma'}
for i, header in ipairs(headers) do
    ngx.req.clear_header(header)
end

