# Конфигурация Core-ноды (Япония)

**Версия:** 1.0
**Дата:** 2026-01-20
**Статус:** Этап 2 — Активна

---

## 1. Характеристики инстанса

### 1.1. Основные параметры

| Параметр | Значение |
|----------|----------|
| Hostname | core-01 |
| IP-адрес | 45.63.121.41 |
| Расположение | Япония |
| Роль | Core-нода (маршрутизация в интернет) |

### 1.2. Версии ПО

| Компонент | Версия |
|-----------|--------|
| Xray-core | 26.1.18 (go1.25.6 linux/amd64) |
| Nginx | 1.22.1 |
| SSL | Самоподписанный (до 2027-01-20) |

---

## 2. Конфигурация

### 2.1. Сертификат

| Параметр | Значение |
|----------|----------|
| Тип | Самоподписанный |
| Путь | `/etc/ssl/core/core.crt` |
| Ключ | `/etc/ssl/core/core.key` |
| Срок действия | 2026-01-20 — 2027-01-20 |
| CN | 45.63.121.41 |
| SAN | IP:45.63.121.41 |

### 2.2. Nginx (`/etc/nginx/sites-available/core`)

```nginx
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name 45.63.121.41;

    ssl_certificate /etc/ssl/core/core.crt;
    ssl_certificate_key /etc/ssl/core/core.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    root /var/www/core/html;
    index index.html;

    # WebSocket от Entry-ноды
    location /api/v2/stream/42f6ebda8e293614/ {
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
        proxy_buffering off;
    }

    # Сайт-прикрытие
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

### 2.3. Xray (`/usr/local/etc/xray/config.json`)

```json
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "inbounds": [
    {
      "tag": "entry-ws",
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
        "network": "ws",
        "wsSettings": {
          "path": "/api/v2/stream/42f6ebda8e293614/"
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

---

## 3. Параметры туннеля

| Параметр | Значение |
|----------|----------|
| Протокол | VLESS |
| Транспорт | WebSocket |
| Порт | 443 |
| TLS | Самоподписанный |
| Путь | `/api/v2/stream/42f6ebda8e293614/` |
| UUID | `d2e5507d-e265-44ba-acc4-1356e4a6d70e` |

---

## 4. Результаты тестирования

### 4.1. Дата тестирования

2026-01-20

### 4.2. Тесты Core-ноды

| Тест | Результат | Примечание |
|------|-----------|------------|
| HTTPS (сайт-прикрытие) | ✅ 200 | `curl -k https://45.63.121.41/` |
| WebSocket путь | ✅ Проксируется | Nginx → Xray:10001 |
| Xray статус | ✅ active (running) | `systemctl status xray` |
| Порт 10001 | ✅ LISTEN | `127.0.0.1:10001` |

### 4.3. Тесты связи Entry → Core

| Тест | Результат | Примечание |
|------|-----------|------------|
| Сетевая доступность | ✅ OK | Entry-нода достигает Core-ноду |
| HTTPS запрос | ✅ 200 | `curl -k https://45.63.121.41/` с Entry-ноды |
| Логи Nginx | ✅ Запросы видны | IP 94.232.46.43 в логах |

### 4.4. Конфигурация Entry-ноды

Entry-нода (leto-ru, 94.232.46.43) обновлена:
- Добавлен outbound `to-core` (VLESS + WS + TLS)
- Routing rule направляет весь клиентский трафик на Core-ноду

---

## 5. Схема работы

```
Клиент (РФ)
    │
    │ VLESS + gRPC/WS + TLS (Let's Encrypt)
    │ mimimi.pro:443
    ▼
Entry-нода (94.232.46.43, РФ)
    │
    │ VLESS + WS + TLS (самоподписанный)
    │ 45.63.121.41:443
    │ /api/v2/stream/42f6ebda8e293614/
    ▼
Core-нода (45.63.121.41, Япония)
    │
    │ freedom
    ▼
Интернет
```

---

## 6. Полезные команды

```bash
# Статус сервисов
systemctl status xray nginx

# Порты
ss -tlnp | grep -E "(xray|nginx)"

# Логи
tail -f /var/log/xray/error.log
tail -f /var/log/nginx/core_access.log

# Проверка сертификата
openssl x509 -in /etc/ssl/core/core.crt -noout -dates

# Тест HTTPS
curl -k https://45.63.121.41/
```

---

## 7. Следующие шаги

- [ ] Тестирование клиентом (v2rayNG/NekoRay)
- [ ] Проверка IP через VPN (должен быть 45.63.121.41)
- [ ] Мониторинг логов при реальном использовании

---

*Документ создан: 2026-01-20*
