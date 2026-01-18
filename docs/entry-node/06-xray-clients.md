# Настройка клиентских подключений

**Статус:** Этап 1 (MVP)

---

## Содержание

1. [Параметры подключения](#1-параметры-подключения)
2. [Формат VLESS-ссылки](#2-формат-vless-ссылки)
3. [Подключение XHTTP (основной)](#3-подключение-xhttp-основной)
4. [Подключение WebSocket](#4-подключение-websocket)
5. [Подключение gRPC](#5-подключение-grpc)
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

## 3. Подключение XHTTP (основной)

XHTTP (splithttp) — приоритетный транспорт, наиболее устойчивый к обнаружению.

### Параметры XHTTP

| Параметр | Значение |
|----------|----------|
| Транспорт | `xhttp` (splithttp) |
| Путь | `/api/v2/xhttp/ваш-случайный-путь/` |
| TLS | Включён |
| SNI | Пустой |

### VLESS-ссылка для XHTTP

```
vless://ВАШ-UUID@mimimi.pro:443?type=xhttp&security=tls&path=%2Fapi%2Fv2%2Fxhttp%2Fваш-путь%2F&sni=&fp=chrome&alpn=h2%2Chttp%2F1.1#Entry-XHTTP
```

**Разбор ссылки:**

| Компонент | Значение |
|-----------|----------|
| `ВАШ-UUID` | UUID пользователя |
| `mimimi.pro:443` | Адрес и порт |
| `type=xhttp` | Транспорт XHTTP |
| `security=tls` | TLS включён |
| `path=...` | URL-encoded путь |
| `sni=` | SNI пустой |
| `fp=chrome` | Fingerprint Chrome |
| `alpn=h2,http/1.1` | ALPN протоколы |
| `#Entry-XHTTP` | Имя подключения |

### Ручная настройка в клиенте

**v2rayN / NekoBox / v2rayNG:**

1. Добавить сервер → VLESS
2. Заполнить параметры:

```
Адрес: mimimi.pro
Порт: 443
UUID: ваш-uuid
Шифрование: none
Транспорт: xhttp (или splithttp)
Путь: /api/v2/xhttp/ваш-путь/
TLS: включён
SNI: (оставить пустым)
Fingerprint: chrome
ALPN: h2,http/1.1
```

---

## 4. Подключение WebSocket

WebSocket — резервный транспорт, хорошо совместим с CDN.

### Параметры WebSocket

| Параметр | Значение |
|----------|----------|
| Транспорт | `ws` |
| Путь | `/api/v2/stream/ваш-случайный-путь/` |
| TLS | Включён |
| SNI | Пустой |

### VLESS-ссылка для WebSocket

```
vless://ВАШ-UUID@mimimi.pro:443?type=ws&security=tls&path=%2Fapi%2Fv2%2Fstream%2Fваш-путь%2F&sni=&fp=chrome&alpn=h2%2Chttp%2F1.1#Entry-WS
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
SNI: (оставить пустым)
Fingerprint: chrome
ALPN: h2,http/1.1
```

---

## 5. Подключение gRPC

gRPC — резервный транспорт на основе HTTP/2 с мультиплексированием.

### Параметры gRPC

| Параметр | Значение |
|----------|----------|
| Транспорт | `grpc` |
| Service Name | `api.v2.rpc.ваш-случайный-путь` |
| TLS | Включён |
| SNI | Пустой |

### VLESS-ссылка для gRPC

```
vless://ВАШ-UUID@mimimi.pro:443?type=grpc&security=tls&serviceName=api.v2.rpc.ваш-путь&sni=&fp=chrome&alpn=h2#Entry-gRPC
```

### Ручная настройка

```
Адрес: mimimi.pro
Порт: 443
UUID: ваш-uuid
Шифрование: none
Транспорт: grpc
Service Name: api.v2.rpc.ваш-путь
TLS: включён
SNI: (оставить пустым)
Fingerprint: chrome
ALPN: h2
```

**Примечание:** Для gRPC рекомендуется использовать только `h2` в ALPN.

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

| Приложение | Описание | Ссылка |
|------------|----------|--------|
| **v2rayNG** | Официальный клиент | [GitHub](https://github.com/2dust/v2rayNG) |
| **NekoBox** | Современный клиент | [GitHub](https://github.com/MatsuriDayo/NekoBoxForAndroid) |

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

### XHTTP (рекомендуемый)

```
vless://a1b2c3d4-e5f6-7890-abcd-ef1234567890@mimimi.pro:443?type=xhttp&security=tls&path=%2Fapi%2Fv2%2Fxhttp%2Fa3f8b2c1d4e5f678%2F&sni=&fp=chrome&alpn=h2%2Chttp%2F1.1#Mimimi-XHTTP
```

### WebSocket

```
vless://a1b2c3d4-e5f6-7890-abcd-ef1234567890@mimimi.pro:443?type=ws&security=tls&path=%2Fapi%2Fv2%2Fstream%2F9b7c6d5e4f3a2b1c%2F&sni=&fp=chrome&alpn=h2%2Chttp%2F1.1#Mimimi-WS
```

### gRPC

```
vless://a1b2c3d4-e5f6-7890-abcd-ef1234567890@mimimi.pro:443?type=grpc&security=tls&serviceName=api.v2.rpc.e1d2c3b4a5968778&sni=&fp=chrome&alpn=h2#Mimimi-gRPC
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
echo "=== XHTTP ==="
echo "vless://${UUID}@${DOMAIN}:${PORT}?type=xhttp&security=tls&path=$(urlencode ${XHTTP_PATH})&sni=&fp=chrome&alpn=h2%2Chttp%2F1.1#Entry-XHTTP"
echo ""

echo "=== WebSocket ==="
echo "vless://${UUID}@${DOMAIN}:${PORT}?type=ws&security=tls&path=$(urlencode ${WS_PATH})&sni=&fp=chrome&alpn=h2%2Chttp%2F1.1#Entry-WS"
echo ""

echo "=== gRPC ==="
echo "vless://${UUID}@${DOMAIN}:${PORT}?type=grpc&security=tls&serviceName=${GRPC_SERVICE}&sni=&fp=chrome&alpn=h2#Entry-gRPC"
```

---

*Документ описывает настройку клиентов для Entry-ноды этапа 1 (MVP).*
