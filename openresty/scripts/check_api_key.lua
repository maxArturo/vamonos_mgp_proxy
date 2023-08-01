local api_key = ngx.req.get_headers()['X-Auth-Token']
if api_key ~= os.getenv("API_TOKEN") then
    -- ngx.log(ngx.ALERT, "api token is: ")
    -- ngx.log(ngx.ALERT, os.getenv("API_TOKEN"))
    ngx.exit(ngx.HTTP_UNAUTHORIZED)
end

-- clear headers here
headers = {'X-Forwarded-By', 'Via', 'Fly', 'X-Auth-Token', 'X-Build-Id', 'Cache-Congrol', 'pragma'}
for i, header in ipairs(headers) do
    ngx.req.clear_header(header)
end

