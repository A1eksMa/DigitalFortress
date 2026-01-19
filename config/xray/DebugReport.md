# Отчёт о диагностике Entry-ноды mimimi.pro

**Дата:** 2026-01-19 (обновлено)
**Статус:** ✅ gRPC транспорт работает | ⚠️ XHTTP/WebSocket блокируются DPI

---

## 1. Конфигурация сервера

### 1.1. Параметры инстанса

| Параметр | Значение |
|----------|----------|
| IP-адрес | 202.223.48.9 |
| Домен | mimimi.pro |
| ОС | Ubuntu 22.04 |
| Хостинг | ABLENET (Япония) |
| RAM | 1.5 GB |
| vCPU | 2 |

### 1.2. Версии ПО

| Компонент | Версия |
|-----------|--------|
| Xray-core | 26.1.18 (go1.25.6 linux/amd64) |
| Nginx | 1.18.0 (Ubuntu) |
| SSL | Let's Encrypt (действителен до 2026-04-18) |

### 1.3. Конфигурация Xray (`/usr/local/etc/xray/config.json`)

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

### 1.4. Конфигурация Nginx (`/etc/nginx/sites-enabled/mimimi.pro`)

```nginx
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
    location /api/v2/xhttp/de8556258953fcc5/ {
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }

    # WebSocket транспорт
    location /api/v2/stream/d4d34f819b478b12/ {
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }

    # gRPC транспорт
    location /api.v2.rpc.ed43dc57c52e69c0 {
        grpc_pass grpc://127.0.0.1:10003;
        grpc_set_header Host $host;
        grpc_set_header X-Real-IP $remote_addr;
        grpc_read_timeout 300s;
        grpc_send_timeout 300s;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }

    location ~* \.(svg|jpg|jpeg|png|gif|ico|css|js)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    access_log /var/log/nginx/mimimi.pro_access.log;
    error_log /var/log/nginx/mimimi.pro_error.log;
}

server {
    listen 80;
    listen [::]:80;
    server_name mimimi.pro;
    return 301 https://$host$request_uri;
}
```

---

## 2. Результаты диагностики

### 2.1. Статус сервисов

**Xray:**
```
● xray.service - Xray Service
     Loaded: loaded (/etc/systemd/system/xray.service; enabled)
     Active: active (running) since Sun 2026-01-18 13:53:32 UTC
   Main PID: 170494 (xray)
```

**Nginx:**
```
● nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/lib/systemd/system/nginx.service; enabled)
     Active: active (running) since Sun 2026-01-18 11:11:04 UTC
```

### 2.2. Проблема с systemd

**Выявлено:** Xray под пользователем `nobody` (systemd) запускается, но **не слушает на портах**.

```bash
$ sudo ss -tlnp | grep 127.0.0.1
# Пустой вывод при запуске через systemd
```

**Решение:** Запуск вручную от root работает корректно:
```bash
$ sudo /usr/local/bin/xray run -config /usr/local/etc/xray/config.json
# Xray слушает на портах 10001, 10002, 10003
```

```bash
$ sudo ss -tlnp | grep 127.0.0.1
LISTEN 0 4096 127.0.0.1:10001 0.0.0.0:* users:(("xray",pid=174076,fd=4))
LISTEN 0 4096 127.0.0.1:10002 0.0.0.0:* users:(("xray",pid=174076,fd=7))
LISTEN 0 4096 127.0.0.1:10003 0.0.0.0:* users:(("xray",pid=174076,fd=9))
```

### 2.3. Проверка SSL-сертификата

```bash
$ echo | openssl s_client -servername mimimi.pro -connect mimimi.pro:443 2>/dev/null | openssl x509 -noout -dates -subject
notBefore=Jan 18 10:18:16 2026 GMT
notAfter=Apr 18 10:18:15 2026 GMT
subject=CN = mimimi.pro
```

**Статус:** Сертификат валиден.

### 2.4. Проверка доступности XHTTP endpoint

```bash
$ curl -I https://mimimi.pro/api/v2/xhttp/de8556258953fcc5/
HTTP/2 400
server: nginx/1.18.0 (Ubuntu)
access-control-allow-methods: GET, POST
access-control-allow-origin: *
x-padding: XXXX...
```

**Статус:** Xray отвечает (400 — нормально для не-VLESS запроса).

---

## 3. Тестирование клиентского подключения

### 3.1. Клиент

| Параметр | Значение |
|----------|----------|
| Приложение | NekoBox (Android) |
| Местоположение | Россия |
| Сеть | Мобильный интернет |
| IP клиента | 178.216.218.134 |

### 3.2. VLESS-ссылка для XHTTP

```
vless://d2e5507d-e265-44ba-acc4-1356e4a6d70e@mimimi.pro:443?type=xhttp&security=tls&path=%2Fapi%2Fv2%2Fxhttp%2Fde8556258953fcc5%2F&fp=chrome&alpn=h2%2Chttp%2F1.1#Mimimi-XHTTP
```

### 3.3. Результат подключения

| Этап | Результат |
|------|-----------|
| TLS handshake | Успешно |
| Подключение к Xray | Успешно (клиент показывает "подключено") |
| Connectivity test | **ОШИБКА:** `net/http: HTTP/1.x transport connection broken: malformed HTTP response` |
| Открытие сайтов | **НЕ РАБОТАЕТ** |

### 3.4. Логи Nginx при подключении

Запросы доходят до сервера:

```
178.216.218.134 - - [18/Jan/2026:17:42:10 +0000] "GET /api/v2/xhttp/de8556258953fcc5/... HTTP/2.0" 200 0 "..." "Go-http-client/2.0"
178.216.218.134 - - [18/Jan/2026:17:42:10 +0000] "POST /api/v2/xhttp/de8556258953fcc5/... HTTP/2.0" 200 198 "..." "Go-http-client/2.0"
178.216.218.134 - - [18/Jan/2026:18:00:46 +0000] "POST /api/v2/xhttp/de8556258953fcc5/... HTTP/2.0" 200 542 "..." "Go-http-client/2.0"
```

**Статус:** HTTP 200, данные передаются (198, 542 байт).

### 3.5. Логи Xray

```
2026/01/18 17:59:59.581207 [Info] [1280929938] app/proxyman/inbound: connection ends > EOF
2026/01/18 18:00:16.013517 [Info] [3136560450] app/proxyman/inbound: connection ends > EOF
2026/01/18 18:00:19.597127 [Info] [3686560924] app/proxyman/inbound: connection ends > EOF
...
```

**Проблема:** Все соединения немедленно закрываются с `EOF` (End Of File).

---

## 4. Выявленные проблемы

### 4.1. Критическая проблема: Xray не работает через systemd

**Симптом:** При запуске через `systemctl start xray` процесс стартует, но не слушает на портах.

**Причина:** Вероятно, пользователь `nobody` не имеет прав на bind портов или конфликт с какими-то настройками.

**Workaround:** Запуск вручную от root.

**TODO:** Исправить systemd unit file.

### 4.2. Основная проблема: XHTTP соединения закрываются с EOF

**Симптом:**
- Клиент показывает "подключено"
- Nginx получает запросы и отвечает 200
- Xray получает соединения, но они сразу закрываются (`connection ends > EOF`)
- Трафик не проходит, сайты не открываются

**Возможные причины:**

1. **Несовместимость версий XHTTP** между Xray 26.1.18 на сервере и клиентом NekoBox
2. **Проблема с конфигурацией Nginx** для XHTTP (возможно нужны дополнительные заголовки)
3. **Проблема с режимом XHTTP** (может потребоваться настройка `mode` в xhttpSettings)

### 4.3. Предупреждения Xray

При запуске Xray выдаёт предупреждения:

```
[Warning] This feature VLESS without flow is deprecated and being migrated to VLESS with flow.
[Warning] This feature WebSocket transport is deprecated and being migrated to XHTTP H2 & H3.
[Warning] This feature gRPC transport is deprecated and being migrated to XHTTP stream-up H2.
```

**Вывод:** Xray 26.x активно мигрирует на XHTTP, старые транспорты помечены как deprecated.

---

## 5. Рекомендации по решению

### 5.1. Попробовать обновить клиент

Проверить версию NekoBox и обновить до последней. XHTTP — относительно новый транспорт, требует свежих версий клиентов.

**Рекомендуемые клиенты с поддержкой XHTTP:**
- NekoBox (последняя версия)
- v2rayN 6.x+
- v2rayNG 1.8.x+

### 5.2. Установить клиент на сервер для теста

Установить Xray-клиент на этом же сервере и протестировать локальное подключение:

```bash
# Создать клиентский конфиг
# Подключиться к 127.0.0.1 (обойдя Nginx) или к mimimi.pro
# Это покажет, проблема в клиенте или в сервере
```

### 5.3. Изменить настройки XHTTP

Попробовать добавить `mode` в xhttpSettings:

```json
"xhttpSettings": {
  "path": "/api/v2/xhttp/de8556258953fcc5/",
  "mode": "auto"
}
```

Или попробовать режимы: `"packet-up"`, `"stream-up"`, `"stream-one"`.

### 5.4. Проверить конфигурацию Nginx для XHTTP

Возможно требуются дополнительные настройки:

```nginx
location /api/v2/xhttp/de8556258953fcc5/ {
    proxy_pass http://127.0.0.1:10001;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_buffering off;
    proxy_request_buffering off;
    proxy_read_timeout 300s;
    proxy_send_timeout 300s;
}
```

### 5.5. Если XHTTP не заработает — использовать WebSocket

WebSocket-ссылка для резервного варианта:

```
vless://d2e5507d-e265-44ba-acc4-1356e4a6d70e@mimimi.pro:443?type=ws&security=tls&path=%2Fapi%2Fv2%2Fstream%2Fd4d34f819b478b12%2F&sni=mimimi.pro&fp=chrome&alpn=h2%2Chttp%2F1.1#Mimimi-WS
```

### 5.6. Исправить systemd

Изменить `/etc/systemd/system/xray.service`:
- Заменить `User=nobody` на `User=root` или создать специального пользователя `xray`
- Выполнить `systemctl daemon-reload && systemctl restart xray`

---

## 6. Следующие шаги

1. [ ] Обновить клиент NekoBox до последней версии
2. [ ] Установить Xray-клиент на сервер и протестировать локально
3. [ ] Попробовать разные режимы XHTTP (`mode`: auto, packet-up, stream-up)
4. [ ] Добавить `proxy_buffering off` в Nginx
5. [ ] Если не поможет — тестировать WebSocket
6. [ ] Исправить systemd unit для автозапуска

---

## 7. Полезные команды для диагностики

```bash
# Статус сервисов
sudo systemctl status xray
sudo systemctl status nginx

# Порты Xray
sudo ss -tlnp | grep 127.0.0.1

# Логи Xray
sudo tail -f /var/log/xray/error.log

# Логи Nginx
sudo tail -f /var/log/nginx/mimimi.pro_access.log

# Тест endpoint
curl -I https://mimimi.pro/api/v2/xhttp/de8556258953fcc5/

# Проверка SSL
echo | openssl s_client -servername mimimi.pro -connect mimimi.pro:443 2>/dev/null | openssl x509 -noout -dates
```

---

---

## 8. Итоги тестирования (2026-01-19)

### 8.1. Статус транспортов

| Транспорт | Из открытого интернета | Из регулируемой сети (РФ) |
|-----------|------------------------|---------------------------|
| **gRPC** | ✅ Работает | ✅ Работает |
| XHTTP | ✅ Работает | ❌ Блокируется DPI |
| WebSocket | ✅ Работает | ❌ Блокируется DPI |

**Вывод:** gRPC — единственный жизнеспособный транспорт для пользователей из регулируемых сетей.

### 8.2. Тестирование клиентов

| Клиент | Платформа | Результат |
|--------|-----------|-----------|
| **v2rayNG** | Android | ✅ Успешное подключение |
| NekoBox (последняя версия) | Android | ❌ Не удалось установить соединение |

**Рекомендация:** Использовать v2rayNG для Android-устройств.

### 8.3. Проблема с тестами подключения

Встроенные тесты в клиентах (Real Delay Test, Connectivity Test) **всегда показывают отрицательный результат**, даже когда VPN работает корректно.

**Причина:** Адреса, используемые для тестирования (gstatic.com, cloudflare.com и др.), заблокированы регулятором.

**Решение:** Игнорировать результаты встроенных тестов. Проверять работоспособность VPN открытием сайтов в браузере.

### 8.4. Проблема с systemd — решена

**Проблема:** Xray при запуске через systemd не биндился к портам.

**Причина:** Пользователь `nobody` не имел прав записи в `/var/log/xray/`.

**Решение:** Настройка прав доступа на директорию логов:

```bash
sudo chown -R nobody:nogroup /var/log/xray
sudo chmod 755 /var/log/xray
sudo systemctl restart xray
```

Подробности — см. документацию `docs/entry-node/05-xray-install.md`, раздел 8.2.

### 8.5. Рабочая конфигурация клиента

**VLESS gRPC (рекомендуется):**

```
vless://d2e5507d-e265-44ba-acc4-1356e4a6d70e@mimimi.pro:443?type=grpc&security=tls&serviceName=api.v2.rpc.ed43dc57c52e69c0&sni=mimimi.pro&alpn=h2&fp=chrome#Mimimi-gRPC
```

---

*Отчёт обновлён: 2026-01-19*
