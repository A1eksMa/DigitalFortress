# Базовая настройка сервера Core-ноды

**Статус:** Этап 2

---

## Предварительные требования

- VPS с root-доступом
- Ubuntu 22.04 или Debian 12
- Выделенный IPv4-адрес

---

## 1. Первое подключение

```bash
# Подключаемся как root
ssh root@45.63.121.41
```

---

## 2. Обновление системы

```bash
# Обновляем список пакетов
apt update

# Обновляем установленные пакеты
apt upgrade -y

# Устанавливаем базовые утилиты
apt install -y curl wget git ufw sudo openssl
```

---

## 3. Создание пользователя

```bash
# Создаём пользователя
adduser coreuser

# Добавляем в группу sudo
usermod -aG sudo coreuser

# Проверяем
id coreuser
```

---

## 4. Настройка SSH-ключей

### На локальной машине

```bash
# Генерируем ключ (если ещё нет)
ssh-keygen -t ed25519 -C "core-node-key"

# Копируем публичный ключ на сервер
ssh-copy-id -i ~/.ssh/id_ed25519.pub coreuser@45.63.121.41
```

### На сервере

```bash
# Создаём директорию для ключей
mkdir -p /home/coreuser/.ssh
chmod 700 /home/coreuser/.ssh

# Добавляем публичный ключ (если копировали вручную)
echo "ваш_публичный_ключ" >> /home/coreuser/.ssh/authorized_keys
chmod 600 /home/coreuser/.ssh/authorized_keys
chown -R coreuser:coreuser /home/coreuser/.ssh
```

---

## 5. Усиление SSH

```bash
# Редактируем конфигурацию SSH
nano /etc/ssh/sshd_config
```

**Рекомендуемые настройки:**

```
# Отключаем вход по паролю
PasswordAuthentication no

# Отключаем вход root
PermitRootLogin no

# Используем только SSH протокол 2
Protocol 2

# Таймаут неактивности
ClientAliveInterval 300
ClientAliveCountMax 2
```

```bash
# Перезапускаем SSH
systemctl restart sshd
```

**Важно:** Перед отключением входа по паролю убедитесь, что SSH-ключ работает.

---

## 6. Настройка файрвола (UFW)

```bash
# Включаем UFW
ufw enable

# Разрешаем SSH
ufw allow 22/tcp

# Разрешаем HTTPS (для WebSocket от Entry-ноды)
ufw allow 443/tcp

# Проверяем статус
ufw status numbered
```

**Ожидаемый результат:**

```
Status: active

     To                         Action      From
     --                         ------      ----
[ 1] 22/tcp                     ALLOW IN    Anywhere
[ 2] 443/tcp                    ALLOW IN    Anywhere
[ 3] 22/tcp (v6)                ALLOW IN    Anywhere (v6)
[ 4] 443/tcp (v6)               ALLOW IN    Anywhere (v6)
```

### Опционально: ограничение доступа к 443

Если хотите разрешить подключение только с IP Entry-ноды:

```bash
# Удаляем общее правило
ufw delete allow 443/tcp

# Разрешаем только с IP Entry-ноды
ufw allow from 94.232.46.43 to any port 443 proto tcp

# Проверяем
ufw status numbered
```

**Примечание:** Это усилит безопасность, но затруднит добавление новых Entry-нод.

---

## 7. Настройка времени

```bash
# Устанавливаем часовой пояс UTC
timedatectl set-timezone UTC

# Синхронизируем время
apt install -y chrony
systemctl enable chrony
systemctl start chrony

# Проверяем
timedatectl
```

---

## 8. Создание директорий

```bash
# Директория для сайта-прикрытия
mkdir -p /var/www/core/html

# Директория для логов Xray
mkdir -p /var/log/xray

# Директория для сертификатов
mkdir -p /etc/ssl/core
```

---

## 9. Финальная проверка

```bash
# Проверяем открытые порты
ss -tlnp

# Проверяем файрвол
ufw status

# Проверяем SSH-подключение (с локальной машины)
ssh -i ~/.ssh/your_key coreuser@45.63.121.41
```

---

## Чек-лист готовности

- [ ] Система обновлена
- [ ] Создан пользователь с sudo
- [ ] SSH-ключи настроены
- [ ] Вход по паролю отключён
- [ ] UFW настроен (порты 22, 443)
- [ ] Время синхронизировано (UTC)
- [ ] Созданы директории для сайта, логов, сертификатов

---

## Следующий шаг

→ [03-certificates.md](./03-certificates.md) — Генерация самоподписанного сертификата

---

*Документ создан: 2026-01-20*
