CREATE OR REPLACE PROCEDURE sp_receive_detail(
    p_detail_id     INTEGER,
    p_warehouse_id  INTEGER,
    p_supplier_id   INTEGER,
    p_quantity      INTEGER,
    p_price         NUMERIC,
    p_user_id       INTEGER,
    p_comment       TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Количество должно быть положительным';
    END IF;

    INSERT INTO stock_movement(detail_id, warehouse_id, supplier_id, movement_type, quantity, price_per_unit, user_id, comment)
    VALUES (p_detail_id, p_warehouse_id, p_supplier_id, 'IN', p_quantity, p_price, p_user_id, p_comment);
END;
$$;

CREATE OR REPLACE PROCEDURE sp_issue_detail(
    p_detail_id     INTEGER,
    p_warehouse_id  INTEGER,
    p_quantity      INTEGER,
    p_user_id       INTEGER,
    p_comment       TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_balance INTEGER;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Количество должно быть положительным';
    END IF;

    v_balance := fn_stock_balance(p_detail_id, p_warehouse_id);
    IF v_balance < p_quantity THEN
        RAISE EXCEPTION 'Недостаточно остатка на складе % (есть %, требуется %)',
            p_warehouse_id, v_balance, p_quantity;
    END IF;

    INSERT INTO stock_movement(detail_id, warehouse_id, movement_type, quantity, user_id, comment)
    VALUES (p_detail_id, p_warehouse_id, 'OUT', p_quantity, p_user_id, p_comment);
END;
$$;

CREATE OR REPLACE PROCEDURE sp_transfer_detail(
    p_detail_id         INTEGER,
    p_warehouse_from    INTEGER,
    p_warehouse_to      INTEGER,
    p_quantity          INTEGER,
    p_user_id           INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_balance INTEGER;
BEGIN
    IF p_warehouse_from = p_warehouse_to THEN
        RAISE EXCEPTION 'Склады отправления и получения должны различаться';
    END IF;

    v_balance := fn_stock_balance(p_detail_id, p_warehouse_from);
    IF v_balance < p_quantity THEN
        RAISE EXCEPTION 'Недостаточно остатка для перемещения (есть %, требуется %)',
            v_balance, p_quantity;
    END IF;

    INSERT INTO stock_movement(detail_id, warehouse_id, movement_type, quantity, user_id, comment)
    VALUES (p_detail_id, p_warehouse_from, 'TRANSFER_OUT', p_quantity, p_user_id,
            'Перемещение на склад #' || p_warehouse_to);
    INSERT INTO stock_movement(detail_id, warehouse_id, movement_type, quantity, user_id, comment)
    VALUES (p_detail_id, p_warehouse_to, 'TRANSFER_IN', p_quantity, p_user_id,
            'Перемещение со склада #' || p_warehouse_from);
END;
$$;

CREATE OR REPLACE PROCEDURE sp_register_user(
    p_login         VARCHAR,
    p_full_name     VARCHAR,
    p_email         VARCHAR,
    p_password_hash VARCHAR,
    p_role          user_role DEFAULT 'storekeeper'
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM users WHERE login = p_login) THEN
        RAISE EXCEPTION 'Логин % уже занят', p_login;
    END IF;
    IF EXISTS (SELECT 1 FROM users WHERE email = p_email) THEN
        RAISE EXCEPTION 'Email % уже зарегистрирован', p_email;
    END IF;

    INSERT INTO users(login, full_name, email, password_hash, role)
    VALUES (p_login, p_full_name, p_email, p_password_hash, p_role);
END;
$$;
