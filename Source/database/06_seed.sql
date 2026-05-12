TRUNCATE audit_log, stock_movement, detail, warehouse, supplier, material, category, users RESTART IDENTITY CASCADE;

INSERT INTO users(login, full_name, email, password_hash, role) VALUES
('admin',   'Администратор Системы',  'admin@detal.local',   '$2y$12$XaaktxtvIRMWd5hgZwdq2uGGNSDA6AkXn4oiGNtsNo/JUuPhidi3O', 'admin'),
('manager', 'Иванов Иван Иванович',   'manager@detal.local', '$2y$12$I0ctxvDa6IcgmrXq7Ljq0eNkyKgYk76Cq/v20DB9qxhzfnKnH23EC', 'manager'),
('petrov',  'Петров Пётр Петрович',   'petrov@detal.local',  '$2y$12$zCBWeQg0hH0pIkFYJkahp.uNDtqWmq7mXPkZGBuSX5OMh4InDqPd.', 'storekeeper'),
('zommer',  'Зоммер Андрей Алексеевич','zommer@detal.local', '$2y$12$XMMq8CDVKDXvE6aTBmdIzummWfN1l89XhEZAo1GAntokVeN.q3yKS', 'storekeeper');

INSERT INTO category(name, parent_id) VALUES
('Корпусные детали', NULL),
('Валы и оси',       NULL),
('Зубчатые колёса',  NULL),
('Крепёж',           NULL),
('Подшипники',       NULL);

INSERT INTO category(name, parent_id) VALUES
('Корпуса редукторов',    1),
('Крышки подшипниковые',  1),
('Валы приводные',        2),
('Оси гладкие',           2),
('Шестерни цилиндрические', 3),
('Шестерни конические',   3),
('Болты',                 4),
('Гайки',                 4);

INSERT INTO material(name, grade, density_kg_m3) VALUES
('Сталь 45',     '45',       7850.00),
('Сталь 40Х',    '40Х',      7820.00),
('Чугун СЧ20',   'СЧ20',     7200.00),
('Бронза БрАЖ',  'БрАЖ9-4',  7600.00),
('Алюминий АД1', 'АД1',      2710.00),
('Полиамид ПА6', 'ПА6',      1140.00);

INSERT INTO supplier(name, inn, phone, email) VALUES
('ООО «МеталлПром»',     '7701234567', '+7 (495) 111-22-33', 'sales@metallprom.ru'),
('АО «Промстальсервис»', '7702345678', '+7 (495) 222-33-44', 'order@promstal.ru'),
('ООО «РТИ-Поставка»',   '7703456789', '+7 (495) 333-44-55', 'rti@postavka.ru'),
('ИП Сидоров А.Г.',      '770456789012','+7 (916) 444-55-66', 'sidorov@yandex.ru');

INSERT INTO warehouse(code, name, address) VALUES
('SKL-01', 'Главный склад',           'г. Москва, Ленинский пр., 4'),
('SKL-02', 'Цеховой склад',           'г. Москва, Ленинский пр., 4, корп. 2'),
('SKL-03', 'Склад готовой продукции', 'г. Москва, Ленинский пр., 4, корп. 3');

INSERT INTO detail(article, name, category_id, material_id, weight_kg, unit, price, drawing_no, min_stock) VALUES
('K-100-01',  'Корпус редуктора Ц2У-200',          6,  3,  18.500, 'шт',   12500.00, 'РЕД-200-01', 5),
('K-100-02',  'Корпус редуктора Ц2У-300',          6,  3,  28.200, 'шт',   18900.00, 'РЕД-300-01', 3),
('KR-200-01', 'Крышка подшипниковая 200',          7,  3,   2.400, 'шт',    1850.00, 'КР-200',     20),
('V-300-01',  'Вал приводной L=420 d=40',          8,  1,   4.150, 'шт',    3200.00, 'В-420-40',   15),
('V-300-02',  'Вал приводной L=600 d=50',          8,  2,   8.900, 'шт',    5800.00, 'В-600-50',   10),
('O-310-01',  'Ось гладкая d=30 L=200',            9,  1,   1.100, 'шт',     720.00, 'О-30-200',   30),
('SH-400-01', 'Шестерня Z=24 m=2',                 10, 2,   1.250, 'шт',    2400.00, 'Ш-24-2',     20),
('SH-400-02', 'Шестерня Z=40 m=3',                 10, 2,   3.150, 'шт',    4100.00, 'Ш-40-3',     15),
('SH-400-03', 'Шестерня Z=60 m=4',                 10, 2,   6.400, 'шт',    7200.00, 'Ш-60-4',     8),
('SHK-410-01','Шестерня коническая Z=18 m=3',      11, 2,   1.900, 'шт',    3800.00, 'ШК-18-3',    10),
('B-500-01',  'Болт М10х40 ГОСТ 7798',             12, 1,   0.045, 'шт',      18.00, '7798',       500),
('B-500-02',  'Болт М12х50 ГОСТ 7798',             12, 1,   0.078, 'шт',      24.00, '7798',       400),
('B-500-03',  'Болт М16х80 ГОСТ 7798',             12, 1,   0.220, 'шт',      48.00, '7798',       200),
('G-510-01',  'Гайка М10 ГОСТ 5915',               13, 1,   0.012, 'шт',       8.00, '5915',       800),
('G-510-02',  'Гайка М12 ГОСТ 5915',               13, 1,   0.020, 'шт',      12.00, '5915',       600),
('KP-220-01', 'Крышка фланцевая d=120',            7,  4,   1.800, 'шт',    2900.00, 'КП-120',     12),
('VTL-001',   'Втулка подшипниковая d20x30',       6,  4,   0.150, 'шт',     420.00, 'ВТЛ-20-30',  60),
('STKN-1',    'Стакан подшипниковый Ц2У-200',      6,  3,   3.200, 'шт',    2150.00, 'СТ-200',     14);

INSERT INTO stock_movement(detail_id, warehouse_id, supplier_id, movement_type, quantity, price_per_unit, moved_at, user_id, comment) VALUES
(1,  1, 1, 'IN',  10, 12000.00, NOW() - INTERVAL '45 days', 3, 'Партия №1'),
(2,  1, 1, 'IN',   8, 18500.00, NOW() - INTERVAL '45 days', 3, 'Партия №1'),
(3,  1, 1, 'IN', 100,  1800.00, NOW() - INTERVAL '40 days', 3, NULL),
(4,  1, 2, 'IN',  40,  3100.00, NOW() - INTERVAL '40 days', 3, NULL),
(5,  1, 2, 'IN',  30,  5700.00, NOW() - INTERVAL '40 days', 3, NULL),
(6,  1, 2, 'IN', 120,   700.00, NOW() - INTERVAL '38 days', 3, NULL),
(7,  1, 2, 'IN',  80,  2300.00, NOW() - INTERVAL '38 days', 3, NULL),
(8,  1, 2, 'IN',  50,  4000.00, NOW() - INTERVAL '38 days', 3, NULL),
(9,  1, 2, 'IN',  25,  7100.00, NOW() - INTERVAL '38 days', 3, NULL),
(10, 1, 2, 'IN',  30,  3700.00, NOW() - INTERVAL '38 days', 3, NULL),
(11, 1, 3, 'IN', 2000,   17.50, NOW() - INTERVAL '30 days', 3, 'Метизы'),
(12, 1, 3, 'IN', 1500,   23.00, NOW() - INTERVAL '30 days', 3, 'Метизы'),
(13, 1, 3, 'IN',  800,   47.00, NOW() - INTERVAL '30 days', 3, 'Метизы'),
(14, 1, 3, 'IN', 3000,    7.50, NOW() - INTERVAL '30 days', 3, 'Метизы'),
(15, 1, 3, 'IN', 2500,   11.50, NOW() - INTERVAL '30 days', 3, 'Метизы'),
(16, 1, 4, 'IN',  40,  2850.00, NOW() - INTERVAL '25 days', 3, NULL),
(17, 1, 4, 'IN', 200,   400.00, NOW() - INTERVAL '25 days', 3, NULL),
(18, 1, 1, 'IN',  30,  2100.00, NOW() - INTERVAL '20 days', 3, NULL),

(11, 1, NULL, 'OUT', 200, NULL, NOW() - INTERVAL '15 days', 3, 'Сборка партии редукторов'),
(12, 1, NULL, 'OUT', 180, NULL, NOW() - INTERVAL '15 days', 3, 'Сборка партии редукторов'),
(14, 1, NULL, 'OUT', 200, NULL, NOW() - INTERVAL '15 days', 3, 'Сборка партии редукторов'),
(15, 1, NULL, 'OUT', 180, NULL, NOW() - INTERVAL '15 days', 3, 'Сборка партии редукторов'),
(4,  1, NULL, 'OUT',   8, NULL, NOW() - INTERVAL '14 days', 3, 'В производство'),
(7,  1, NULL, 'OUT',  12, NULL, NOW() - INTERVAL '14 days', 3, 'В производство'),
(3,  1, NULL, 'OUT',  15, NULL, NOW() - INTERVAL '12 days', 3, 'В сборку'),

(1,  1, NULL, 'TRANSFER_OUT', 4, NULL, NOW() - INTERVAL '10 days', 3, 'Перемещение на склад #2'),
(1,  2, NULL, 'TRANSFER_IN',  4, NULL, NOW() - INTERVAL '10 days', 3, 'Перемещение со склада #1'),
(4,  1, NULL, 'TRANSFER_OUT', 10, NULL, NOW() - INTERVAL '9 days', 3, 'Перемещение на склад #2'),
(4,  2, NULL, 'TRANSFER_IN',  10, NULL, NOW() - INTERVAL '9 days', 3, 'Перемещение со склада #1'),
(7,  1, NULL, 'TRANSFER_OUT', 25, NULL, NOW() - INTERVAL '8 days', 3, 'Перемещение на склад #2'),
(7,  2, NULL, 'TRANSFER_IN',  25, NULL, NOW() - INTERVAL '8 days', 3, 'Перемещение со склада #1'),

(1,  2, NULL, 'OUT', 2, NULL, NOW() - INTERVAL '5 days', 4, 'Со склада №2 в сборочный участок'),
(4,  2, NULL, 'OUT', 5, NULL, NOW() - INTERVAL '4 days', 4, 'Сборка изделия №47'),
(7,  2, NULL, 'OUT', 10, NULL, NOW() - INTERVAL '3 days', 4, 'Сборка изделия №47'),
(13, 1, NULL, 'OUT', 50, NULL, NOW() - INTERVAL '2 days', 4, 'Цех №3');
