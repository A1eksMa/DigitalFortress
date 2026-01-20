# Конфигурация Entry-ноды (Россия)

**Версия:** 1.0
**Дата:** 2026-01-19
**Статус:** Этап 1 (MVP) — тестовая нода в регулируемом контуре

---

## 1. Назначение

Тестовая Entry-нода, развёрнутая **внутри регулируемого контура** (территория РФ) для проверки работоспособности транспортов при подключении из регулируемых сетей.

---

## 2. Характеристики инстанса

### 2.1. Основные параметры

| Параметр | Значение |
|----------|----------|
| Hostname | leto |
| IP-адрес | 94.232.46.43 |
| Домен | mimimi.pro |
| ОС | Debian 12 |
| Расположение | Россия |

### 2.2. Версии ПО

| Компонент | Версия |
|-----------|--------|
| Xray-core | 26.1.18 (go1.25.6 linux/amd64) |
| Nginx | 1.18.0 |
| SSL | Let's Encrypt (до 2026-04-19) |

---

## 3. Конфигурация

### 3.1. Xray (`/usr/local/etc/xray/config.json`)

```json
{
  "log": {
    "loglevel": "debug",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "inbounds": [
    {
      "tag": "vless-xhttp",
      "listen": "127.0.0.1",
      "port": 10001,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "d2e5507d-e265-44ba-acc4-1356e4a6d70e",
            "level": 0
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "xhttp",
        "xhttpSettings": {
          "path": "/api/v2/xhttp/de8556258953fcc5/"
        }
      }
    },
    {
      "tag": "vless-ws",
      "listen": "127.0.0.1",
      "port": 10002,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "d2e5507d-e265-44ba-acc4-1356e4a6d70e",
            "level": 0
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/api/v2/stream/d4d34f819b478b12/"
        }
      }
    },
    {
      "tag": "vless-grpc",
      "listen": "127.0.0.1",
      "port": 10003,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "d2e5507d-e265-44ba-acc4-1356e4a6d70e",
            "level": 0
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": {
          "serviceName": "api.v2.rpc.ed43dc57c52e69c0"
        }
      }
    }
  ],
  "outbounds": [
    {
      "tag": "direct",
      "protocol": "freedom",
      "settings": {}
    },
    {
      "tag": "block",
      "protocol": "blackhole",
      "settings": {}
    }
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {
        "type": "field",
        "ip": ["geoip:private"],
        "outboundTag": "block"
      }
    ]
  }
}
```

### 3.2. Nginx (`/etc/nginx/sites-enabled/mimimi.pro`)

```nginx
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
```

**Важно:** Для WebSocket обязательна директива `map $http_upgrade $connection_upgrade` в начале файла.

---

## 4. Результаты тестирования

### 4.1. Статус транспортов

| Транспорт | Сервер | Из регулируемой сети | Примечание |
|-----------|--------|---------------------|------------|
| **gRPC** | ✅ OK | ✅ Работает | Рекомендуется |
| **WebSocket** | ✅ OK | ✅ Работает | После исправления Nginx |
| **XHTTP** | ✅ OK | ❌ Блокируется DPI | Запросы доходят, но DPI разрывает соединение |

### 4.2. Анализ блокировки XHTTP

**Симптомы:**
- Запросы XHTTP доходят до сервера (видны в access.log с кодом 200)
- Xray получает соединения, но они сразу закрываются
- Логи показывают: `packet queue closed`, `connection ends > EOF`

**Причина:** DPI распознаёт характерный паттерн XHTTP (splithttp):
- Множественные HTTP-запросы с UUID в URL
- Параметры `x_padding=XXX...`
- Чередование GET/POST запросов

**Подтверждение:** Запрос с localhost (минуя DPI) работает корректно:
```bash
curl -sv -X POST "https://mimimi.pro/api/v2/xhttp/PATH/test"
# Возвращает HTTP 400 + x-padding (нормальный ответ Xray)
```

---

## 5. Исправления, внесённые во время настройки

### 5.1. Плейсхолдеры в конфиге Xray

**Проблема:** В конфиге остались плейсхолдеры вместо реальных значений.

**Решение:** Заменить `ВАШ-UUID-ЗДЕСЬ` и `ВАШ-СЛУЧАЙНЫЙ-ПУТЬ` на сгенерированные значения.

### 5.2. WebSocket не подключается

**Проблема:** Заголовок `Upgrade` не передавался корректно при HTTP/2.

**Причина:** Переменная `$http_upgrade` пуста при HTTP/2, а `Connection "upgrade"` — статическая строка.

**Решение:** Добавить `map` директиву:
```nginx
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}
```

И использовать в location:
```nginx
proxy_set_header Connection $connection_upgrade;
```

---

## 6. Рекомендации

1. **Для регулируемых сетей:** использовать gRPC и WebSocket
2. **XHTTP:** оставить для подключений из открытого интернета
3. **Мониторинг:** периодически проверять работоспособность транспортов, так как DPI может адаптироваться

---

## 7. Полезные команды

```bash
# Статус сервисов
systemctl status xray nginx

# Порты Xray
ss -tlnp | grep xray

# Логи
tail -f /var/log/xray/error.log
tail -f /var/log/nginx/mimimi.pro_error.log

# Тест endpoint
curl -I https://mimimi.pro/api/v2/xhttp/PATH/

# Проверка SSL
echo | openssl s_client -servername mimimi.pro -connect mimimi.pro:443 2>/dev/null | openssl x509 -noout -dates
```

---

*Документ создан: 2026-01-19*
