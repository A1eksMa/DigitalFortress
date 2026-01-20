# Обновление конфигурации Entry-ноды

**Статус:** Этап 2

---

## 1. Введение

После настройки Core-ноды необходимо обновить конфигурацию Entry-ноды, чтобы трафик шёл через Core-ноду, а не напрямую в интернет.

### Изменение схемы

**Было (этап 1):**
```
Клиент → Entry-нода → freedom → Интернет
```

**Стало (этап 2):**
```
Клиент → Entry-нода → Core-нода → Интернет
```

---

## 2. Подготовка

### 2.1. Необходимые данные

Перед началом убедитесь, что у вас есть:

| Параметр | Значение | Откуда |
|----------|----------|--------|
| IP Core-ноды | `45.63.121.41` | Документация |
| Порт | `443` | Стандартный HTTPS |
| UUID | `d2e5507d-e265-44ba-acc4-1356e4a6d70e` | Существующий |
| Путь WebSocket | `/api/v2/stream/{ваш_путь}/` | Из настройки Core-ноды |

### 2.2. Проверка доступности Core-ноды

```bash
# С Entry-ноды (leto-ru)
curl -k https://45.63.121.41/

# Должен вернуть HTML сайта-прикрытия
```

---

## 3. Обновление конфигурации Xray

### 3.1. Резервное копирование

```bash
# На Entry-ноде (leto-ru)
cp /usr/local/etc/xray/config.json /usr/local/etc/xray/config.json.backup
```

### 3.2. Новая конфигурация

```bash
nano /usr/local/etc/xray/config.json
```

**Полная конфигурация:**

```json
{
  "log": {
    "loglevel": "warning",
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
      "tag": "to-core",
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "45.63.121.41",
            "port": 443,
            "users": [
              {
                "id": "d2e5507d-e265-44ba-acc4-1356e4a6d70e",
                "level": 0
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "allowInsecure": true,
          "serverName": "45.63.121.41"
        },
        "wsSettings": {
          "path": "/api/v2/stream/ЗАМЕНИТЕ_НА_ПУТЬ_CORE_НОДЫ/"
        }
      }
    },
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
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "block"
      },
      {
        "type": "field",
        "inboundTag": [
          "vless-xhttp",
          "vless-ws",
          "vless-grpc"
        ],
        "outboundTag": "to-core"
      }
    ]
  }
}
```

### 3.3. Ключевые изменения

| Раздел | Было | Стало |
|--------|------|-------|
| `outbounds[0]` | `direct` (freedom) | `to-core` (VLESS к Core-ноде) |
| `routing.rules` | Только блокировка private IP | + маршрут всех inbound на `to-core` |

### 3.4. Замена плейсхолдера

Замените `ЗАМЕНИТЕ_НА_ПУТЬ_CORE_НОДЫ` на путь, настроенный на Core-ноде.

**Пример:**
```json
"path": "/api/v2/stream/a1b2c3d4e5f67890/"
```

---

## 4. Проверка и применение

### 4.1. Проверка синтаксиса

```bash
xray run -test -config /usr/local/etc/xray/config.json
```

**Ожидаемый вывод:** `Configuration OK.`

### 4.2. Перезапуск Xray

```bash
systemctl restart xray
systemctl status xray
```

---

## 5. Тестирование

### 5.1. Проверка логов Entry-ноды

```bash
# Логи Xray
tail -f /var/log/xray/error.log
```

При подключении клиента должны появиться записи о соединении.

### 5.2. Проверка логов Core-ноды

```bash
# На Core-ноде
tail -f /var/log/xray/access.log
```

При успешном подключении — записи о входящих соединениях от Entry-ноды.

### 5.3. Тестирование с клиента

1. Подключитесь клиентом (v2rayNG, NekoRay) к Entry-ноде
2. Откройте любой сайт
3. Проверьте свой IP (должен быть IP Core-ноды, а не Entry-ноды):
   ```
   curl ifconfig.me
   ```

**Ожидаемый результат:** `45.63.121.41` (IP Core-ноды)

---

## 6. Откат изменений

Если что-то пошло не так:

```bash
# Восстанавливаем резервную копию
cp /usr/local/etc/xray/config.json.backup /usr/local/etc/xray/config.json

# Перезапускаем
systemctl restart xray
```

---

## 7. Схема маршрутизации

### Текущая конфигурация

```
┌─────────────────────────────────────────────────────────────────┐
│                    ENTRY-НОДА (leto-ru)                         │
│                                                                 │
│   Inbound:                                                      │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │ :10001 (XHTTP)  ─┐                                      │   │
│   │ :10002 (WS)     ─┼─── routing rule ───▶ outbound:to-core│   │
│   │ :10003 (gRPC)   ─┘                                      │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│   Outbound "to-core":                                           │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │ protocol: vless                                         │   │
│   │ address: 45.63.121.41:443                               │   │
│   │ transport: WebSocket + TLS                              │   │
│   │ path: /api/v2/stream/{core-path}/                       │   │
│   │ tlsSettings.allowInsecure: true                         │   │
│   └─────────────────────────────────────────────────────────┘   │
│                              │                                  │
└──────────────────────────────┼──────────────────────────────────┘
                               │
                               ▼
                    ┌──────────────────┐
                    │   CORE-НОДА      │
                    │  45.63.121.41    │
                    │        │         │
                    │        ▼         │
                    │    ИНТЕРНЕТ      │
                    └──────────────────┘
```

---

## 8. Чек-лист

- [ ] Резервная копия создана
- [ ] Конфигурация обновлена
- [ ] Путь WebSocket соответствует Core-ноде
- [ ] Синтаксис проверен
- [ ] Xray перезапущен
- [ ] Логи Entry-ноды показывают подключения
- [ ] Логи Core-ноды показывают входящий трафик
- [ ] Клиент успешно подключается
- [ ] IP клиента = IP Core-ноды (45.63.121.41)

---

## 9. Возможные проблемы

| Проблема | Причина | Решение |
|----------|---------|---------|
| `connection refused` | Core-нода недоступна | Проверить firewall на Core |
| `certificate verify failed` | TLS ошибка | Убедиться в `allowInsecure: true` |
| `path mismatch` | Путь не совпадает | Сверить пути в Entry и Core |
| IP не изменился | Трафик идёт напрямую | Проверить routing rules |

---

## Готово!

После выполнения всех шагов схема работает:

```
Клиент (РФ) → Entry-нода (РФ) → Core-нода (Япония) → Интернет
```

DPI видит только HTTPS-трафик между российским и японским серверами.

---

*Документ создан: 2026-01-20*
