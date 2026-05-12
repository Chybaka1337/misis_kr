CREATE OR REPLACE FUNCTION trg_validate_movement()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_balance INTEGER;
BEGIN
    IF NEW.movement_type IN ('OUT', 'TRANSFER_OUT') THEN
        v_balance := COALESCE((
            SELECT SUM(
                CASE
                    WHEN movement_type IN ('IN', 'TRANSFER_IN') THEN quantity
                    WHEN movement_type IN ('OUT', 'TRANSFER_OUT') THEN -quantity
                    ELSE 0
                END
            )
            FROM stock_movement
            WHERE detail_id = NEW.detail_id
              AND warehouse_id = NEW.warehouse_id
        ), 0);

        IF v_balance < NEW.quantity THEN
            RAISE EXCEPTION 'Недостаточно остатка детали % на складе % (есть %, списать %)',
                NEW.detail_id, NEW.warehouse_id, v_balance, NEW.quantity;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tg_validate_movement ON stock_movement;
CREATE TRIGGER tg_validate_movement
    BEFORE INSERT ON stock_movement
    FOR EACH ROW
    EXECUTE FUNCTION trg_validate_movement();

CREATE OR REPLACE FUNCTION trg_detail_touch_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tg_detail_touch_updated_at ON detail;
CREATE TRIGGER tg_detail_touch_updated_at
    BEFORE UPDATE ON detail
    FOR EACH ROW
    EXECUTE FUNCTION trg_detail_touch_updated_at();

CREATE OR REPLACE FUNCTION trg_audit_detail()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log(table_name, record_id, action, new_data, changed_by)
        VALUES ('detail', NEW.id, 'INSERT', to_jsonb(NEW), current_user);
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log(table_name, record_id, action, old_data, new_data, changed_by)
        VALUES ('detail', NEW.id, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW), current_user);
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log(table_name, record_id, action, old_data, changed_by)
        VALUES ('detail', OLD.id, 'DELETE', to_jsonb(OLD), current_user);
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS tg_audit_detail ON detail;
CREATE TRIGGER tg_audit_detail
    AFTER INSERT OR UPDATE OR DELETE ON detail
    FOR EACH ROW
    EXECUTE FUNCTION trg_audit_detail();
