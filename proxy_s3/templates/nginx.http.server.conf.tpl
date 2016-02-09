server {
    listen       80;
    client_max_body_size {{ proxy_s3_nginx_client_max_body_size }};
    server_name  localhost;

    error_page   404              /404.html;
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   html;
    }

    location / {
        set_by_lua $orgn '
            local origin = ngx.req.get_headers()["origin"]
            if origin == nil then
                origin = "*"
            end
            return origin
        ';

        rewrite_by_lua '
            local dir, file, param = string.match(ngx.var.request_uri, "(.*/)([^?]*)(%??.*)")
            if file == "" then
                ngx.req.set_uri(dir .. "index.html", false)
            end
        ';

        access_by_lua '
            if ngx.var.remote_user == "smallfish" and ngx.var.remote_passwd == "12" then
                return
            end
            ngx.header.www_authenticate = [[Basic realm="Restricted"]]
            ngx.exit(401)
        ';


        set $s3_bucket "{{ proxy_s3_bucket }}.s3-{{ proxy_s3_region }}.amazonaws.com";

        proxy_http_version     1.1;
        proxy_set_header       Host $s3_bucket;
        proxy_set_header       Authorization "";
        proxy_set_header       Cookie "";

        proxy_hide_header Access-Control-Allow-Methods;
        proxy_hide_header Access-Control-Allow-Origin;

        add_header Access-Control-Allow-Origin $orgn;
        add_header Access-Control-Allow-Methods "GET, OPTIONS";
        add_header Access-Control-Allow-Headers "Origin, Authorization, Accept";
        add_header Access-Control-Allow-Credentials true;

        proxy_pass https://$s3_bucket;

        # auth_basic "Restricted";
        # auth_basic_user_file "{{ proxy_s3_nginx_sub_conf_directory }}/{{ proxy_s3_htpassword_file_name }}";

        if ($request_method = OPTIONS ) {
            add_header Access-Control-Allow-Origin *;
            add_header Access-Control-Allow-Methods "GET, OPTIONS";
            add_header Access-Control-Allow-Headers "Origin, Authorization, Accept";
            add_header Access-Control-Allow-Credentials true;
            return 200;
        }
    }
}