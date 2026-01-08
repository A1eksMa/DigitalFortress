# Установка и настройка Nginx на Entry-ноде

**Версия:** 1.0
**Дата:** 2026-01-08
**Статус:** Этап 1 (MVP)
**Целевой сервер:** Entry-нода (202.223.48.9), Ubuntu 22.04

---

## Содержание

1. [Введение](#введение)
2. [Вариант 1: Традиционная установка (для MVP)](#вариант-1-традиционная-установка-для-mvp)
3. [Вариант 2: Docker-контейнер (для масштабирования)](#вариант-2-docker-контейнер-для-масштабирования)
4. [Проверка работоспособности](#проверка-работоспособности)
5. [Обслуживание и мониторинг](#обслуживание-и-мониторинг)

---

## Введение

Данный документ описывает процесс развертывания веб-сайта-прикрытия на Entry-ноде с использованием Nginx и SSL-сертификатов Let's Encrypt.

**Цель:**
- Разместить сайт-прикрытие по адресу https://mimimi.pro
- Настроить автоматическое обновление SSL-сертификатов
- Подготовить инфраструктуру для добавления Xray-туннеля

**Доступны два варианта:**
- **Вариант 1** (рекомендуется для Этапа 1): Традиционная установка на хост-систему
- **Вариант 2** (для Этапа 2+): Docker-контейнер для быстрого развертывания

---

## Вариант 1: Традиционная установка (для MVP)

### 1.1. Подключение к Entry-ноде

```bash
# Подключаемся по SSH с ключом
ssh -i ~/.ssh/your_key user@202.223.48.9
```

**Важно:** Убедитесь, что у пользователя есть права `sudo`.

---

### 1.2. Обновление системы

```bash
# Обновляем список пакетов
sudo apt update

# Обновляем установленные пакеты
sudo apt upgrade -y

# Устанавливаем необходимые утилиты
sudo apt install -y curl wget git ufw
```

---

### 1.3. Установка Nginx

```bash
# Устанавливаем Nginx
sudo apt install -y nginx

# Проверяем версию
nginx -v

# Запускаем и включаем автозапуск
sudo systemctl start nginx
sudo systemctl enable nginx

# Проверяем статус
sudo systemctl status nginx
```

**Ожидаемый результат:**
```
● nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/lib/systemd/system/nginx.service; enabled; vendor preset: enabled)
     Active: active (running)
```

---

### 1.4. Настройка файрвола (UFW)

```bash
# Проверяем статус UFW
sudo ufw status

# Разрешаем HTTP и HTTPS (временно, для получения сертификата)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Проверяем правила
sudo ufw status numbered
```

**Примечание:** Порт 22 (SSH) должен быть уже открыт согласно `entry-node-instance-config.md`.

---

### 1.5. Копирование сайта на сервер

#### 1.5.1. Создание директории для сайта

```bash
# Создаём директорию для сайта
sudo mkdir -p /var/www/mimimi.pro/html

# Устанавливаем правильные права
sudo chown -R $USER:$USER /var/www/mimimi.pro/html
sudo chmod -R 755 /var/www/mimimi.pro
```

#### 1.5.2. Копирование файлов с локальной машины

**На вашей локальной машине (Core-нода или компьютер разработчика):**

```bash
# Переходим в папку с проектом
cd /root/github/DigitalFortress

# Копируем сайт на Entry-ноду через SCP
scp -i ~/.ssh/your_key -r site/* user@202.223.48.9:/tmp/site/

# Или используем rsync (более надёжный вариант)
rsync -avz -e "ssh -i ~/.ssh/your_key" site/ user@202.223.48.9:/tmp/site/
```

**На Entry-ноде:**

```bash
# Перемещаем файлы в рабочую директорию
sudo cp -r /tmp/site/* /var/www/mimimi.pro/html/

# Проверяем структуру
ls -la /var/www/mimimi.pro/html/
```

**Ожидаемая структура:**
```
/var/www/mimimi.pro/html/
├── index.html
└── assets/
    ├── logo.svg
    ├── login-image.svg
    ├── girl-01.svg
    ├── girl-02.svg
    ... (остальные SVG)
```

#### 1.5.3. Альтернатива: Клонирование из Git-репозитория

Если сайт находится в репозитории:

```bash
# Клонируем репозиторий во временную директорию
git clone https://github.com/A1eksMa/DigitalFortress.git /tmp/digitalfortress

# Копируем только сайт
sudo cp -r /tmp/digitalfortress/site/* /var/www/mimimi.pro/html/

# Удаляем временную директорию
rm -rf /tmp/digitalfortress
```

---

### 1.6. Настройка Nginx-конфигурации

#### 1.6.1. Создание конфигурации для сайта

```bash
# Создаём файл конфигурации
sudo nano /etc/nginx/sites-available/mimimi.pro
```

**Содержимое файла (до получения SSL-сертификата):**

```nginx
server {
    listen 80;
    listen [::]:80;

    server_name mimimi.pro www.mimimi.pro;

    root /var/www/mimimi.pro/html;
    index index.html;

    # Логи
    access_log /var/log/nginx/mimimi.pro_access.log;
    error_log /var/log/nginx/mimimi.pro_error.log;

    location / {
        try_files $uri $uri/ =404;
    }

    # Кэширование статики
    location ~* \.(svg|jpg|jpeg|png|gif|ico|css|js)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
}
```

#### 1.6.2. Активация конфигурации

```bash
# Создаём символическую ссылку
sudo ln -s /etc/nginx/sites-available/mimimi.pro /etc/nginx/sites-enabled/

# Удаляем дефолтную конфигурацию (опционально)
sudo rm /etc/nginx/sites-enabled/default

# Проверяем синтаксис конфигурации
sudo nginx -t
```

**Ожидаемый результат:**
```
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

#### 1.6.3. Перезапуск Nginx

```bash
# Перезагружаем конфигурацию
sudo systemctl reload nginx

# Или перезапускаем полностью
sudo systemctl restart nginx
```

---

### 1.7. Проверка DNS-записи

**Перед получением SSL-сертификата убедитесь, что домен указывает на IP Entry-ноды:**

```bash
# На любой машине проверяем DNS-запись
dig mimimi.pro +short
nslookup mimimi.pro
```

**Ожидаемый результат:**
```
202.223.48.9
```

**Если DNS ещё не обновился:**
- Подождите 5-30 минут (в зависимости от TTL)
- Проверьте настройки в панели регистратора домена

---

### 1.8. Получение SSL-сертификата (Let's Encrypt)

#### 1.8.1. Установка Certbot

```bash
# Устанавливаем Certbot и плагин для Nginx
sudo apt install -y certbot python3-certbot-nginx
```

#### 1.8.2. Получение сертификата

```bash
# Запускаем Certbot в интерактивном режиме
sudo certbot --nginx -d mimimi.pro -d www.mimimi.pro

# Или неинтерактивный режим с автоматическими ответами
sudo certbot --nginx -d mimimi.pro -d www.mimimi.pro \
  --non-interactive \
  --agree-tos \
  --email your-email@example.com \
  --redirect
```

**Параметры:**
- `--nginx` — автоматически модифицирует конфиг Nginx
- `-d mimimi.pro -d www.mimimi.pro` — домены для сертификата
- `--redirect` — автоматическое перенаправление HTTP → HTTPS
- `--agree-tos` — согласие с условиями Let's Encrypt
- `--email` — ваш email для уведомлений

**Ожидаемый результат:**
```
Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/mimimi.pro/fullchain.pem
Key is saved at:         /etc/letsencrypt/live/mimimi.pro/privkey.pem
```

#### 1.8.3. Проверка обновлённой конфигурации Nginx

```bash
# Просматриваем изменённый конфиг
sudo cat /etc/nginx/sites-available/mimimi.pro
```

**Certbot автоматически добавит блок для HTTPS:**

```nginx
server {
    server_name mimimi.pro www.mimimi.pro;

    root /var/www/mimimi.pro/html;
    index index.html;

    access_log /var/log/nginx/mimimi.pro_access.log;
    error_log /var/log/nginx/mimimi.pro_error.log;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~* \.(svg|jpg|jpeg|png|gif|ico|css|js)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    listen [::]:443 ssl ipv6only=on; # managed by Certbot
    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/mimimi.pro/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/mimimi.pro/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot
}

server {
    if ($host = www.mimimi.pro) {
        return 301 https://$host$request_uri;
    } # managed by Certbot

    if ($host = mimimi.pro) {
        return 301 https://$host$request_uri;
    } # managed by Certbot

    listen 80;
    listen [::]:80;

    server_name mimimi.pro www.mimimi.pro;
    return 404; # managed by Certbot
}
```

---

### 1.9. Настройка автоматического обновления сертификатов

Let's Encrypt сертификаты действительны 90 дней. Certbot автоматически создаёт cronjob для обновления.

#### 1.9.1. Проверка таймера обновления

```bash
# Проверяем наличие таймера systemd
sudo systemctl list-timers | grep certbot

# Или проверяем статус
sudo systemctl status certbot.timer
```

**Ожидаемый результат:**
```
● certbot.timer - Run certbot twice daily
     Loaded: loaded
     Active: active (waiting)
```

#### 1.9.2. Тестирование обновления

```bash
# Симуляция обновления (dry-run)
sudo certbot renew --dry-run
```

**Ожидаемый результат:**
```
Congratulations, all simulated renewals succeeded
```

#### 1.9.3. Ручное обновление (если нужно)

```bash
# Обновить все сертификаты
sudo certbot renew

# Обновить конкретный сертификат
sudo certbot renew --cert-name mimimi.pro
```

---

### 1.10. Финальная проверка и тюнинг безопасности

#### 1.10.1. Улучшение SSL-конфигурации (опционально)

Добавим дополнительные заголовки безопасности:

```bash
sudo nano /etc/nginx/sites-available/mimimi.pro
```

**Добавьте в блок `server { listen 443 ssl; ... }`:**

```nginx
    # Дополнительные заголовки безопасности
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
```

#### 1.10.2. Перезагрузка Nginx

```bash
sudo nginx -t && sudo systemctl reload nginx
```

---

### 1.11. Закрытие порта 80 в UFW (опционально)

Если вы хотите, чтобы сайт был доступен только по HTTPS:

```bash
# Удаляем правило для порта 80
sudo ufw delete allow 80/tcp

# Проверяем
sudo ufw status numbered
```

**Примечание:** HTTP→HTTPS редирект всё равно будет работать, но сайт станет недоступен по чистому HTTP извне. Для Certbot автообновления порт 80 не обязателен (используется порт 443 с TLS-ALPN-01 challenge).

---

## Вариант 2: Docker-контейнер (для масштабирования)

**Преимущества Docker-подхода:**
- Быстрое развертывание на новых Entry-нодах
- Изолированная среда
- Простая репликация и ротация нод
- Версионирование конфигураций

**Когда использовать:**
- Этап 2 (масштабирование): при наличии 3+ Entry-нод
- Автоматизация деплоя (Terraform, Ansible)

---

### 2.1. Установка Docker и Docker Compose

```bash
# Обновляем систему
sudo apt update

# Устанавливаем зависимости
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

# Добавляем GPG-ключ Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Добавляем репозиторий Docker
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Устанавливаем Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Добавляем пользователя в группу docker
sudo usermod -aG docker $USER

# Перелогиниваемся или используем
newgrp docker

# Проверяем установку
docker --version
docker compose version
```

---

### 2.2. Создание структуры проекта

```bash
# Создаём директорию проекта
mkdir -p ~/entry-node-docker
cd ~/entry-node-docker

# Создаём поддиректории
mkdir -p site nginx/conf.d certbot/conf certbot/www
```

**Структура:**
```
~/entry-node-docker/
├── docker-compose.yml
├── site/
│   ├── index.html
│   └── assets/
│       └── *.svg
├── nginx/
│   └── conf.d/
│       └── mimimi.pro.conf
├── certbot/
│   ├── conf/       # Сертификаты Let's Encrypt
│   └── www/        # Webroot для ACME challenge
└── init-letsencrypt.sh
```

---

### 2.3. Копирование сайта

```bash
# Копируем сайт из репозитория или с локальной машины
# Вариант 1: SCP с локальной машины
scp -r /root/github/DigitalFortress/site/* user@202.223.48.9:~/entry-node-docker/site/

# Вариант 2: Git clone на сервере
git clone https://github.com/A1eksMa/DigitalFortress.git /tmp/df
cp -r /tmp/df/site/* ~/entry-node-docker/site/
rm -rf /tmp/df
```

---

### 2.4. Создание Nginx-конфигурации

```bash
nano ~/entry-node-docker/nginx/conf.d/mimimi.pro.conf
```

**Содержимое файла:**

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name mimimi.pro www.mimimi.pro;

    # ACME challenge для Let's Encrypt
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # Редирект на HTTPS
    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name mimimi.pro www.mimimi.pro;

    # SSL сертификаты
    ssl_certificate /etc/letsencrypt/live/mimimi.pro/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/mimimi.pro/privkey.pem;

    # SSL конфигурация
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';

    # Заголовки безопасности
    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    # Корневая директория
    root /var/www/html;
    index index.html;

    # Логи
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    location / {
        try_files $uri $uri/ =404;
    }

    # Кэширование статики
    location ~* \.(svg|jpg|jpeg|png|gif|ico|css|js)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
}
```

---

### 2.5. Создание docker-compose.yml

```bash
nano ~/entry-node-docker/docker-compose.yml
```

**Содержимое файла:**

```yaml
version: '3.8'

services:
  nginx:
    image: nginx:alpine
    container_name: entry-node-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./site:/var/www/html:ro
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./certbot/conf:/etc/letsencrypt:ro
      - ./certbot/www:/var/www/certbot:ro
    networks:
      - entry-network
    depends_on:
      - certbot

  certbot:
    image: certbot/certbot
    container_name: entry-node-certbot
    restart: unless-stopped
    volumes:
      - ./certbot/conf:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait $${!}; done;'"
    networks:
      - entry-network

networks:
  entry-network:
    driver: bridge
```

---

### 2.6. Скрипт для первичного получения сертификата

```bash
nano ~/entry-node-docker/init-letsencrypt.sh
chmod +x ~/entry-node-docker/init-letsencrypt.sh
```

**Содержимое скрипта:**

```bash
#!/bin/bash

DOMAIN="mimimi.pro"
EMAIL="your-email@example.com"  # Замените на ваш email
STAGING=0  # Установите 1 для тестового режима

# Создаём временный nginx конфиг без SSL
cat > nginx/conf.d/temp.conf <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN www.$DOMAIN;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        root /var/www/html;
        index index.html;
    }
}
EOF

# Удаляем основной конфиг временно
mv nginx/conf.d/mimimi.pro.conf nginx/conf.d/mimimi.pro.conf.bak

# Запускаем только nginx
docker compose up -d nginx

echo "### Получение сертификата для $DOMAIN ..."

# Staging или production
if [ $STAGING != "0" ]; then
  STAGING_ARG="--staging"
fi

# Получаем сертификат
docker compose run --rm certbot certonly \
  --webroot \
  --webroot-path=/var/www/certbot \
  --email $EMAIL \
  --agree-tos \
  --no-eff-email \
  $STAGING_ARG \
  -d $DOMAIN \
  -d www.$DOMAIN

# Восстанавливаем основной конфиг
rm nginx/conf.d/temp.conf
mv nginx/conf.d/mimimi.pro.conf.bak nginx/conf.d/mimimi.pro.conf

# Перезапускаем с полным конфигом
docker compose down
docker compose up -d

echo "### Сертификат получен! Nginx запущен с HTTPS."
```

---

### 2.7. Запуск Docker-контейнеров

```bash
cd ~/entry-node-docker

# Первичный запуск: получение сертификата
./init-letsencrypt.sh

# Проверка логов
docker compose logs -f nginx
docker compose logs -f certbot

# Проверка статуса
docker compose ps
```

**Ожидаемый результат:**
```
NAME                   STATUS    PORTS
entry-node-nginx       Up        0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp
entry-node-certbot     Up
```

---

### 2.8. Управление контейнерами

```bash
# Остановить все сервисы
docker compose down

# Запустить все сервисы
docker compose up -d

# Перезапустить nginx
docker compose restart nginx

# Просмотр логов
docker compose logs -f

# Обновление сайта (после изменения файлов)
docker compose restart nginx
```

---

### 2.9. Ручное обновление сертификата

```bash
# Запустить обновление вручную
docker compose run --rm certbot renew

# Перезагрузить nginx после обновления
docker compose restart nginx
```

---

## Проверка работоспособности

### 3.1. Проверка HTTP → HTTPS редиректа

```bash
# Должен вернуть 301 редирект
curl -I http://mimimi.pro

# Должен вернуть 200 OK
curl -I https://mimimi.pro
```

### 3.2. Проверка SSL-сертификата

```bash
# Проверка срока действия сертификата
echo | openssl s_client -servername mimimi.pro -connect mimimi.pro:443 2>/dev/null | openssl x509 -noout -dates

# Или через онлайн-сервис
# https://www.ssllabs.com/ssltest/analyze.html?d=mimimi.pro
```

### 3.3. Проверка загрузки сайта

**В браузере:**
1. Откройте https://mimimi.pro
2. Проверьте, что:
   - Сертификат валиден (зелёный замок)
   - Сайт загружается полностью
   - Все изображения отображаются
   - Навигация работает

**Из терминала:**

```bash
# Проверка размера загруженной страницы
curl -s https://mimimi.pro | wc -c

# Должно быть >16000 байт (16 КБ)
```

### 3.4. Проверка логов

```bash
# Традиционная установка
sudo tail -f /var/log/nginx/mimimi.pro_access.log
sudo tail -f /var/log/nginx/mimimi.pro_error.log

# Docker
docker compose logs -f nginx
```

---

## Обслуживание и мониторинг

### 4.1. Мониторинг статуса Nginx

**Традиционная установка:**

```bash
# Статус сервиса
sudo systemctl status nginx

# Проверка конфигурации
sudo nginx -t
```

**Docker:**

```bash
# Статус контейнеров
docker compose ps

# Проверка конфигурации
docker compose exec nginx nginx -t
```

### 4.2. Обновление сайта

**Традиционная установка:**

```bash
# Копируем новые файлы
sudo cp -r /path/to/new/site/* /var/www/mimimi.pro/html/

# Перезагружаем nginx
sudo systemctl reload nginx
```

**Docker:**

```bash
# Копируем новые файлы
cp -r /path/to/new/site/* ~/entry-node-docker/site/

# Перезапускаем контейнер
docker compose restart nginx
```

### 4.3. Ротация логов

**Традиционная установка:**

Logrotate настроен автоматически при установке Nginx.

Проверка:

```bash
cat /etc/logrotate.d/nginx
```

**Docker:**

Добавьте в `docker-compose.yml` параметры логирования:

```yaml
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

### 4.4. Резервное копирование

**Что нужно сохранять:**

```bash
# Сайт
/var/www/mimimi.pro/html/
# или ~/entry-node-docker/site/

# Конфигурация Nginx
/etc/nginx/sites-available/mimimi.pro
# или ~/entry-node-docker/nginx/conf.d/

# SSL-сертификаты (опционально, можно перевыпустить)
/etc/letsencrypt/
# или ~/entry-node-docker/certbot/conf/
```

**Скрипт резервного копирования (традиционная установка):**

```bash
#!/bin/bash
BACKUP_DIR="/backup/entry-node-$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

# Копируем сайт
cp -r /var/www/mimimi.pro/html $BACKUP_DIR/site

# Копируем конфиг Nginx
cp /etc/nginx/sites-available/mimimi.pro $BACKUP_DIR/nginx.conf

# Копируем сертификаты
sudo cp -r /etc/letsencrypt $BACKUP_DIR/letsencrypt

# Архивируем
tar -czf /backup/entry-node-backup-$(date +%Y%m%d).tar.gz $BACKUP_DIR
rm -rf $BACKUP_DIR

echo "Backup completed: /backup/entry-node-backup-$(date +%Y%m%d).tar.gz"
```

---

## Заключение

После выполнения инструкций у вас будет:

✅ Работающий Nginx с сайтом-прикрытием
✅ Валидный SSL-сертификат от Let's Encrypt
✅ Автоматическое обновление сертификатов
✅ HTTPS-доступ к https://mimimi.pro
✅ Готовая инфраструктура для добавления Xray-туннеля

**Следующие шаги:**
1. Установка Xray-core на Entry-ноду
2. Настройка VLESS inbound для клиентских подключений
3. Настройка туннеля Entry → Core
4. Тестирование полной цепочки подключения

---

## Приложение A: Troubleshooting

### Проблема: Certbot не может получить сертификат

**Решение:**

```bash
# Проверьте DNS
dig mimimi.pro +short

# Проверьте доступность порта 80
sudo netstat -tlnp | grep :80

# Проверьте файрвол
sudo ufw status

# Попробуйте вручную
sudo certbot certonly --standalone -d mimimi.pro
```

### Проблема: Nginx не запускается

**Решение:**

```bash
# Проверьте синтаксис конфига
sudo nginx -t

# Проверьте логи
sudo journalctl -u nginx -n 50

# Проверьте порты
sudo netstat -tlnp | grep nginx
```

### Проблема: Сайт недоступен по HTTPS

**Решение:**

```bash
# Проверьте, что Nginx слушает 443
sudo netstat -tlnp | grep :443

# Проверьте файрвол
sudo ufw status

# Проверьте сертификаты
sudo ls -la /etc/letsencrypt/live/mimimi.pro/

# Проверьте конфигурацию SSL
sudo nginx -T | grep ssl
```

---

*Документ подготовлен для развертывания сайта-прикрытия на Entry-ноде. Обновляется по мере внедрения дополнительных компонентов.*
