# Установка и настройка Xray

**Статус:** Этап 2

---

## 1. Установка Xray

### 1.1. Автоматическая установка

```bash
# Скачиваем и запускаем установочный скрипт
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
```

### 1.2. Проверка установки

```bash
# Версия Xray
xray version

# Путь к конфигурации
ls -la /usr/local/etc/xray/

# Статус сервиса
systemctl status xray
```

---

## 2. Создание директории для логов

```bash
# Создаём директорию
mkdir -p /var/log/xray

# Устанавливаем права (Xray работает от nobody)
chown nobody:nogroup /var/log/xray
chmod 755 /var/log/xray
```

---

## 3. Конфигурация Xray

### 3.1. Создание конфигурации

```bash
nano /usr/local/etc/xray/config.json
```

**Содержимое:**

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
          "path": "/api/v2/stream/ЗАМЕНИТЕ_НА_ВАШ_ПУТЬ/"
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
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "block"
      }
    ]
  }
}
```

### 3.2. Важные параметры

| Параметр | Значение | Описание |
|----------|----------|----------|
| `listen` | `127.0.0.1` | Только localhost (Nginx проксирует) |
| `port` | `10001` | Порт для WebSocket от Entry-ноды |
| `id` | UUID | Тот же UUID, что на Entry-ноде |
| `path` | `/api/v2/stream/{random}/` | Должен совпадать с Nginx |
| `decryption` | `none` | TLS терминируется на Nginx |

### 3.3. Замена плейсхолдеров

Замените `ЗАМЕНИТЕ_НА_ВАШ_ПУТЬ` на путь, сгенерированный в шаге 2 документа `04-nginx-setup.md`.

**Пример:**
```json
"path": "/api/v2/stream/a1b2c3d4e5f67890/"
```

---

## 4. Проверка конфигурации

```bash
# Проверка синтаксиса JSON
xray run -test -config /usr/local/etc/xray/config.json
```

**Ожидаемый вывод:**

```
Xray X.XX (Xray, Pair) Custom (go1.XX linux/amd64)
A]dequate L]ibrary for X]treme-ray.
Configuration OK.
```

---

## 5. Запуск Xray

```bash
# Запускаем сервис
systemctl start xray

# Включаем автозапуск
systemctl enable xray

# Проверяем статус
systemctl status xray
```

**Ожидаемый статус:** `active (running)`

---

## 6. Проверка работы

### 6.1. Проверка порта

```bash
# Xray должен слушать на 127.0.0.1:10001
ss -tlnp | grep xray
```

**Ожидаемый вывод:**

```
LISTEN 0  4096  127.0.0.1:10001  0.0.0.0:*  users:(("xray",pid=XXXX,fd=X))
```

### 6.2. Проверка логов

```bash
# Логи ошибок
tail -f /var/log/xray/error.log

# Логи доступа
tail -f /var/log/xray/access.log
```

### 6.3. Тестовое подключение

После настройки Entry-ноды проверьте подключение:

```bash
# На Entry-ноде: проверка связи с Core-нодой
curl -k -v --http1.1 \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  -H "Sec-WebSocket-Version: 13" \
  https://45.63.121.41/api/v2/stream/ВАШ_ПУТЬ/
```

**Ожидаемый ответ:** HTTP 101 Switching Protocols

---

## 7. Отладка

### 7.1. Включение debug-логов

Временно для отладки:

```json
{
  "log": {
    "loglevel": "debug",
    ...
  }
}
```

```bash
# Перезапуск после изменения
systemctl restart xray

# Просмотр подробных логов
tail -f /var/log/xray/error.log
```

### 7.2. Типичные проблемы

| Проблема | Причина | Решение |
|----------|---------|---------|
| `connection refused` | Xray не запущен | `systemctl start xray` |
| `permission denied` на логи | Неверные права | `chown nobody:nogroup /var/log/xray` |
| `invalid user` | Неверный UUID | Проверить совпадение UUID |
| `path mismatch` | Путь не совпадает | Проверить путь в Nginx и Xray |

---

## 8. Итоговая конфигурация

### Файлы Core-ноды

| Файл | Назначение |
|------|------------|
| `/etc/ssl/core/core.crt` | Самоподписанный сертификат |
| `/etc/ssl/core/core.key` | Приватный ключ |
| `/etc/nginx/sites-available/core` | Конфигурация Nginx |
| `/usr/local/etc/xray/config.json` | Конфигурация Xray |
| `/var/www/core/html/` | Сайт-прикрытие |
| `/var/log/xray/` | Логи Xray |

### Порты

| Порт | Сервис | Интерфейс |
|------|--------|-----------|
| 443 | Nginx | 0.0.0.0 (публичный) |
| 10001 | Xray (WebSocket) | 127.0.0.1 (localhost) |

---

## 9. Чек-лист

- [ ] Xray установлен
- [ ] Директория логов создана с правильными правами
- [ ] Конфигурация создана с правильным UUID и путём
- [ ] Синтаксис конфигурации проверен
- [ ] Xray запущен и работает
- [ ] Порт 10001 слушает на localhost
- [ ] Автозапуск включён

---

## Следующий шаг

→ [06-entry-node-update.md](./06-entry-node-update.md) — Обновление конфигурации Entry-ноды

---

*Документ создан: 2026-01-20*
