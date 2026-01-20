# Установка и настройка Nginx

**Статус:** Этап 2

---

## 1. Установка Nginx

```bash
# Устанавливаем Nginx
apt update
apt install -y nginx

# Проверяем статус
systemctl status nginx

# Включаем автозапуск
systemctl enable nginx
```

---

## 2. Генерация случайного пути

Для WebSocket туннеля нужен секретный путь. Генерируем:

```bash
# Генерируем 16 символов hex
openssl rand -hex 8
```

**Пример вывода:** `a1b2c3d4e5f67890`

Полный путь будет: `/api/v2/stream/a1b2c3d4e5f67890/`

**Важно:** Запишите этот путь — он понадобится для настройки Xray и Entry-ноды.

---

## 3. Конфигурация Nginx

### 3.1. Создание конфигурации

```bash
nano /etc/nginx/sites-available/core
```

**Содержимое:**

```nginx
# Директива для корректной работы WebSocket с HTTP/2
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name 45.63.121.41;

    # Самоподписанный сертификат
    ssl_certificate /etc/ssl/core/core.crt;
    ssl_certificate_key /etc/ssl/core/core.key;

    # TLS настройки
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;

    # Сайт-прикрытие
    root /var/www/core/html;
    index index.html;

    # ============================================================
    # WebSocket от Entry-ноды
    # ЗАМЕНИТЕ a1b2c3d4e5f67890 на ваш сгенерированный путь
    # ============================================================
    location /api/v2/stream/a1b2c3d4e5f67890/ {
        proxy_pass http://127.0.0.1:10001;
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

    # Сайт-прикрытие (fallback)
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Кэширование статики
    location ~* \.(svg|jpg|jpeg|png|gif|ico|css|js)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    access_log /var/log/nginx/core_access.log;
    error_log /var/log/nginx/core_error.log;
}
```

### 3.2. Важные моменты конфигурации

| Директива | Назначение |
|-----------|------------|
| `map $http_upgrade` | Корректная работа WebSocket при HTTP/2 |
| `proxy_set_header Upgrade` | Передача заголовка WebSocket |
| `proxy_set_header Connection $connection_upgrade` | Динамическое значение Connection |
| `proxy_buffering off` | Отключение буферизации для real-time |
| `try_files ... /index.html` | SPA fallback для сайта-прикрытия |

---

## 4. Активация конфигурации

```bash
# Создаём символическую ссылку
ln -s /etc/nginx/sites-available/core /etc/nginx/sites-enabled/

# Удаляем дефолтную конфигурацию (опционально)
rm -f /etc/nginx/sites-enabled/default

# Проверяем синтаксис
nginx -t

# Перезапускаем Nginx
systemctl reload nginx
```

**Ожидаемый вывод `nginx -t`:**

```
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

---

## 5. Установка сайта-прикрытия

### 5.1. Копирование с Entry-ноды

Если сайт-прикрытие уже настроен на Entry-ноде:

```bash
# На Entry-ноде (leto-ru)
scp -r /var/www/mimimi.pro/html/* root@45.63.121.41:/var/www/core/html/
```

### 5.2. Или копирование из репозитория

```bash
# Клонируем репозиторий (если ещё не склонирован)
git clone https://github.com/YOUR_REPO/DigitalFortress.git /tmp/df

# Копируем сайт
cp -r /tmp/df/site/* /var/www/core/html/

# Устанавливаем права
chown -R www-data:www-data /var/www/core/html
chmod -R 755 /var/www/core/html
```

### 5.3. Проверка

```bash
# Проверяем наличие файлов
ls -la /var/www/core/html/

# Проверяем размер (должен быть >16 КБ)
du -sh /var/www/core/html/
```

---

## 6. Тестирование

### 6.1. Проверка HTTPS

```bash
# С самой Core-ноды (игнорируем самоподписанный сертификат)
curl -k https://127.0.0.1/

# Должен вернуть HTML сайта-прикрытия
```

### 6.2. Проверка с внешнего хоста

```bash
# С Entry-ноды или локальной машины
curl -k https://45.63.121.41/

# Должен вернуть HTML сайта-прикрытия
```

### 6.3. Проверка WebSocket пути (до установки Xray)

```bash
curl -k -I https://45.63.121.41/api/v2/stream/a1b2c3d4e5f67890/
```

**Ожидаемый результат:** HTTP 502 Bad Gateway (Xray ещё не запущен)

После установки Xray — HTTP 101 Switching Protocols (при корректном WebSocket handshake).

---

## 7. Логи

```bash
# Просмотр логов доступа
tail -f /var/log/nginx/core_access.log

# Просмотр логов ошибок
tail -f /var/log/nginx/core_error.log
```

---

## 8. Чек-лист

- [ ] Nginx установлен и запущен
- [ ] Сгенерирован случайный путь для WebSocket
- [ ] Конфигурация создана в `/etc/nginx/sites-available/core`
- [ ] Символическая ссылка создана в `sites-enabled`
- [ ] Синтаксис проверен (`nginx -t`)
- [ ] Сайт-прикрытие скопирован в `/var/www/core/html/`
- [ ] HTTPS работает (curl -k https://45.63.121.41/)
- [ ] Сайт-прикрытие отображается

---

## Следующий шаг

→ [05-xray-install.md](./05-xray-install.md) — Установка и настройка Xray

---

*Документ создан: 2026-01-20*
