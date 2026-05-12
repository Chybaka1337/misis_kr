# Курсовая работа «Учёт деталей предприятия»

Группа: БИВТ-22-ИСАД-1
Студент: Зоммер Андрей Алексеевич
Вариант: 4
Дисциплина: Разработка клиент-серверных приложений
Год: 2026

Git-репозиторий: https://github.com/Chybaka1337/misis_kr

## Состав каталога

```
БИВТ-22-ИСАД-1_ЗоммерАА_4_Деталь/
├── DB/
│   ├── BIVT-22-ISAD-1_Zommer_AA_4.bak   — бэкап PostgreSQL (custom format)
│   └── BIVT-22-ISAD-1_Zommer_AA_4.sql   — текстовый SQL-дамп
├── Documents/
│   ├── Documents.docx                   — пояснительная записка
│   └── Documents.pdf                    — она же в формате PDF
├── Source/
│   ├── database/                        — миграции и сид-данные
│   ├── backend/                         — PHP REST API
│   └── frontend/                        — React SPA на Vite
└── README.md
```

## Технологический стек

| Уровень       | Стек                                                |
|---------------|-----------------------------------------------------|
| СУБД          | PostgreSQL 17                                       |
| Серверная     | PHP 8.5 + PDO_pgsql, JWT (HS256), без фреймворков   |
| Клиентская    | React 19, Vite 5, react-router-dom, LocalStorage    |

## Учётные записи для входа

| Логин   | Пароль       | Роль          |
|---------|--------------|---------------|
| admin   | admin2026    | администратор |
| manager | manager2026  | менеджер      |
| petrov  | ivanov2026   | кладовщик     |
| zommer  | zommer2026   | кладовщик     |

## Развёртывание

### 1. Восстановление базы данных

```bash
createdb -h 127.0.0.1 -U postgres misis_kr_detail
pg_restore -h 127.0.0.1 -U postgres -d misis_kr_detail DB/BIVT-22-ISAD-1_Zommer_AA_4.bak
```

либо последовательно применить SQL-скрипты:

```bash
psql -h 127.0.0.1 -U postgres -d misis_kr_detail \
    -f Source/database/01_schema.sql \
    -f Source/database/02_views.sql \
    -f Source/database/03_functions.sql \
    -f Source/database/04_procedures.sql \
    -f Source/database/05_triggers.sql \
    -f Source/database/06_seed.sql
```

### 2. Запуск REST API

В `Source/backend/config.php` указаны параметры подключения к БД и
секрет JWT. По умолчанию ожидается PostgreSQL на 127.0.0.1:5433
с пользователем postgres и паролем kursovaya2026.

```bash
cd Source/backend
php -S 127.0.0.1:8001 -t . api/index.php
```

### 3. Запуск фронтенда

```bash
cd Source/frontend
npm install
npm run dev -- --port 5190
```

Открыть http://127.0.0.1:5190.

## REST API: основные эндпоинты

| Метод   | URL                              | Назначение                            |
|---------|----------------------------------|---------------------------------------|
| POST    | /api/v1/auth/login               | Авторизация                           |
| GET     | /api/v1/auth/me                  | Текущий пользователь                  |
| GET     | /api/v1/details                  | Список деталей                        |
| GET     | /api/v1/details/{id}             | Карточка детали                       |
| POST    | /api/v1/details                  | Создание (admin / manager)            |
| PUT     | /api/v1/details/{id}             | Обновление                            |
| DELETE  | /api/v1/details/{id}             | Удаление                              |
| GET     | /api/v1/movements                | Журнал движений                       |
| POST    | /api/v1/movements/receive        | Приход                                |
| POST    | /api/v1/movements/issue          | Расход                                |
| POST    | /api/v1/movements/transfer       | Перемещение                           |
| GET     | /api/v1/categories               | Справочник категорий                  |
| GET     | /api/v1/materials                | Справочник материалов                 |
| GET     | /api/v1/suppliers                | Справочник поставщиков                |
| GET     | /api/v1/warehouses               | Справочник складов                    |
| GET     | /api/v1/reports/stock            | Остатки (v_detail_stock)              |
| GET     | /api/v1/reports/low-stock        | Дефицитные позиции (v_low_stock)      |
| GET     | /api/v1/reports/suppliers        | Закупки (v_supplier_purchases)        |
| GET     | /api/v1/reports/warehouse-value  | Стоимость остатков по складам         |
| GET     | /api/v1/reports/consumption      | Расход за период                      |

## Объекты базы данных

- 8 таблиц (`users`, `category`, `material`, `supplier`, `warehouse`,
  `detail`, `stock_movement`, `audit_log`);
- 4 представления (`v_detail_stock`, `v_low_stock`,
  `v_supplier_purchases`, `v_recent_movements`);
- 4 функции (`fn_stock_balance`, `fn_warehouse_value`,
  `fn_detail_consumption`, `fn_category_descendants`);
- 4 хранимые процедуры (`sp_receive_detail`, `sp_issue_detail`,
  `sp_transfer_detail`, `sp_register_user`);
- 3 триггера (`tg_validate_movement`, `tg_detail_touch_updated_at`,
  `tg_audit_detail`).
