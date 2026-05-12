SET client_encoding = 'UTF8';

DROP TABLE IF EXISTS audit_log CASCADE;
DROP TABLE IF EXISTS stock_movement CASCADE;
DROP TABLE IF EXISTS detail CASCADE;
DROP TABLE IF EXISTS warehouse CASCADE;
DROP TABLE IF EXISTS supplier CASCADE;
DROP TABLE IF EXISTS material CASCADE;
DROP TABLE IF EXISTS category CASCADE;
DROP TABLE IF EXISTS users CASCADE;

DROP TYPE IF EXISTS movement_type;
CREATE TYPE movement_type AS ENUM ('IN', 'OUT', 'TRANSFER_IN', 'TRANSFER_OUT');

DROP TYPE IF EXISTS user_role;
CREATE TYPE user_role AS ENUM ('admin', 'manager', 'storekeeper');

CREATE TABLE users (
    id              SERIAL PRIMARY KEY,
    login           VARCHAR(64) NOT NULL UNIQUE,
    full_name       VARCHAR(120) NOT NULL,
    email           VARCHAR(120) NOT NULL UNIQUE,
    password_hash   VARCHAR(255) NOT NULL,
    role            user_role NOT NULL DEFAULT 'storekeeper',
    created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE category (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(120) NOT NULL UNIQUE,
    parent_id   INTEGER REFERENCES category(id) ON DELETE SET NULL
);

CREATE TABLE material (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(80) NOT NULL UNIQUE,
    grade           VARCHAR(40),
    density_kg_m3   NUMERIC(8, 2)
);

CREATE TABLE supplier (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(200) NOT NULL,
    inn         VARCHAR(12) UNIQUE,
    phone       VARCHAR(40),
    email       VARCHAR(120)
);

CREATE TABLE warehouse (
    id          SERIAL PRIMARY KEY,
    code        VARCHAR(20) NOT NULL UNIQUE,
    name        VARCHAR(120) NOT NULL,
    address     VARCHAR(200)
);

CREATE TABLE detail (
    id              SERIAL PRIMARY KEY,
    article         VARCHAR(40) NOT NULL UNIQUE,
    name            VARCHAR(200) NOT NULL,
    category_id     INTEGER NOT NULL REFERENCES category(id) ON DELETE RESTRICT,
    material_id     INTEGER NOT NULL REFERENCES material(id) ON DELETE RESTRICT,
    weight_kg       NUMERIC(10, 3) NOT NULL CHECK (weight_kg >= 0),
    unit            VARCHAR(10) NOT NULL DEFAULT 'шт',
    price           NUMERIC(12, 2) NOT NULL CHECK (price >= 0),
    drawing_no      VARCHAR(40),
    min_stock       INTEGER NOT NULL DEFAULT 0 CHECK (min_stock >= 0),
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_detail_category ON detail(category_id);
CREATE INDEX idx_detail_material ON detail(material_id);
CREATE INDEX idx_detail_article ON detail(article);

CREATE TABLE stock_movement (
    id                  SERIAL PRIMARY KEY,
    detail_id           INTEGER NOT NULL REFERENCES detail(id) ON DELETE RESTRICT,
    warehouse_id        INTEGER NOT NULL REFERENCES warehouse(id) ON DELETE RESTRICT,
    supplier_id         INTEGER REFERENCES supplier(id) ON DELETE SET NULL,
    movement_type       movement_type NOT NULL,
    quantity            INTEGER NOT NULL CHECK (quantity > 0),
    price_per_unit      NUMERIC(12, 2),
    moved_at            TIMESTAMP NOT NULL DEFAULT NOW(),
    user_id             INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    comment             TEXT
);

CREATE INDEX idx_movement_detail ON stock_movement(detail_id);
CREATE INDEX idx_movement_warehouse ON stock_movement(warehouse_id);
CREATE INDEX idx_movement_date ON stock_movement(moved_at);

CREATE TABLE audit_log (
    id              SERIAL PRIMARY KEY,
    table_name      VARCHAR(40) NOT NULL,
    record_id       INTEGER NOT NULL,
    action          VARCHAR(20) NOT NULL,
    old_data        JSONB,
    new_data        JSONB,
    changed_by      VARCHAR(64),
    changed_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_table_record ON audit_log(table_name, record_id);
