--
-- PostgreSQL database dump
--

-- Dumped from database version 17.5
-- Dumped by pg_dump version 17.5

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

DROP DATABASE IF EXISTS misis_kr_detail;
--
-- Name: misis_kr_detail; Type: DATABASE; Schema: -; Owner: postgres
--

CREATE DATABASE misis_kr_detail WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'C';


ALTER DATABASE misis_kr_detail OWNER TO postgres;

\connect misis_kr_detail

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: movement_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.movement_type AS ENUM (
    'IN',
    'OUT',
    'TRANSFER_IN',
    'TRANSFER_OUT'
);


ALTER TYPE public.movement_type OWNER TO postgres;

--
-- Name: user_role; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.user_role AS ENUM (
    'admin',
    'manager',
    'storekeeper'
);


ALTER TYPE public.user_role OWNER TO postgres;

--
-- Name: fn_category_descendants(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_category_descendants(p_category_id integer) RETURNS TABLE(id integer, name character varying, depth integer)
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


ALTER FUNCTION public.fn_category_descendants(p_category_id integer) OWNER TO postgres;

--
-- Name: fn_detail_consumption(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_detail_consumption(p_detail_id integer, p_days integer) RETURNS integer
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


ALTER FUNCTION public.fn_detail_consumption(p_detail_id integer, p_days integer) OWNER TO postgres;

--
-- Name: fn_stock_balance(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_stock_balance(p_detail_id integer, p_warehouse_id integer) RETURNS integer
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


ALTER FUNCTION public.fn_stock_balance(p_detail_id integer, p_warehouse_id integer) OWNER TO postgres;

--
-- Name: fn_warehouse_value(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_warehouse_value(p_warehouse_id integer) RETURNS numeric
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


ALTER FUNCTION public.fn_warehouse_value(p_warehouse_id integer) OWNER TO postgres;

--
-- Name: sp_issue_detail(integer, integer, integer, integer, text); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_issue_detail(IN p_detail_id integer, IN p_warehouse_id integer, IN p_quantity integer, IN p_user_id integer, IN p_comment text DEFAULT NULL::text)
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


ALTER PROCEDURE public.sp_issue_detail(IN p_detail_id integer, IN p_warehouse_id integer, IN p_quantity integer, IN p_user_id integer, IN p_comment text) OWNER TO postgres;

--
-- Name: sp_receive_detail(integer, integer, integer, integer, numeric, integer, text); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_receive_detail(IN p_detail_id integer, IN p_warehouse_id integer, IN p_supplier_id integer, IN p_quantity integer, IN p_price numeric, IN p_user_id integer, IN p_comment text DEFAULT NULL::text)
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


ALTER PROCEDURE public.sp_receive_detail(IN p_detail_id integer, IN p_warehouse_id integer, IN p_supplier_id integer, IN p_quantity integer, IN p_price numeric, IN p_user_id integer, IN p_comment text) OWNER TO postgres;

--
-- Name: sp_register_user(character varying, character varying, character varying, character varying, public.user_role); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_register_user(IN p_login character varying, IN p_full_name character varying, IN p_email character varying, IN p_password_hash character varying, IN p_role public.user_role DEFAULT 'storekeeper'::public.user_role)
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


ALTER PROCEDURE public.sp_register_user(IN p_login character varying, IN p_full_name character varying, IN p_email character varying, IN p_password_hash character varying, IN p_role public.user_role) OWNER TO postgres;

--
-- Name: sp_transfer_detail(integer, integer, integer, integer, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_transfer_detail(IN p_detail_id integer, IN p_warehouse_from integer, IN p_warehouse_to integer, IN p_quantity integer, IN p_user_id integer)
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


ALTER PROCEDURE public.sp_transfer_detail(IN p_detail_id integer, IN p_warehouse_from integer, IN p_warehouse_to integer, IN p_quantity integer, IN p_user_id integer) OWNER TO postgres;

--
-- Name: trg_audit_detail(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.trg_audit_detail() RETURNS trigger
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


ALTER FUNCTION public.trg_audit_detail() OWNER TO postgres;

--
-- Name: trg_detail_touch_updated_at(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.trg_detail_touch_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.trg_detail_touch_updated_at() OWNER TO postgres;

--
-- Name: trg_validate_movement(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.trg_validate_movement() RETURNS trigger
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


ALTER FUNCTION public.trg_validate_movement() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: audit_log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.audit_log (
    id integer NOT NULL,
    table_name character varying(40) NOT NULL,
    record_id integer NOT NULL,
    action character varying(20) NOT NULL,
    old_data jsonb,
    new_data jsonb,
    changed_by character varying(64),
    changed_at timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.audit_log OWNER TO postgres;

--
-- Name: audit_log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.audit_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.audit_log_id_seq OWNER TO postgres;

--
-- Name: audit_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.audit_log_id_seq OWNED BY public.audit_log.id;


--
-- Name: category; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.category (
    id integer NOT NULL,
    name character varying(120) NOT NULL,
    parent_id integer
);


ALTER TABLE public.category OWNER TO postgres;

--
-- Name: category_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.category_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.category_id_seq OWNER TO postgres;

--
-- Name: category_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.category_id_seq OWNED BY public.category.id;


--
-- Name: detail; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.detail (
    id integer NOT NULL,
    article character varying(40) NOT NULL,
    name character varying(200) NOT NULL,
    category_id integer NOT NULL,
    material_id integer NOT NULL,
    weight_kg numeric(10,3) NOT NULL,
    unit character varying(10) DEFAULT 'шт'::character varying NOT NULL,
    price numeric(12,2) NOT NULL,
    drawing_no character varying(40),
    min_stock integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT detail_min_stock_check CHECK ((min_stock >= 0)),
    CONSTRAINT detail_price_check CHECK ((price >= (0)::numeric)),
    CONSTRAINT detail_weight_kg_check CHECK ((weight_kg >= (0)::numeric))
);


ALTER TABLE public.detail OWNER TO postgres;

--
-- Name: detail_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.detail_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.detail_id_seq OWNER TO postgres;

--
-- Name: detail_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.detail_id_seq OWNED BY public.detail.id;


--
-- Name: material; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.material (
    id integer NOT NULL,
    name character varying(80) NOT NULL,
    grade character varying(40),
    density_kg_m3 numeric(8,2)
);


ALTER TABLE public.material OWNER TO postgres;

--
-- Name: material_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.material_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.material_id_seq OWNER TO postgres;

--
-- Name: material_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.material_id_seq OWNED BY public.material.id;


--
-- Name: stock_movement; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stock_movement (
    id integer NOT NULL,
    detail_id integer NOT NULL,
    warehouse_id integer NOT NULL,
    supplier_id integer,
    movement_type public.movement_type NOT NULL,
    quantity integer NOT NULL,
    price_per_unit numeric(12,2),
    moved_at timestamp without time zone DEFAULT now() NOT NULL,
    user_id integer NOT NULL,
    comment text,
    CONSTRAINT stock_movement_quantity_check CHECK ((quantity > 0))
);


ALTER TABLE public.stock_movement OWNER TO postgres;

--
-- Name: stock_movement_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.stock_movement_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.stock_movement_id_seq OWNER TO postgres;

--
-- Name: stock_movement_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.stock_movement_id_seq OWNED BY public.stock_movement.id;


--
-- Name: supplier; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.supplier (
    id integer NOT NULL,
    name character varying(200) NOT NULL,
    inn character varying(12),
    phone character varying(40),
    email character varying(120)
);


ALTER TABLE public.supplier OWNER TO postgres;

--
-- Name: supplier_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.supplier_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.supplier_id_seq OWNER TO postgres;

--
-- Name: supplier_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.supplier_id_seq OWNED BY public.supplier.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id integer NOT NULL,
    login character varying(64) NOT NULL,
    full_name character varying(120) NOT NULL,
    email character varying(120) NOT NULL,
    password_hash character varying(255) NOT NULL,
    role public.user_role DEFAULT 'storekeeper'::public.user_role NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_id_seq OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: warehouse; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.warehouse (
    id integer NOT NULL,
    code character varying(20) NOT NULL,
    name character varying(120) NOT NULL,
    address character varying(200)
);


ALTER TABLE public.warehouse OWNER TO postgres;

--
-- Name: v_detail_stock; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_detail_stock AS
 SELECT d.id AS detail_id,
    d.article,
    d.name AS detail_name,
    c.name AS category_name,
    m.name AS material_name,
    w.id AS warehouse_id,
    w.code AS warehouse_code,
    w.name AS warehouse_name,
    (COALESCE(sum(
        CASE
            WHEN (sm.movement_type = ANY (ARRAY['IN'::public.movement_type, 'TRANSFER_IN'::public.movement_type])) THEN sm.quantity
            WHEN (sm.movement_type = ANY (ARRAY['OUT'::public.movement_type, 'TRANSFER_OUT'::public.movement_type])) THEN (- sm.quantity)
            ELSE 0
        END), (0)::bigint))::integer AS balance
   FROM ((((public.detail d
     CROSS JOIN public.warehouse w)
     LEFT JOIN public.stock_movement sm ON (((sm.detail_id = d.id) AND (sm.warehouse_id = w.id))))
     JOIN public.category c ON ((c.id = d.category_id)))
     JOIN public.material m ON ((m.id = d.material_id)))
  GROUP BY d.id, d.article, d.name, c.name, m.name, w.id, w.code, w.name;


ALTER VIEW public.v_detail_stock OWNER TO postgres;

--
-- Name: v_low_stock; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_low_stock AS
 SELECT d.id AS detail_id,
    d.article,
    d.name AS detail_name,
    d.min_stock,
    (COALESCE(sum(
        CASE
            WHEN (sm.movement_type = ANY (ARRAY['IN'::public.movement_type, 'TRANSFER_IN'::public.movement_type])) THEN sm.quantity
            WHEN (sm.movement_type = ANY (ARRAY['OUT'::public.movement_type, 'TRANSFER_OUT'::public.movement_type])) THEN (- sm.quantity)
            ELSE 0
        END), (0)::bigint))::integer AS total_balance
   FROM (public.detail d
     LEFT JOIN public.stock_movement sm ON ((sm.detail_id = d.id)))
  GROUP BY d.id, d.article, d.name, d.min_stock
 HAVING (COALESCE(sum(
        CASE
            WHEN (sm.movement_type = ANY (ARRAY['IN'::public.movement_type, 'TRANSFER_IN'::public.movement_type])) THEN sm.quantity
            WHEN (sm.movement_type = ANY (ARRAY['OUT'::public.movement_type, 'TRANSFER_OUT'::public.movement_type])) THEN (- sm.quantity)
            ELSE 0
        END), (0)::bigint) < d.min_stock);


ALTER VIEW public.v_low_stock OWNER TO postgres;

--
-- Name: v_recent_movements; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_recent_movements AS
 SELECT sm.id,
    sm.moved_at,
    sm.movement_type,
    d.article,
    d.name AS detail_name,
    w.code AS warehouse_code,
    w.name AS warehouse_name,
    sm.quantity,
    sm.price_per_unit,
    ((sm.quantity)::numeric * COALESCE(sm.price_per_unit, (0)::numeric)) AS amount,
    s.name AS supplier_name,
    u.full_name AS user_name,
    sm.comment
   FROM ((((public.stock_movement sm
     JOIN public.detail d ON ((d.id = sm.detail_id)))
     JOIN public.warehouse w ON ((w.id = sm.warehouse_id)))
     LEFT JOIN public.supplier s ON ((s.id = sm.supplier_id)))
     JOIN public.users u ON ((u.id = sm.user_id)))
  ORDER BY sm.moved_at DESC;


ALTER VIEW public.v_recent_movements OWNER TO postgres;

--
-- Name: v_supplier_purchases; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_supplier_purchases AS
 SELECT s.id AS supplier_id,
    s.name AS supplier_name,
    count(sm.id) AS movement_count,
    (COALESCE(sum(sm.quantity), (0)::bigint))::integer AS total_qty,
    COALESCE(sum(((sm.quantity)::numeric * sm.price_per_unit)), (0)::numeric) AS total_amount,
    max(sm.moved_at) AS last_purchase_at
   FROM (public.supplier s
     LEFT JOIN public.stock_movement sm ON (((sm.supplier_id = s.id) AND (sm.movement_type = 'IN'::public.movement_type))))
  GROUP BY s.id, s.name;


ALTER VIEW public.v_supplier_purchases OWNER TO postgres;

--
-- Name: warehouse_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.warehouse_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.warehouse_id_seq OWNER TO postgres;

--
-- Name: warehouse_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.warehouse_id_seq OWNED BY public.warehouse.id;


--
-- Name: audit_log id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_log ALTER COLUMN id SET DEFAULT nextval('public.audit_log_id_seq'::regclass);


--
-- Name: category id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.category ALTER COLUMN id SET DEFAULT nextval('public.category_id_seq'::regclass);


--
-- Name: detail id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detail ALTER COLUMN id SET DEFAULT nextval('public.detail_id_seq'::regclass);


--
-- Name: material id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.material ALTER COLUMN id SET DEFAULT nextval('public.material_id_seq'::regclass);


--
-- Name: stock_movement id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stock_movement ALTER COLUMN id SET DEFAULT nextval('public.stock_movement_id_seq'::regclass);


--
-- Name: supplier id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.supplier ALTER COLUMN id SET DEFAULT nextval('public.supplier_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: warehouse id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.warehouse ALTER COLUMN id SET DEFAULT nextval('public.warehouse_id_seq'::regclass);


--
-- Data for Name: audit_log; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.audit_log (id, table_name, record_id, action, old_data, new_data, changed_by, changed_at) FROM stdin;
1	detail	1	INSERT	\N	{"id": 1, "name": "Корпус редуктора Ц2У-200", "unit": "шт", "price": 12500.00, "article": "K-100-01", "min_stock": 5, "weight_kg": 18.500, "created_at": "2026-05-12T21:10:17.989039", "drawing_no": "РЕД-200-01", "updated_at": "2026-05-12T21:10:17.989039", "category_id": 6, "material_id": 3}	postgres	2026-05-12 21:10:17.989039
2	detail	2	INSERT	\N	{"id": 2, "name": "Корпус редуктора Ц2У-300", "unit": "шт", "price": 18900.00, "article": "K-100-02", "min_stock": 3, "weight_kg": 28.200, "created_at": "2026-05-12T21:10:17.989039", "drawing_no": "РЕД-300-01", "updated_at": "2026-05-12T21:10:17.989039", "category_id": 6, "material_id": 3}	postgres	2026-05-12 21:10:17.989039
3	detail	3	INSERT	\N	{"id": 3, "name": "Крышка подшипниковая 200", "unit": "шт", "price": 1850.00, "article": "KR-200-01", "min_stock": 20, "weight_kg": 2.400, "created_at": "2026-05-12T21:10:17.989039", "drawing_no": "КР-200", "updated_at": "2026-05-12T21:10:17.989039", "category_id": 7, "material_id": 3}	postgres	2026-05-12 21:10:17.989039
4	detail	4	INSERT	\N	{"id": 4, "name": "Вал приводной L=420 d=40", "unit": "шт", "price": 3200.00, "article": "V-300-01", "min_stock": 15, "weight_kg": 4.150, "created_at": "2026-05-12T21:10:17.989039", "drawing_no": "В-420-40", "updated_at": "2026-05-12T21:10:17.989039", "category_id": 8, "material_id": 1}	postgres	2026-05-12 21:10:17.989039
5	detail	5	INSERT	\N	{"id": 5, "name": "Вал приводной L=600 d=50", "unit": "шт", "price": 5800.00, "article": "V-300-02", "min_stock": 10, "weight_kg": 8.900, "created_at": "2026-05-12T21:10:17.989039", "drawing_no": "В-600-50", "updated_at": "2026-05-12T21:10:17.989039", "category_id": 8, "material_id": 2}	postgres	2026-05-12 21:10:17.989039
6	detail	6	INSERT	\N	{"id": 6, "name": "Ось гладкая d=30 L=200", "unit": "шт", "price": 720.00, "article": "O-310-01", "min_stock": 30, "weight_kg": 1.100, "created_at": "2026-05-12T21:10:17.989039", "drawing_no": "О-30-200", "updated_at": "2026-05-12T21:10:17.989039", "category_id": 9, "material_id": 1}	postgres	2026-05-12 21:10:17.989039
7	detail	7	INSERT	\N	{"id": 7, "name": "Шестерня Z=24 m=2", "unit": "шт", "price": 2400.00, "article": "SH-400-01", "min_stock": 20, "weight_kg": 1.250, "created_at": "2026-05-12T21:10:17.989039", "drawing_no": "Ш-24-2", "updated_at": "2026-05-12T21:10:17.989039", "category_id": 10, "material_id": 2}	postgres	2026-05-12 21:10:17.989039
8	detail	8	INSERT	\N	{"id": 8, "name": "Шестерня Z=40 m=3", "unit": "шт", "price": 4100.00, "article": "SH-400-02", "min_stock": 15, "weight_kg": 3.150, "created_at": "2026-05-12T21:10:17.989039", "drawing_no": "Ш-40-3", "updated_at": "2026-05-12T21:10:17.989039", "category_id": 10, "material_id": 2}	postgres	2026-05-12 21:10:17.989039
9	detail	9	INSERT	\N	{"id": 9, "name": "Шестерня Z=60 m=4", "unit": "шт", "price": 7200.00, "article": "SH-400-03", "min_stock": 8, "weight_kg": 6.400, "created_at": "2026-05-12T21:10:17.989039", "drawing_no": "Ш-60-4", "updated_at": "2026-05-12T21:10:17.989039", "category_id": 10, "material_id": 2}	postgres	2026-05-12 21:10:17.989039
10	detail	10	INSERT	\N	{"id": 10, "name": "Шестерня коническая Z=18 m=3", "unit": "шт", "price": 3800.00, "article": "SHK-410-01", "min_stock": 10, "weight_kg": 1.900, "created_at": "2026-05-12T21:10:17.989039", "drawing_no": "ШК-18-3", "updated_at": "2026-05-12T21:10:17.989039", "category_id": 11, "material_id": 2}	postgres	2026-05-12 21:10:17.989039
11	detail	11	INSERT	\N	{"id": 11, "name": "Болт М10х40 ГОСТ 7798", "unit": "шт", "price": 18.00, "article": "B-500-01", "min_stock": 500, "weight_kg": 0.045, "created_at": "2026-05-12T21:10:17.989039", "drawing_no": "7798", "updated_at": "2026-05-12T21:10:17.989039", "category_id": 12, "material_id": 1}	postgres	2026-05-12 21:10:17.989039
12	detail	12	INSERT	\N	{"id": 12, "name": "Болт М12х50 ГОСТ 7798", "unit": "шт", "price": 24.00, "article": "B-500-02", "min_stock": 400, "weight_kg": 0.078, "created_at": "2026-05-12T21:10:17.989039", "drawing_no": "7798", "updated_at": "2026-05-12T21:10:17.989039", "category_id": 12, "material_id": 1}	postgres	2026-05-12 21:10:17.989039
13	detail	13	INSERT	\N	{"id": 13, "name": "Болт М16х80 ГОСТ 7798", "unit": "шт", "price": 48.00, "article": "B-500-03", "min_stock": 200, "weight_kg": 0.220, "created_at": "2026-05-12T21:10:17.989039", "drawing_no": "7798", "updated_at": "2026-05-12T21:10:17.989039", "category_id": 12, "material_id": 1}	postgres	2026-05-12 21:10:17.989039
14	detail	14	INSERT	\N	{"id": 14, "name": "Гайка М10 ГОСТ 5915", "unit": "шт", "price": 8.00, "article": "G-510-01", "min_stock": 800, "weight_kg": 0.012, "created_at": "2026-05-12T21:10:17.989039", "drawing_no": "5915", "updated_at": "2026-05-12T21:10:17.989039", "category_id": 13, "material_id": 1}	postgres	2026-05-12 21:10:17.989039
15	detail	15	INSERT	\N	{"id": 15, "name": "Гайка М12 ГОСТ 5915", "unit": "шт", "price": 12.00, "article": "G-510-02", "min_stock": 600, "weight_kg": 0.020, "created_at": "2026-05-12T21:10:17.989039", "drawing_no": "5915", "updated_at": "2026-05-12T21:10:17.989039", "category_id": 13, "material_id": 1}	postgres	2026-05-12 21:10:17.989039
16	detail	16	INSERT	\N	{"id": 16, "name": "Крышка фланцевая d=120", "unit": "шт", "price": 2900.00, "article": "KP-220-01", "min_stock": 12, "weight_kg": 1.800, "created_at": "2026-05-12T21:10:17.989039", "drawing_no": "КП-120", "updated_at": "2026-05-12T21:10:17.989039", "category_id": 7, "material_id": 4}	postgres	2026-05-12 21:10:17.989039
17	detail	17	INSERT	\N	{"id": 17, "name": "Втулка подшипниковая d20x30", "unit": "шт", "price": 420.00, "article": "VTL-001", "min_stock": 60, "weight_kg": 0.150, "created_at": "2026-05-12T21:10:17.989039", "drawing_no": "ВТЛ-20-30", "updated_at": "2026-05-12T21:10:17.989039", "category_id": 6, "material_id": 4}	postgres	2026-05-12 21:10:17.989039
18	detail	18	INSERT	\N	{"id": 18, "name": "Стакан подшипниковый Ц2У-200", "unit": "шт", "price": 2150.00, "article": "STKN-1", "min_stock": 14, "weight_kg": 3.200, "created_at": "2026-05-12T21:10:17.989039", "drawing_no": "СТ-200", "updated_at": "2026-05-12T21:10:17.989039", "category_id": 6, "material_id": 3}	postgres	2026-05-12 21:10:17.989039
19	detail	19	INSERT	\N	{"id": 19, "name": "Тестовый вал d=25", "unit": "шт", "price": 1500.00, "article": "TEST-001", "min_stock": 5, "weight_kg": 2.500, "created_at": "2026-05-12T21:17:13.100589", "drawing_no": "Т-001", "updated_at": "2026-05-12T21:17:13.100589", "category_id": 8, "material_id": 1}	postgres	2026-05-12 21:17:13.100589
20	detail	19	UPDATE	{"id": 19, "name": "Тестовый вал d=25", "unit": "шт", "price": 1500.00, "article": "TEST-001", "min_stock": 5, "weight_kg": 2.500, "created_at": "2026-05-12T21:17:13.100589", "drawing_no": "Т-001", "updated_at": "2026-05-12T21:17:13.100589", "category_id": 8, "material_id": 1}	{"id": 19, "name": "Тестовый вал d=25 (обновлено)", "unit": "шт", "price": 1700.00, "article": "TEST-001", "min_stock": 10, "weight_kg": 2.700, "created_at": "2026-05-12T21:17:13.100589", "drawing_no": "Т-001", "updated_at": "2026-05-12T21:17:13.579285", "category_id": 8, "material_id": 1}	postgres	2026-05-12 21:17:13.579285
21	detail	19	DELETE	{"id": 19, "name": "Тестовый вал d=25 (обновлено)", "unit": "шт", "price": 1700.00, "article": "TEST-001", "min_stock": 10, "weight_kg": 2.700, "created_at": "2026-05-12T21:17:13.100589", "drawing_no": "Т-001", "updated_at": "2026-05-12T21:17:13.579285", "category_id": 8, "material_id": 1}	\N	postgres	2026-05-12 21:17:32.428147
\.


--
-- Data for Name: category; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.category (id, name, parent_id) FROM stdin;
1	Корпусные детали	\N
2	Валы и оси	\N
3	Зубчатые колёса	\N
4	Крепёж	\N
5	Подшипники	\N
6	Корпуса редукторов	1
7	Крышки подшипниковые	1
8	Валы приводные	2
9	Оси гладкие	2
10	Шестерни цилиндрические	3
11	Шестерни конические	3
12	Болты	4
13	Гайки	4
\.


--
-- Data for Name: detail; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.detail (id, article, name, category_id, material_id, weight_kg, unit, price, drawing_no, min_stock, created_at, updated_at) FROM stdin;
1	K-100-01	Корпус редуктора Ц2У-200	6	3	18.500	шт	12500.00	РЕД-200-01	5	2026-05-12 21:10:17.989039	2026-05-12 21:10:17.989039
2	K-100-02	Корпус редуктора Ц2У-300	6	3	28.200	шт	18900.00	РЕД-300-01	3	2026-05-12 21:10:17.989039	2026-05-12 21:10:17.989039
3	KR-200-01	Крышка подшипниковая 200	7	3	2.400	шт	1850.00	КР-200	20	2026-05-12 21:10:17.989039	2026-05-12 21:10:17.989039
4	V-300-01	Вал приводной L=420 d=40	8	1	4.150	шт	3200.00	В-420-40	15	2026-05-12 21:10:17.989039	2026-05-12 21:10:17.989039
5	V-300-02	Вал приводной L=600 d=50	8	2	8.900	шт	5800.00	В-600-50	10	2026-05-12 21:10:17.989039	2026-05-12 21:10:17.989039
6	O-310-01	Ось гладкая d=30 L=200	9	1	1.100	шт	720.00	О-30-200	30	2026-05-12 21:10:17.989039	2026-05-12 21:10:17.989039
7	SH-400-01	Шестерня Z=24 m=2	10	2	1.250	шт	2400.00	Ш-24-2	20	2026-05-12 21:10:17.989039	2026-05-12 21:10:17.989039
8	SH-400-02	Шестерня Z=40 m=3	10	2	3.150	шт	4100.00	Ш-40-3	15	2026-05-12 21:10:17.989039	2026-05-12 21:10:17.989039
9	SH-400-03	Шестерня Z=60 m=4	10	2	6.400	шт	7200.00	Ш-60-4	8	2026-05-12 21:10:17.989039	2026-05-12 21:10:17.989039
10	SHK-410-01	Шестерня коническая Z=18 m=3	11	2	1.900	шт	3800.00	ШК-18-3	10	2026-05-12 21:10:17.989039	2026-05-12 21:10:17.989039
11	B-500-01	Болт М10х40 ГОСТ 7798	12	1	0.045	шт	18.00	7798	500	2026-05-12 21:10:17.989039	2026-05-12 21:10:17.989039
12	B-500-02	Болт М12х50 ГОСТ 7798	12	1	0.078	шт	24.00	7798	400	2026-05-12 21:10:17.989039	2026-05-12 21:10:17.989039
13	B-500-03	Болт М16х80 ГОСТ 7798	12	1	0.220	шт	48.00	7798	200	2026-05-12 21:10:17.989039	2026-05-12 21:10:17.989039
14	G-510-01	Гайка М10 ГОСТ 5915	13	1	0.012	шт	8.00	5915	800	2026-05-12 21:10:17.989039	2026-05-12 21:10:17.989039
15	G-510-02	Гайка М12 ГОСТ 5915	13	1	0.020	шт	12.00	5915	600	2026-05-12 21:10:17.989039	2026-05-12 21:10:17.989039
16	KP-220-01	Крышка фланцевая d=120	7	4	1.800	шт	2900.00	КП-120	12	2026-05-12 21:10:17.989039	2026-05-12 21:10:17.989039
17	VTL-001	Втулка подшипниковая d20x30	6	4	0.150	шт	420.00	ВТЛ-20-30	60	2026-05-12 21:10:17.989039	2026-05-12 21:10:17.989039
18	STKN-1	Стакан подшипниковый Ц2У-200	6	3	3.200	шт	2150.00	СТ-200	14	2026-05-12 21:10:17.989039	2026-05-12 21:10:17.989039
\.


--
-- Data for Name: material; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.material (id, name, grade, density_kg_m3) FROM stdin;
1	Сталь 45	45	7850.00
2	Сталь 40Х	40Х	7820.00
3	Чугун СЧ20	СЧ20	7200.00
4	Бронза БрАЖ	БрАЖ9-4	7600.00
5	Алюминий АД1	АД1	2710.00
6	Полиамид ПА6	ПА6	1140.00
\.


--
-- Data for Name: stock_movement; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.stock_movement (id, detail_id, warehouse_id, supplier_id, movement_type, quantity, price_per_unit, moved_at, user_id, comment) FROM stdin;
1	1	1	1	IN	10	12000.00	2026-03-28 21:10:17.99466	3	Партия №1
2	2	1	1	IN	8	18500.00	2026-03-28 21:10:17.99466	3	Партия №1
3	3	1	1	IN	100	1800.00	2026-04-02 21:10:17.99466	3	\N
4	4	1	2	IN	40	3100.00	2026-04-02 21:10:17.99466	3	\N
5	5	1	2	IN	30	5700.00	2026-04-02 21:10:17.99466	3	\N
6	6	1	2	IN	120	700.00	2026-04-04 21:10:17.99466	3	\N
7	7	1	2	IN	80	2300.00	2026-04-04 21:10:17.99466	3	\N
8	8	1	2	IN	50	4000.00	2026-04-04 21:10:17.99466	3	\N
9	9	1	2	IN	25	7100.00	2026-04-04 21:10:17.99466	3	\N
10	10	1	2	IN	30	3700.00	2026-04-04 21:10:17.99466	3	\N
11	11	1	3	IN	2000	17.50	2026-04-12 21:10:17.99466	3	Метизы
12	12	1	3	IN	1500	23.00	2026-04-12 21:10:17.99466	3	Метизы
13	13	1	3	IN	800	47.00	2026-04-12 21:10:17.99466	3	Метизы
14	14	1	3	IN	3000	7.50	2026-04-12 21:10:17.99466	3	Метизы
15	15	1	3	IN	2500	11.50	2026-04-12 21:10:17.99466	3	Метизы
16	16	1	4	IN	40	2850.00	2026-04-17 21:10:17.99466	3	\N
17	17	1	4	IN	200	400.00	2026-04-17 21:10:17.99466	3	\N
18	18	1	1	IN	30	2100.00	2026-04-22 21:10:17.99466	3	\N
19	11	1	\N	OUT	200	\N	2026-04-27 21:10:17.99466	3	Сборка партии редукторов
20	12	1	\N	OUT	180	\N	2026-04-27 21:10:17.99466	3	Сборка партии редукторов
21	14	1	\N	OUT	200	\N	2026-04-27 21:10:17.99466	3	Сборка партии редукторов
22	15	1	\N	OUT	180	\N	2026-04-27 21:10:17.99466	3	Сборка партии редукторов
23	4	1	\N	OUT	8	\N	2026-04-28 21:10:17.99466	3	В производство
24	7	1	\N	OUT	12	\N	2026-04-28 21:10:17.99466	3	В производство
25	3	1	\N	OUT	15	\N	2026-04-30 21:10:17.99466	3	В сборку
26	1	1	\N	TRANSFER_OUT	4	\N	2026-05-02 21:10:17.99466	3	Перемещение на склад #2
27	1	2	\N	TRANSFER_IN	4	\N	2026-05-02 21:10:17.99466	3	Перемещение со склада #1
28	4	1	\N	TRANSFER_OUT	10	\N	2026-05-03 21:10:17.99466	3	Перемещение на склад #2
29	4	2	\N	TRANSFER_IN	10	\N	2026-05-03 21:10:17.99466	3	Перемещение со склада #1
30	7	1	\N	TRANSFER_OUT	25	\N	2026-05-04 21:10:17.99466	3	Перемещение на склад #2
31	7	2	\N	TRANSFER_IN	25	\N	2026-05-04 21:10:17.99466	3	Перемещение со склада #1
32	1	2	\N	OUT	2	\N	2026-05-07 21:10:17.99466	4	Со склада №2 в сборочный участок
33	4	2	\N	OUT	5	\N	2026-05-08 21:10:17.99466	4	Сборка изделия №47
34	7	2	\N	OUT	10	\N	2026-05-09 21:10:17.99466	4	Сборка изделия №47
35	13	1	\N	OUT	50	\N	2026-05-10 21:10:17.99466	4	Цех №3
\.


--
-- Data for Name: supplier; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.supplier (id, name, inn, phone, email) FROM stdin;
1	ООО «МеталлПром»	7701234567	+7 (495) 111-22-33	sales@metallprom.ru
2	АО «Промстальсервис»	7702345678	+7 (495) 222-33-44	order@promstal.ru
3	ООО «РТИ-Поставка»	7703456789	+7 (495) 333-44-55	rti@postavka.ru
4	ИП Сидоров А.Г.	770456789012	+7 (916) 444-55-66	sidorov@yandex.ru
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, login, full_name, email, password_hash, role, created_at) FROM stdin;
1	admin	Администратор Системы	admin@detal.local	$2y$12$XaaktxtvIRMWd5hgZwdq2uGGNSDA6AkXn4oiGNtsNo/JUuPhidi3O	admin	2026-05-12 21:10:17.980755
2	manager	Иванов Иван Иванович	manager@detal.local	$2y$12$I0ctxvDa6IcgmrXq7Ljq0eNkyKgYk76Cq/v20DB9qxhzfnKnH23EC	manager	2026-05-12 21:10:17.980755
3	petrov	Петров Пётр Петрович	petrov@detal.local	$2y$12$zCBWeQg0hH0pIkFYJkahp.uNDtqWmq7mXPkZGBuSX5OMh4InDqPd.	storekeeper	2026-05-12 21:10:17.980755
4	zommer	Зоммер Андрей Алексеевич	zommer@detal.local	$2y$12$XMMq8CDVKDXvE6aTBmdIzummWfN1l89XhEZAo1GAntokVeN.q3yKS	storekeeper	2026-05-12 21:10:17.980755
\.


--
-- Data for Name: warehouse; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.warehouse (id, code, name, address) FROM stdin;
1	SKL-01	Главный склад	г. Москва, Ленинский пр., 4
2	SKL-02	Цеховой склад	г. Москва, Ленинский пр., 4, корп. 2
3	SKL-03	Склад готовой продукции	г. Москва, Ленинский пр., 4, корп. 3
\.


--
-- Name: audit_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.audit_log_id_seq', 21, true);


--
-- Name: category_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.category_id_seq', 13, true);


--
-- Name: detail_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.detail_id_seq', 20, true);


--
-- Name: material_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.material_id_seq', 6, true);


--
-- Name: stock_movement_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.stock_movement_id_seq', 39, true);


--
-- Name: supplier_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.supplier_id_seq', 4, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_id_seq', 4, true);


--
-- Name: warehouse_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.warehouse_id_seq', 3, true);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);


--
-- Name: category category_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.category
    ADD CONSTRAINT category_name_key UNIQUE (name);


--
-- Name: category category_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.category
    ADD CONSTRAINT category_pkey PRIMARY KEY (id);


--
-- Name: detail detail_article_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detail
    ADD CONSTRAINT detail_article_key UNIQUE (article);


--
-- Name: detail detail_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detail
    ADD CONSTRAINT detail_pkey PRIMARY KEY (id);


--
-- Name: material material_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.material
    ADD CONSTRAINT material_name_key UNIQUE (name);


--
-- Name: material material_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.material
    ADD CONSTRAINT material_pkey PRIMARY KEY (id);


--
-- Name: stock_movement stock_movement_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stock_movement
    ADD CONSTRAINT stock_movement_pkey PRIMARY KEY (id);


--
-- Name: supplier supplier_inn_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.supplier
    ADD CONSTRAINT supplier_inn_key UNIQUE (inn);


--
-- Name: supplier supplier_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.supplier
    ADD CONSTRAINT supplier_pkey PRIMARY KEY (id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_login_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_login_key UNIQUE (login);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: warehouse warehouse_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.warehouse
    ADD CONSTRAINT warehouse_code_key UNIQUE (code);


--
-- Name: warehouse warehouse_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.warehouse
    ADD CONSTRAINT warehouse_pkey PRIMARY KEY (id);


--
-- Name: idx_audit_table_record; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_audit_table_record ON public.audit_log USING btree (table_name, record_id);


--
-- Name: idx_detail_article; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_detail_article ON public.detail USING btree (article);


--
-- Name: idx_detail_category; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_detail_category ON public.detail USING btree (category_id);


--
-- Name: idx_detail_material; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_detail_material ON public.detail USING btree (material_id);


--
-- Name: idx_movement_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_movement_date ON public.stock_movement USING btree (moved_at);


--
-- Name: idx_movement_detail; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_movement_detail ON public.stock_movement USING btree (detail_id);


--
-- Name: idx_movement_warehouse; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_movement_warehouse ON public.stock_movement USING btree (warehouse_id);


--
-- Name: detail tg_audit_detail; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tg_audit_detail AFTER INSERT OR DELETE OR UPDATE ON public.detail FOR EACH ROW EXECUTE FUNCTION public.trg_audit_detail();


--
-- Name: detail tg_detail_touch_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tg_detail_touch_updated_at BEFORE UPDATE ON public.detail FOR EACH ROW EXECUTE FUNCTION public.trg_detail_touch_updated_at();


--
-- Name: stock_movement tg_validate_movement; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tg_validate_movement BEFORE INSERT ON public.stock_movement FOR EACH ROW EXECUTE FUNCTION public.trg_validate_movement();


--
-- Name: category category_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.category
    ADD CONSTRAINT category_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.category(id) ON DELETE SET NULL;


--
-- Name: detail detail_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detail
    ADD CONSTRAINT detail_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.category(id) ON DELETE RESTRICT;


--
-- Name: detail detail_material_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detail
    ADD CONSTRAINT detail_material_id_fkey FOREIGN KEY (material_id) REFERENCES public.material(id) ON DELETE RESTRICT;


--
-- Name: stock_movement stock_movement_detail_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stock_movement
    ADD CONSTRAINT stock_movement_detail_id_fkey FOREIGN KEY (detail_id) REFERENCES public.detail(id) ON DELETE RESTRICT;


--
-- Name: stock_movement stock_movement_supplier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stock_movement
    ADD CONSTRAINT stock_movement_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES public.supplier(id) ON DELETE SET NULL;


--
-- Name: stock_movement stock_movement_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stock_movement
    ADD CONSTRAINT stock_movement_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: stock_movement stock_movement_warehouse_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stock_movement
    ADD CONSTRAINT stock_movement_warehouse_id_fkey FOREIGN KEY (warehouse_id) REFERENCES public.warehouse(id) ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--

