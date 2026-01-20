# Конфигурация Nginx для Entry-ноды (Россия)
# Протестировано: 2026-01-19
# Статус: gRPC и WebSocket работают, XHTTP блокируется DPI

# КРИТИЧНО: map директива для корректной работы WebSocket через HTTP/2
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name mimimi.pro;

    ssl_certificate /etc/letsencrypt/live/mimimi.pro/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/mimimi.pro/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    root /var/www/mimimi.pro/html;
    index index.html;

    # XHTTP транспорт
    # Примечание: блокируется DPI в регулируемых сетях
    location /api/v2/xhttp/RANDOM_PATH/ {
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Connection "";
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
        proxy_buffering off;
        chunked_transfer_encoding on;
    }

    # WebSocket транспорт
    # Работает внутри регулируемого контура
    location /api/v2/stream/RANDOM_PATH/ {
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
        proxy_buffering off;
    }

    # gRPC транспорт
    # Рекомендуется как основной — работает везде
    location /api.v2.rpc.RANDOM_PATH {
        grpc_pass grpc://127.0.0.1:10003;
        grpc_set_header Host $host;
        grpc_set_header X-Real-IP $remote_addr;
        grpc_read_timeout 300s;
        grpc_send_timeout 300s;
    }

    # Сайт-прикрытие
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Кэширование статики
    location ~* \.(svg|jpg|jpeg|png|gif|ico|css|js)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    access_log /var/log/nginx/mimimi.pro_access.log;
    error_log /var/log/nginx/mimimi.pro_error.log;
}

# HTTP → HTTPS редирект
server {
    listen 80;
    listen [::]:80;
    server_name mimimi.pro;
    return 301 https://$host$request_uri;
}
