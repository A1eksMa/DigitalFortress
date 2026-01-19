# Установка и настройка Xray на Entry-ноде

**Статус:** Этап 1 (MVP)
**Целевой сервер:** Entry-нода с установленным Nginx и SSL

---

## Содержание

1. [Предварительные требования](#1-предварительные-требования)
2. [Установка Xray-core](#2-установка-xray-core)
3. [Генерация UUID](#3-генерация-uuid)
4. [Генерация случайных путей](#4-генерация-случайных-путей)
5. [Конфигурация Xray](#5-конфигурация-xray)
6. [Интеграция с Nginx](#6-интеграция-с-nginx)
7. [Запуск и проверка](#7-запуск-и-проверка)
8. [Автозапуск (systemd)](#8-автозапуск-systemd)
9. [Диагностика проблем](#9-диагностика-проблем)

---

## 1. Предварительные требования

Перед установкой Xray убедитесь, что:

- [ ] Nginx установлен и работает
- [ ] SSL-сертификат получен (Let's Encrypt)
- [ ] Сайт-прикрытие развёрнут и доступен по HTTPS
- [ ] Файрвол настроен (только порты 22 и 443)

**Проверка:**

```bash
# Nginx работает
sudo systemctl status nginx

# Сертификат действителен
echo | openssl s_client -servername mimimi.pro -connect mimimi.pro:443 2>/dev/null | openssl x509 -noout -dates

# Сайт доступен
curl -I https://mimimi.pro
```

---

## 2. Установка Xray-core

### 2.1. Официальный скрипт установки

```bash
# Скачиваем и запускаем официальный скрипт
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
```

**Что устанавливает скрипт:**

- Бинарный файл: `/usr/local/bin/xray`
- Конфигурация: `/usr/local/etc/xray/config.json`
- Systemd-сервис: `xray.service`
- Логи: `/var/log/xray/`

### 2.2. Проверка установки

```bash
# Версия Xray
xray version

# Статус сервиса (пока не запущен)
sudo systemctl status xray
```

**Ожидаемый вывод:**

```
Xray 1.8.x (Xray, Penetrates Everything.)
```

---

## 3. Генерация UUID

UUID — это идентификатор пользователя для VLESS. Каждый пользователь должен иметь уникальный UUID.

```bash
# Генерация UUID через Xray
xray uuid

# Или через стандартную утилиту
cat /proc/sys/kernel/random/uuid
```

**Пример вывода:**

```
a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

**Сохраните этот UUID** — он понадобится для конфигурации сервера и клиента.

---

## 4. Генерация случайных путей

Пути URL должны выглядеть как легитимные API-эндпоинты и быть уникальными.

```bash
# Генерация случайной строки (16 символов)
openssl rand -hex 8

# Или через /dev/urandom
head -c 8 /dev/urandom | xxd -p
```

**Создайте три разных пути для трёх транспортов:**

| Транспорт | Пример пути |
|-----------|-------------|
| XHTTP | `/api/v2/xhttp/a3f8b2c1d4e5f678/` |
| WebSocket | `/api/v2/stream/9b7c6d5e4f3a2b1c/` |
| gRPC | `/api/v2/rpc/e1d2c3b4a5968778/` |

**Важно:** Запишите эти пути — они нужны для Nginx и клиентов.

---

## 5. Конфигурация Xray

### 5.1. Создание конфигурационного файла

```bash
sudo nano /usr/local/etc/xray/config.json
```

### 5.2. Конфигурация с тремя транспортами

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
            "id": "ВАШ-UUID-ЗДЕСЬ",
            "level": 0
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "xhttp",
        "xhttpSettings": {
          "path": "/api/v2/xhttp/ВАШ-СЛУЧАЙНЫЙ-ПУТЬ/"
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
            "id": "ВАШ-UUID-ЗДЕСЬ",
            "level": 0
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/api/v2/stream/ВАШ-СЛУЧАЙНЫЙ-ПУТЬ/"
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
            "id": "ВАШ-UUID-ЗДЕСЬ",
            "level": 0
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": {
          "serviceName": "api.v2.rpc.ВАШ-СЛУЧАЙНЫЙ-ПУТЬ"
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

### 5.3. Пояснения к конфигурации

| Параметр | Значение | Описание |
|----------|----------|----------|
| `listen` | `127.0.0.1` | Только локальные подключения (через Nginx) |
| `port` | 10001-10003 | Внутренние порты для трёх транспортов |
| `decryption` | `none` | TLS терминируется на Nginx |
| `network` | xhttp/ws/grpc | Тип транспорта |
| `outbounds.freedom` | — | Прямой выход в интернет (этап 1) |

### 5.4. Проверка синтаксиса

```bash
# Проверка конфигурации
xray run -test -config /usr/local/etc/xray/config.json
```

**Ожидаемый вывод:**

```
Configuration OK.
```

---

## 6. Интеграция с Nginx

### 6.1. Обновление конфигурации Nginx

```bash
sudo nano /etc/nginx/sites-available/mimimi.pro
```

### 6.2. Добавление проксирования для Xray

Добавьте следующие блоки `location` внутрь секции `server { listen 443 ssl; ... }`:

```nginx
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name mimimi.pro;

    # SSL сертификаты (уже настроены Certbot)
    ssl_certificate /etc/letsencrypt/live/mimimi.pro/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/mimimi.pro/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    # Корневая директория сайта-прикрытия
    root /var/www/mimimi.pro/html;
    index index.html;

    # === XHTTP транспорт ===
    location /api/v2/xhttp/ВАШ-СЛУЧАЙНЫЙ-ПУТЬ/ {
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }

    # === WebSocket транспорт ===
    location /api/v2/stream/ВАШ-СЛУЧАЙНЫЙ-ПУТЬ/ {
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

    # === gRPC транспорт ===
    location /api.v2.rpc.ВАШ-СЛУЧАЙНЫЙ-ПУТЬ {
        grpc_pass grpc://127.0.0.1:10003;
        grpc_set_header Host $host;
        grpc_set_header X-Real-IP $remote_addr;
        grpc_read_timeout 300s;
        grpc_send_timeout 300s;
    }

    # === Сайт-прикрытие (основной) ===
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Кэширование статики
    location ~* \.(svg|jpg|jpeg|png|gif|ico|css|js)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # Логи
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

### 6.3. Важные моменты конфигурации Nginx

| Параметр | Описание |
|----------|----------|
| `proxy_http_version 1.1` | Обязательно для WebSocket |
| `proxy_set_header Upgrade` | Обязательно для WebSocket upgrade |
| `grpc_pass` | Специальная директива для gRPC |
| `proxy_read_timeout 300s` | Длительные соединения для VPN |

### 6.4. Fallback на сайт-прикрытие

При обращении на секретные пути без правильных заголовков VLESS, Nginx вернёт сайт-прикрытие благодаря `try_files` и порядку блоков `location`.

Для усиления маскировки можно добавить явный fallback:

```nginx
# Fallback для неправильных запросов к API
location /api/ {
    try_files $uri /index.html;
}
```

### 6.5. Проверка и перезапуск Nginx

```bash
# Проверка синтаксиса
sudo nginx -t

# Перезагрузка конфигурации
sudo systemctl reload nginx
```

---

## 7. Запуск и проверка

### 7.1. Запуск Xray

```bash
# Запускаем Xray
sudo systemctl start xray

# Проверяем статус
sudo systemctl status xray
```

**Ожидаемый вывод:**

```
● xray.service - Xray Service
     Loaded: loaded
     Active: active (running)
```

### 7.2. Проверка портов

```bash
# Xray должен слушать на localhost
ss -tlnp | grep xray
```

**Ожидаемый вывод:**

```
LISTEN  0  4096  127.0.0.1:10001  0.0.0.0:*  users:(("xray",pid=...))
LISTEN  0  4096  127.0.0.1:10002  0.0.0.0:*  users:(("xray",pid=...))
LISTEN  0  4096  127.0.0.1:10003  0.0.0.0:*  users:(("xray",pid=...))
```

**Важно:** Xray должен слушать ТОЛЬКО на `127.0.0.1`, не на `0.0.0.0`.

### 7.3. Проверка логов

```bash
# Логи Xray
sudo tail -f /var/log/xray/error.log

# Логи Nginx
sudo tail -f /var/log/nginx/mimimi.pro_error.log
```

### 7.4. Проверка сайта-прикрытия

```bash
# Сайт должен работать
curl -I https://mimimi.pro

# Секретный путь без VLESS заголовков → должен вернуть сайт
curl -I https://mimimi.pro/api/v2/xhttp/ваш-путь/
```

---

## 8. Автозапуск (systemd)

Xray устанавливается с systemd-юнитом автоматически. Однако стандартная конфигурация требует дополнительной настройки прав доступа.

### 8.1. Известная проблема: Xray не биндится к портам

**Симптом:** После `systemctl start xray` сервис показывает статус `active (running)`, но при проверке портов — пустой вывод:

```bash
$ sudo ss -tlnp | grep 127.0.0.1
# Пустой вывод — Xray не слушает на портах
```

**Причина:** Официальный скрипт устанавливает сервис с `User=nobody`. Этот пользователь не имеет прав на запись в директорию логов `/var/log/xray/`, что приводит к тихому падению процесса при инициализации.

### 8.2. Решение: Настройка прав доступа

**Вариант A: Исправление прав для пользователя nobody (рекомендуется)**

```bash
# Создаём директорию логов если её нет
sudo mkdir -p /var/log/xray

# Устанавливаем владельца nobody:nogroup
sudo chown -R nobody:nogroup /var/log/xray

# Устанавливаем права
sudo chmod 755 /var/log/xray

# Проверяем права на конфигурацию (должна быть читаема для nobody)
sudo chmod 644 /usr/local/etc/xray/config.json

# Проверяем права на geo-файлы
sudo chmod 644 /usr/local/share/xray/*.dat 2>/dev/null || true

# Перезапускаем сервис
sudo systemctl restart xray

# Проверяем порты
sudo ss -tlnp | grep 127.0.0.1
```

**Вариант B: Создание выделенного пользователя xray**

```bash
# Создаём системного пользователя xray
sudo useradd -r -s /usr/sbin/nologin -d /nonexistent xray

# Настраиваем права на директории
sudo chown -R xray:xray /var/log/xray
sudo chown -R xray:xray /usr/local/etc/xray

# Редактируем systemd unit
sudo nano /etc/systemd/system/xray.service
```

Измените строку `User=nobody` на `User=xray`:

```ini
[Service]
User=xray
```

```bash
# Применяем изменения
sudo systemctl daemon-reload
sudo systemctl restart xray
```

**Вариант C: Запуск от root (быстрое решение, менее безопасно)**

```bash
# Редактируем systemd unit
sudo nano /etc/systemd/system/xray.service
```

Закомментируйте или удалите строку `User=nobody`:

```ini
[Service]
# User=nobody  # Закомментировано — запуск от root
```

```bash
# Применяем изменения
sudo systemctl daemon-reload
sudo systemctl restart xray
```

### 8.3. Проверка после настройки

```bash
# Статус сервиса
sudo systemctl status xray

# Порты должны быть заняты
sudo ss -tlnp | grep 127.0.0.1
```

**Ожидаемый вывод:**

```
LISTEN  0  4096  127.0.0.1:10001  0.0.0.0:*  users:(("xray",pid=...))
LISTEN  0  4096  127.0.0.1:10002  0.0.0.0:*  users:(("xray",pid=...))
LISTEN  0  4096  127.0.0.1:10003  0.0.0.0:*  users:(("xray",pid=...))
```

### 8.4. Включение автозапуска

```bash
# Включаем автозапуск
sudo systemctl enable xray

# Проверяем
sudo systemctl is-enabled xray
```

### 8.5. Управление сервисом

```bash
# Запуск
sudo systemctl start xray

# Остановка
sudo systemctl stop xray

# Перезапуск
sudo systemctl restart xray

# Перезагрузка конфигурации (без разрыва соединений)
sudo systemctl reload xray

# Статус
sudo systemctl status xray
```

---

## 9. Диагностика проблем

### Xray не запускается

```bash
# Проверяем логи
sudo journalctl -u xray -n 50

# Проверяем конфигурацию
xray run -test -config /usr/local/etc/xray/config.json
```

### Xray запущен, но не слушает на портах

**Симптом:** `systemctl status xray` показывает `active (running)`, но `ss -tlnp | grep 127.0.0.1` пустой.

**Диагностика:**

```bash
# Проверяем права на директорию логов
ls -la /var/log/xray/

# Проверяем, может ли nobody писать в директорию
sudo -u nobody touch /var/log/xray/test && echo "OK" || echo "FAIL"
sudo rm -f /var/log/xray/test

# Проверяем журнал systemd на ошибки
sudo journalctl -u xray -n 100 --no-pager
```

**Решение:** См. раздел 8.2 — настройка прав доступа.

**Временный workaround (запуск вручную):**

```bash
# Останавливаем systemd-сервис
sudo systemctl stop xray

# Убиваем все процессы Xray
sudo pkill -9 xray

# Запускаем вручную (для тестирования)
sudo /usr/local/bin/xray run -config /usr/local/etc/xray/config.json

# После тестирования: Ctrl+C и исправление systemd
```

### Nginx возвращает 502 Bad Gateway

```bash
# Xray запущен?
sudo systemctl status xray

# Порты слушаются?
sudo ss -tlnp | grep 1000

# Проверяем логи Nginx
sudo tail -f /var/log/nginx/mimimi.pro_error.log
```

### Клиент не подключается

1. Проверьте UUID — должен совпадать на сервере и клиенте
2. Проверьте путь — должен совпадать полностью, включая слеши
3. Проверьте, что TLS включён на клиенте
4. Проверьте SNI — должен быть `mimimi.pro`

### XHTTP и WebSocket блокируются DPI

**Симптом:** Из открытого интернета подключение работает, из регулируемой сети — соединение сразу закрывается.

**Причина:** Системы DPI (Deep Packet Inspection) анализируют паттерны трафика и могут блокировать XHTTP и WebSocket даже при использовании TLS.

**Решение:** Использовать gRPC-транспорт. gRPC использует HTTP/2 framing и сложнее детектируется как VPN-трафик.

```
vless://UUID@домен:443?type=grpc&security=tls&serviceName=api.v2.rpc.путь&sni=домен#Название
```

### Тесты подключения показывают ошибку

**Симптом:** Клиент подключён, но встроенный тест показывает ошибку.

**Причина:** Многие адреса, которые используются клиентами для тестирования (например, `gstatic.com`, `cloudflare.com`), заблокированы регулятором.

**Проверка:** Откройте браузер и попробуйте зайти на любой сайт. Если сайты открываются — VPN работает, игнорируйте результаты встроенного теста.

### Рекомендации по клиентам

| Клиент | Платформа | Статус |
|--------|-----------|--------|
| **v2rayNG** | Android | ✅ Рекомендуется |
| NekoBox | Android | ⚠️ Проблемы с подключением |
| v2rayN | Windows | ✅ Работает |

**Важно:** Используйте последние версии клиентов. XHTTP — относительно новый транспорт.

---

## Чек-лист готовности

- [ ] Xray установлен
- [ ] UUID сгенерирован и записан
- [ ] Пути сгенерированы и записаны
- [ ] Конфигурация Xray создана и проверена
- [ ] Nginx обновлён с проксированием
- [ ] Xray запущен и слушает на localhost
- [ ] Автозапуск включён
- [ ] Сайт-прикрытие работает
- [ ] Логи не содержат ошибок

---

## Следующий шаг

→ [06-xray-clients.md](./06-xray-clients.md) — Настройка клиентских подключений
