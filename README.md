# folder_simple_backup

Простой Docker-контейнер для backup указанной директории в `tar.gz` архивы с cron-расписанием и compact retention-конфигом.

## Что умеет

- По расписанию архивирует директорию через `tar`
- Сохраняет backup в `*.tar.gz`
- Поддерживает retention через `KEEP_HOURLY`, `KEEP_DAILY`, `KEEP_WEEKLY`, `KEEP_MONTHLY`, `KEEP_YEARLY`
- Если `KEEP_*` не заданы, ничего не удаляет
- Конфигурируется через один `.env`

## Быстрый старт

```bash
cp .env.example .env
mkdir -p source backups
docker compose up -d --build
```

## Основные настройки

- `SOURCE_PATH` - путь на хосте до директории, которую нужно архивировать
- `SOURCE_DIR` - путь внутри контейнера, куда монтируется исходная директория
- `CRON` - cron-выражение, например `0 2 * * *`
- `BACKUP_DIR` - путь внутри контейнера для архивов
- `KEEP_HOURLY`, `KEEP_DAILY`, `KEEP_WEEKLY`, `KEEP_MONTHLY`, `KEEP_YEARLY` - сколько периодов хранить
- `TAR_EXTRA_OPTS` - дополнительные флаги для `tar`

## Как работает retention

- Для каждого периода сохраняется последний backup в этом периоде
- Backup сохраняется, если он попал хотя бы под одно правило retention
- Пустое значение `KEEP_*` означает "не ограничивать этот тип retention"
- Если все `KEEP_*` пустые, сохраняются все backup-файлы

Пример:

- `KEEP_HOURLY=24` - оставить последние 24 часа
- `KEEP_DAILY=7` - оставить последние 7 дней
- `KEEP_WEEKLY=8` - дополнительно оставить последние 8 недель
- `KEEP_MONTHLY=12` - дополнительно оставить последние 12 месяцев

## Ручной запуск backup

```bash
docker compose exec folder-backup /app/backup.sh
```

## Тестовый стенд

Есть отдельный `compose` с тестовой директорией и backup-контейнером.

Запуск:

```bash
docker compose -f docker-compose.test.yml up -d --build
```

Для ручного теста backup:

```bash
docker compose -f docker-compose.test.yml exec folder-backup /app/backup.sh
ls -la ./test_backups
tar -tzf ./test_backups/*.tar.gz
```

## Тесты

Есть shell-тесты для `backup.sh` и `retention.sh`.

Запуск:

```bash
docker build -t folder_simple_backup:test .
docker run --rm -v "$PWD":/app -w /app --entrypoint bash folder_simple_backup:test tests/retention_test.sh
docker run --rm -v "$PWD":/app -w /app --entrypoint bash folder_simple_backup:test tests/backup_test.sh
```
