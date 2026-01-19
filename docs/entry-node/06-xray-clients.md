# Настройка клиентских подключений

**Статус:** Этап 1 (MVP)
**Обновлено:** 2026-01-19

---

> **⚠️ Важно:** По результатам тестирования, **gRPC — единственный транспорт**, который работает через системы DPI в регулируемых сетях. XHTTP и WebSocket блокируются.

---

## Содержание

1. [Параметры подключения](#1-параметры-подключения)
2. [Формат VLESS-ссылки](#2-формат-vless-ссылки)
3. [Подключение gRPC (рекомендуется)](#3-подключение-grpc-рекомендуется)
4. [Подключение XHTTP (блокируется DPI)](#4-подключение-xhttp-блокируется-dpi)
5. [Подключение WebSocket (блокируется DPI)](#5-подключение-websocket-блокируется-dpi)
6. [Клиентские приложения](#6-клиентские-приложения)
7. [Проверка соединения](#7-проверка-соединения)
8. [Диагностика проблем](#8-диагностика-проблем)

---

## 1. Параметры подключения

Для подключения к Entry-ноде клиенту необходимы следующие параметры:

| Параметр | Значение | Описание |
|----------|----------|----------|
| Протокол | VLESS | Основной протокол |
| Адрес | `mimimi.pro` | Домен Entry-ноды |
| Порт | `443` | HTTPS порт |
| UUID | `ваш-uuid` | Идентификатор пользователя |
| Шифрование | `none` | TLS терминируется на Nginx |
| Транспорт | xhttp / ws / grpc | Тип транспорта |
| Путь | `/api/v2/.../` | Секретный путь |
| TLS | Включён | Обязательно |
| SNI | Пустой или `mimimi.pro` | Server Name Indication |

---

## 2. Формат VLESS-ссылки

VLESS-ссылка позволяет импортировать конфигурацию одним кликом.

### Общий формат

```
vless://UUID@АДРЕС:ПОРТ?параметры#имя
```

### Параметры URL

| Параметр | Описание | Значение |
|----------|----------|----------|
| `type` | Тип транспорта | `xhttp`, `ws`, `grpc` |
| `security` | Безопасность | `tls` |
| `path` | Путь (для xhttp/ws) | URL-encoded путь |
| `serviceName` | Имя сервиса (для gRPC) | Имя сервиса |
| `sni` | Server Name Indication | Пустой или домен |
| `fp` | Fingerprint | `chrome`, `firefox`, `safari` |
| `alpn` | ALPN протоколы | `h2,http/1.1` |

---

## 3. Подключение gRPC (рекомендуется)

**✅ gRPC — единственный транспорт, работающий через DPI** в регулируемых сетях.

gRPC использует HTTP/2 framing и сложнее детектируется системами глубокой инспекции пакетов.

### Параметры gRPC

| Параметр | Значение |
|----------|----------|
| Транспорт | `grpc` |
| Service Name | `api.v2.rpc.ваш-случайный-путь` |
| TLS | Включён |
| SNI | `mimimi.pro` |

### VLESS-ссылка для gRPC

```
vless://ВАШ-UUID@mimimi.pro:443?type=grpc&security=tls&serviceName=api.v2.rpc.ваш-путь&sni=mimimi.pro&fp=chrome&alpn=h2#Entry-gRPC
```

### Ручная настройка

**v2rayNG (рекомендуется для Android):**

1. Добавить сервер → VLESS
2. Заполнить параметры:

```
Адрес: mimimi.pro
Порт: 443
UUID: ваш-uuid
Шифрование: none
Транспорт: grpc
Service Name: api.v2.rpc.ваш-путь
TLS: включён
SNI: mimimi.pro
Fingerprint: chrome
ALPN: h2
```

**Примечание:** Для gRPC используйте только `h2` в ALPN (не `h2,http/1.1`).

---

## 4. Подключение XHTTP (блокируется DPI)

> **⚠️ Внимание:** XHTTP блокируется системами DPI в регулируемых сетях. Используйте только если вы находитесь в открытом интернете.

XHTTP (splithttp) — транспорт, разбивающий трафик на множество HTTP-запросов.

### Параметры XHTTP

| Параметр | Значение |
|----------|----------|
| Транспорт | `xhttp` (splithttp) |
| Путь | `/api/v2/xhttp/ваш-случайный-путь/` |
| TLS | Включён |
| SNI | Пустой или `mimimi.pro` |

### VLESS-ссылка для XHTTP

```
vless://ВАШ-UUID@mimimi.pro:443?type=xhttp&security=tls&path=%2Fapi%2Fv2%2Fxhttp%2Fваш-путь%2F&sni=mimimi.pro&fp=chrome&alpn=h2%2Chttp%2F1.1#Entry-XHTTP
```

### Ручная настройка в клиенте

```
Адрес: mimimi.pro
Порт: 443
UUID: ваш-uuid
Шифрование: none
Транспорт: xhttp (или splithttp)
Путь: /api/v2/xhttp/ваш-путь/
TLS: включён
SNI: mimimi.pro
Fingerprint: chrome
ALPN: h2,http/1.1
```

---

## 5. Подключение WebSocket (блокируется DPI)

> **⚠️ Внимание:** WebSocket блокируется системами DPI в регулируемых сетях. Используйте только если вы находитесь в открытом интернете.

WebSocket — транспорт, совместимый с CDN.

### Параметры WebSocket

| Параметр | Значение |
|----------|----------|
| Транспорт | `ws` |
| Путь | `/api/v2/stream/ваш-случайный-путь/` |
| TLS | Включён |
| SNI | `mimimi.pro` |

### VLESS-ссылка для WebSocket

```
vless://ВАШ-UUID@mimimi.pro:443?type=ws&security=tls&path=%2Fapi%2Fv2%2Fstream%2Fваш-путь%2F&sni=mimimi.pro&fp=chrome&alpn=h2%2Chttp%2F1.1#Entry-WS
```

### Ручная настройка

```
Адрес: mimimi.pro
Порт: 443
UUID: ваш-uuid
Шифрование: none
Транспорт: ws
Путь: /api/v2/stream/ваш-путь/
TLS: включён
SNI: mimimi.pro
Fingerprint: chrome
ALPN: h2,http/1.1
```

---

## 6. Клиентские приложения

### Windows

| Приложение | Описание | Ссылка |
|------------|----------|--------|
| **v2rayN** | Популярный клиент с GUI | [GitHub](https://github.com/2dust/v2rayN) |
| **NekoRay** | Современный клиент | [GitHub](https://github.com/MatsuriDayo/nekoray) |

### macOS

| Приложение | Описание | Ссылка |
|------------|----------|--------|
| **V2RayXS** | Нативный клиент для macOS | [GitHub](https://github.com/tzmax/V2RayXS) |
| **NekoRay** | Кроссплатформенный | [GitHub](https://github.com/MatsuriDayo/nekoray) |

### Linux

| Приложение | Описание | Ссылка |
|------------|----------|--------|
| **NekoRay** | GUI клиент | [GitHub](https://github.com/MatsuriDayo/nekoray) |
| **v2rayA** | Веб-интерфейс | [GitHub](https://github.com/v2rayA/v2rayA) |
| **Xray CLI** | Командная строка | [GitHub](https://github.com/XTLS/Xray-core) |

### Android

| Приложение | Описание | Статус | Ссылка |
|------------|----------|--------|--------|
| **v2rayNG** | Официальный клиент | ✅ Рекомендуется | [GitHub](https://github.com/2dust/v2rayNG) |
| NekoBox | Современный клиент | ⚠️ Проблемы с подключением | [GitHub](https://github.com/MatsuriDayo/NekoBoxForAndroid) |

> **Примечание:** По результатам тестирования, v2rayNG успешно устанавливает соединение, в то время как NekoBox (даже последняя версия) не смог подключиться.

### iOS

| Приложение | Описание | Ссылка |
|------------|----------|--------|
| **Shadowrocket** | Платный, но лучший | App Store |
| **Stash** | Альтернатива | App Store |

---

## 7. Проверка соединения

### После настройки клиента

1. **Подключитесь** к серверу через клиентское приложение

2. **Проверьте IP-адрес:**
   ```
   Откройте в браузере: https://ifconfig.me
   IP должен быть IP Entry-ноды (202.223.48.9)
   ```

3. **Проверьте доступ к заблокированным ресурсам:**
   ```
   Попробуйте открыть ресурсы, недоступные в вашем регионе
   ```

### Проверка через командную строку

```bash
# С включённым VPN-клиентом
curl https://ifconfig.me

# Должен вернуть IP Entry-ноды
```

---

## 8. Диагностика проблем

### Клиент не подключается

| Проблема | Решение |
|----------|---------|
| Неверный UUID | Проверьте UUID на сервере и клиенте |
| Неверный путь | Путь должен совпадать полностью, включая `/` |
| TLS отключён | Включите TLS в настройках клиента |
| Неверный порт | Порт должен быть 443 |

### Подключение есть, но сайты не открываются

| Проблема | Решение |
|----------|---------|
| DNS не работает | Используйте DNS через прокси в настройках клиента |
| Маршрутизация | Проверьте настройки маршрутизации (весь трафик через прокси) |

### Медленное соединение

| Проблема | Решение |
|----------|---------|
| Далёкий сервер | Выберите сервер ближе географически |
| Перегруженный сервер | Попробуйте в другое время |
| MTU проблемы | Попробуйте другой транспорт (WS вместо XHTTP) |

### Подключение обрывается

| Проблема | Решение |
|----------|---------|
| Таймаут на сервере | Проверьте `proxy_read_timeout` в Nginx |
| Нестабильный интернет | Проверьте базовое подключение |

---

## Примеры готовых ссылок

**Замените `UUID` и `путь` на ваши значения.**

### gRPC (рекомендуется — работает через DPI)

```
vless://a1b2c3d4-e5f6-7890-abcd-ef1234567890@mimimi.pro:443?type=grpc&security=tls&serviceName=api.v2.rpc.e1d2c3b4a5968778&sni=mimimi.pro&fp=chrome&alpn=h2#Mimimi-gRPC
```

### XHTTP (блокируется DPI)

```
vless://a1b2c3d4-e5f6-7890-abcd-ef1234567890@mimimi.pro:443?type=xhttp&security=tls&path=%2Fapi%2Fv2%2Fxhttp%2Fa3f8b2c1d4e5f678%2F&sni=mimimi.pro&fp=chrome&alpn=h2%2Chttp%2F1.1#Mimimi-XHTTP
```

### WebSocket (блокируется DPI)

```
vless://a1b2c3d4-e5f6-7890-abcd-ef1234567890@mimimi.pro:443?type=ws&security=tls&path=%2Fapi%2Fv2%2Fstream%2F9b7c6d5e4f3a2b1c%2F&sni=mimimi.pro&fp=chrome&alpn=h2%2Chttp%2F1.1#Mimimi-WS
```

---

## Чек-лист для пользователя

- [ ] Получил UUID от администратора
- [ ] Получил секретные пути для транспортов
- [ ] Установил клиентское приложение
- [ ] Импортировал VLESS-ссылку или настроил вручную
- [ ] Проверил подключение (IP изменился)
- [ ] Проверил доступ к ресурсам

---

## Генератор ссылок

Для удобства можно использовать скрипт генерации ссылок:

```bash
#!/bin/bash

# Параметры
UUID="ваш-uuid-здесь"
DOMAIN="mimimi.pro"
PORT="443"
XHTTP_PATH="/api/v2/xhttp/ваш-путь/"
WS_PATH="/api/v2/stream/ваш-путь/"
GRPC_SERVICE="api.v2.rpc.ваш-путь"

# URL-encode функция
urlencode() {
    python3 -c "import urllib.parse; print(urllib.parse.quote('$1', safe=''))"
}

# Генерация ссылок
echo "=== gRPC (рекомендуется) ==="
echo "vless://${UUID}@${DOMAIN}:${PORT}?type=grpc&security=tls&serviceName=${GRPC_SERVICE}&sni=${DOMAIN}&fp=chrome&alpn=h2#Entry-gRPC"
echo ""

echo "=== XHTTP (блокируется DPI) ==="
echo "vless://${UUID}@${DOMAIN}:${PORT}?type=xhttp&security=tls&path=$(urlencode ${XHTTP_PATH})&sni=${DOMAIN}&fp=chrome&alpn=h2%2Chttp%2F1.1#Entry-XHTTP"
echo ""

echo "=== WebSocket (блокируется DPI) ==="
echo "vless://${UUID}@${DOMAIN}:${PORT}?type=ws&security=tls&path=$(urlencode ${WS_PATH})&sni=${DOMAIN}&fp=chrome&alpn=h2%2Chttp%2F1.1#Entry-WS"
```

---

*Документ описывает настройку клиентов для Entry-ноды этапа 1 (MVP).*
