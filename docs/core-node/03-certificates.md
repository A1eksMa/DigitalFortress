# Генерация самоподписанного сертификата

**Статус:** Этап 2

---

## 1. Введение

Core-нода использует самоподписанный TLS-сертификат для шифрования соединения с Entry-нодой. Это упрощает настройку и не требует домена.

### Почему самоподписанный сертификат

| Аспект | Самоподписанный | Let's Encrypt |
|--------|-----------------|---------------|
| Требует домен | Нет | Да |
| Сложность | Минимальная | Средняя |
| Автообновление | Не нужно | Нужно |
| Доверие браузеров | Нет | Да |
| Для Entry→Core | Достаточно | Избыточно |

Entry-нода явно доверяет сертификату Core-ноды (`allowInsecure: true`), поэтому валидация через CA не требуется.

---

## 2. Генерация сертификата

### 2.1. Создание сертификата для IP-адреса

```bash
# Переходим в директорию для сертификатов
cd /etc/ssl/core

# Генерируем приватный ключ и сертификат
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout core.key \
  -out core.crt \
  -subj "/CN=45.63.121.41" \
  -addext "subjectAltName=IP:45.63.121.41"
```

**Параметры:**
- `-x509` — самоподписанный сертификат
- `-nodes` — без пароля на ключ
- `-days 365` — срок действия 1 год
- `-newkey rsa:2048` — генерация нового RSA-ключа
- `-subj "/CN=..."` — Common Name (IP-адрес)
- `-addext "subjectAltName=..."` — Subject Alternative Name для IP

### 2.2. Проверка сертификата

```bash
# Просмотр информации о сертификате
openssl x509 -in /etc/ssl/core/core.crt -text -noout
```

**Ожидаемый вывод (фрагмент):**

```
Certificate:
    Data:
        Version: 3 (0x2)
        ...
        Subject: CN = 45.63.121.41
        ...
        X509v3 extensions:
            X509v3 Subject Alternative Name:
                IP Address:45.63.121.41
```

### 2.3. Проверка срока действия

```bash
openssl x509 -in /etc/ssl/core/core.crt -noout -dates
```

**Ожидаемый вывод:**

```
notBefore=Jan 20 12:00:00 2026 GMT
notAfter=Jan 20 12:00:00 2027 GMT
```

---

## 3. Настройка прав доступа

```bash
# Ограничиваем доступ к приватному ключу
chmod 600 /etc/ssl/core/core.key
chmod 644 /etc/ssl/core/core.crt

# Владелец — root
chown root:root /etc/ssl/core/core.key
chown root:root /etc/ssl/core/core.crt

# Проверяем
ls -la /etc/ssl/core/
```

**Ожидаемый вывод:**

```
-rw-r--r-- 1 root root 1234 Jan 20 12:00 core.crt
-rw------- 1 root root 1704 Jan 20 12:00 core.key
```

---

## 4. Альтернатива: сертификат с большим сроком

Для долгоживущей Core-ноды можно увеличить срок действия:

```bash
# Сертификат на 5 лет
openssl req -x509 -nodes -days 1825 -newkey rsa:2048 \
  -keyout /etc/ssl/core/core.key \
  -out /etc/ssl/core/core.crt \
  -subj "/CN=45.63.121.41" \
  -addext "subjectAltName=IP:45.63.121.41"
```

---

## 5. Обновление сертификата

При истечении срока действия:

```bash
# Создаём резервную копию
cp /etc/ssl/core/core.crt /etc/ssl/core/core.crt.backup
cp /etc/ssl/core/core.key /etc/ssl/core/core.key.backup

# Генерируем новый сертификат
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/core/core.key \
  -out /etc/ssl/core/core.crt \
  -subj "/CN=45.63.121.41" \
  -addext "subjectAltName=IP:45.63.121.41"

# Перезапускаем Nginx
systemctl reload nginx
```

**Примечание:** Entry-нода использует `allowInsecure: true`, поэтому обновление сертификата на Core-ноде не требует изменений на Entry-ноде.

---

## 6. Будущее: Certificate Pinning

Для повышения безопасности можно использовать pinning вместо `allowInsecure`:

### 6.1. Получение fingerprint сертификата

```bash
# SHA-256 fingerprint
openssl x509 -in /etc/ssl/core/core.crt -pubkey -noout | \
  openssl pkey -pubin -outform der | \
  openssl dgst -sha256 -binary | \
  base64
```

### 6.2. Использование в Xray (Entry-нода)

```json
{
  "tlsSettings": {
    "allowInsecure": false,
    "pinnedPeerCertificateChainSha256": [
      "BASE64_FINGERPRINT_ЗДЕСЬ"
    ]
  }
}
```

**Преимущество:** Защита от MITM даже с самоподписанным сертификатом.

**Недостаток:** При обновлении сертификата нужно обновить fingerprint на всех Entry-нодах.

---

## 7. Чек-лист

- [ ] Сертификат создан: `/etc/ssl/core/core.crt`
- [ ] Приватный ключ создан: `/etc/ssl/core/core.key`
- [ ] Права доступа настроены (ключ: 600, сертификат: 644)
- [ ] Срок действия проверен
- [ ] Subject Alternative Name содержит IP-адрес

---

## Следующий шаг

→ [04-nginx-setup.md](./04-nginx-setup.md) — Установка и настройка Nginx

---

*Документ создан: 2026-01-20*
