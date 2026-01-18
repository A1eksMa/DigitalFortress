# Базовая настройка сервера Entry-ноды

**Статус:** Этап 1 (MVP)

---

## Предварительные требования

- VPS с root-доступом
- Ubuntu 22.04 или Debian 12
- Выделенный IPv4-адрес
- Домен, делегированный на IP сервера

---

## 1. Первое подключение

```bash
# Подключаемся как root
ssh root@<IP_ADDRESS>
```

---

## 2. Обновление системы

```bash
# Обновляем список пакетов
apt update

# Обновляем установленные пакеты
apt upgrade -y

# Устанавливаем базовые утилиты
apt install -y curl wget git ufw sudo
```

---

## 3. Создание пользователя

```bash
# Создаём пользователя (замените USERNAME на ваше имя)
adduser USERNAME

# Добавляем в группу sudo
usermod -aG sudo USERNAME

# Проверяем
id USERNAME
```

---

## 4. Настройка SSH-ключей

### На локальной машине

```bash
# Генерируем ключ (если ещё нет)
ssh-keygen -t ed25519 -C "entry-node-key"

# Копируем публичный ключ на сервер
ssh-copy-id -i ~/.ssh/id_ed25519.pub USERNAME@<IP_ADDRESS>

# Или вручную
cat ~/.ssh/id_ed25519.pub
# Скопируйте вывод
```

### На сервере

```bash
# Создаём директорию для ключей
mkdir -p /home/USERNAME/.ssh
chmod 700 /home/USERNAME/.ssh

# Добавляем публичный ключ
echo "ваш_публичный_ключ" >> /home/USERNAME/.ssh/authorized_keys
chmod 600 /home/USERNAME/.ssh/authorized_keys
chown -R USERNAME:USERNAME /home/USERNAME/.ssh
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

# Разрешаем HTTPS
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

## 8. Проверка DNS

Убедитесь, что домен указывает на IP сервера:

```bash
# На любой машине
dig your-domain.com +short
nslookup your-domain.com
```

**Ожидаемый результат:** IP-адрес вашего сервера.

---

## 9. Финальная проверка

```bash
# Проверяем открытые порты
ss -tlnp

# Проверяем файрвол
ufw status

# Проверяем SSH-подключение (с локальной машины)
ssh -i ~/.ssh/your_key USERNAME@<IP_ADDRESS>
```

---

## Чек-лист готовности

- [ ] Система обновлена
- [ ] Создан пользователь с sudo
- [ ] SSH-ключи настроены
- [ ] Вход по паролю отключён
- [ ] UFW настроен (порты 22, 443)
- [ ] Время синхронизировано (UTC)
- [ ] DNS делегирован на IP сервера

---

## Следующий шаг

→ [03-nginx-setup.md](./03-nginx-setup.md) — Установка Nginx и SSL-сертификата
