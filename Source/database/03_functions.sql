CREATE OR REPLACE FUNCTION fn_stock_balance(p_detail_id INTEGER, p_warehouse_id INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_balance INTEGER;
BEGIN
    SELECT COALESCE(SUM(
        CASE
            WHEN movement_type IN ('IN', 'TRANSFER_IN') THEN quantity
            WHEN movement_type IN ('OUT', 'TRANSFER_OUT') THEN -quantity
            ELSE 0
        END
    ), 0)
    INTO v_balance
    FROM stock_movement
    WHERE detail_id = p_detail_id
      AND warehouse_id = p_warehouse_id;

    RETURN v_balance;
END;
$$;

CREATE OR REPLACE FUNCTION fn_warehouse_value(p_warehouse_id INTEGER)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_total NUMERIC;
BEGIN
    SELECT COALESCE(SUM(fn_stock_balance(d.id, p_warehouse_id) * d.price), 0)
    INTO v_total
    FROM detail d;

    RETURN v_total;
END;
$$;

CREATE OR REPLACE FUNCTION fn_detail_consumption(p_detail_id INTEGER, p_days INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_consumed INTEGER;
BEGIN
    SELECT COALESCE(SUM(quantity), 0)
    INTO v_consumed
    FROM stock_movement
    WHERE detail_id = p_detail_id
      AND movement_type = 'OUT'
      AND moved_at >= NOW() - (p_days || ' days')::INTERVAL;

    RETURN v_consumed;
END;
$$;

CREATE OR REPLACE FUNCTION fn_category_descendants(p_category_id INTEGER)
RETURNS TABLE(id INTEGER, name VARCHAR, depth INTEGER)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE tree AS (
        SELECT c.id, c.name, 0 AS depth
        FROM category c
        WHERE c.id = p_category_id
        UNION ALL
        SELECT child.id, child.name, t.depth + 1
        FROM category child
        JOIN tree t ON child.parent_id = t.id
    )
    SELECT tree.id, tree.name, tree.depth FROM tree;
END;
$$;
