server {

root /var/www/mimimi.pro/html;
index index.html index.htm;

server_name mimimi.pro;

location / {
try_files $uri $uri/ =404;
}

location /shell/ {
    proxy_pass http://localhost:4200/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}


    listen [::]:443 ssl ipv6only=on; # managed by Certbot
    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/mimimi.pro/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/mimimi.pro/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot

}
server {
    if ($host = mimimi.pro) {
        return 301 https://$host$request_uri;
    } # managed by Certbot


listen 80 default_server;
listen [::]:80 default_server;

server_name mimimi.pro;
    return 404; # managed by Certbot


}
