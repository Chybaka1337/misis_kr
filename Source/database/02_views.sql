CREATE OR REPLACE VIEW v_detail_stock AS
SELECT
    d.id                        AS detail_id,
    d.article,
    d.name                      AS detail_name,
    c.name                      AS category_name,
    m.name                      AS material_name,
    w.id                        AS warehouse_id,
    w.code                      AS warehouse_code,
    w.name                      AS warehouse_name,
    COALESCE(SUM(
        CASE
            WHEN sm.movement_type IN ('IN', 'TRANSFER_IN') THEN sm.quantity
            WHEN sm.movement_type IN ('OUT', 'TRANSFER_OUT') THEN -sm.quantity
            ELSE 0
        END
    ), 0)::INTEGER              AS balance
FROM detail d
CROSS JOIN warehouse w
LEFT JOIN stock_movement sm
       ON sm.detail_id = d.id AND sm.warehouse_id = w.id
JOIN category c ON c.id = d.category_id
JOIN material m ON m.id = d.material_id
GROUP BY d.id, d.article, d.name, c.name, m.name, w.id, w.code, w.name;

CREATE OR REPLACE VIEW v_low_stock AS
SELECT
    d.id            AS detail_id,
    d.article,
    d.name          AS detail_name,
    d.min_stock,
    COALESCE(SUM(
        CASE
            WHEN sm.movement_type IN ('IN', 'TRANSFER_IN') THEN sm.quantity
            WHEN sm.movement_type IN ('OUT', 'TRANSFER_OUT') THEN -sm.quantity
            ELSE 0
        END
    ), 0)::INTEGER  AS total_balance
FROM detail d
LEFT JOIN stock_movement sm ON sm.detail_id = d.id
GROUP BY d.id, d.article, d.name, d.min_stock
HAVING COALESCE(SUM(
        CASE
            WHEN sm.movement_type IN ('IN', 'TRANSFER_IN') THEN sm.quantity
            WHEN sm.movement_type IN ('OUT', 'TRANSFER_OUT') THEN -sm.quantity
            ELSE 0
        END
    ), 0) < d.min_stock;

CREATE OR REPLACE VIEW v_supplier_purchases AS
SELECT
    s.id                        AS supplier_id,
    s.name                      AS supplier_name,
    COUNT(sm.id)                AS movement_count,
    COALESCE(SUM(sm.quantity), 0)::INTEGER                 AS total_qty,
    COALESCE(SUM(sm.quantity * sm.price_per_unit), 0)      AS total_amount,
    MAX(sm.moved_at)            AS last_purchase_at
FROM supplier s
LEFT JOIN stock_movement sm
       ON sm.supplier_id = s.id AND sm.movement_type = 'IN'
GROUP BY s.id, s.name;

CREATE OR REPLACE VIEW v_recent_movements AS
SELECT
    sm.id,
    sm.moved_at,
    sm.movement_type,
    d.article,
    d.name                  AS detail_name,
    w.code                  AS warehouse_code,
    w.name                  AS warehouse_name,
    sm.quantity,
    sm.price_per_unit,
    (sm.quantity * COALESCE(sm.price_per_unit, 0)) AS amount,
    s.name                  AS supplier_name,
    u.full_name             AS user_name,
    sm.comment
FROM stock_movement sm
JOIN detail d    ON d.id = sm.detail_id
JOIN warehouse w ON w.id = sm.warehouse_id
LEFT JOIN supplier s ON s.id = sm.supplier_id
JOIN users u     ON u.id = sm.user_id
ORDER BY sm.moved_at DESC;
