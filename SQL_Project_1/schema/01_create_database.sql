-- ============================================================
-- PROJECT 1: MIS Reporting System — Merchant Network
-- Author   : Vijay | Data Analyst Portfolio
-- Database : MySQL 8.0+
-- Run order: 01_create_database.sql → 02_load_data.sql → 03_mis_queries.sql
-- ============================================================

-- Step 1: Create and select the database
CREATE DATABASE IF NOT EXISTS merchant_mis
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE merchant_mis;

-- ─── DROP TABLES (safe re-run) ───────────────────────────────
DROP TABLE IF EXISTS disputes;
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS merchants;

-- ─── 1. MERCHANTS ────────────────────────────────────────────
CREATE TABLE merchants (
    merchant_id           VARCHAR(10)  PRIMARY KEY,
    merchant_name         VARCHAR(100) NOT NULL,
    category              VARCHAR(50)  NOT NULL,
    city                  VARCHAR(50)  NOT NULL,
    region                VARCHAR(20)  NOT NULL,
    onboarding_date       DATE         NOT NULL,
    contract_type         ENUM('Standard','Premium','Enterprise') NOT NULL,
    settlement_cycle_days TINYINT      NOT NULL DEFAULT 2,
    monthly_txn_limit     INT          NOT NULL,
    created_at            TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_merchants_category ON merchants(category);
CREATE INDEX idx_merchants_region   ON merchants(region);
CREATE INDEX idx_merchants_city     ON merchants(city);

-- ─── 2. CUSTOMERS ────────────────────────────────────────────
CREATE TABLE customers (
    customer_id      VARCHAR(10)  PRIMARY KEY,
    customer_name    VARCHAR(100) NOT NULL,
    city             VARCHAR(50)  NOT NULL,
    customer_segment ENUM('Retail','Premium','Corporate') NOT NULL,
    credit_limit     DECIMAL(12,2) NOT NULL,
    join_date        DATE          NOT NULL,
    created_at       TIMESTAMP     DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_customers_segment ON customers(customer_segment);
CREATE INDEX idx_customers_city    ON customers(city);

-- ─── 3. TRANSACTIONS ─────────────────────────────────────────
CREATE TABLE transactions (
    txn_id                VARCHAR(15)   PRIMARY KEY,
    txn_date              DATE          NOT NULL,
    txn_time              TIME          NOT NULL,
    txn_month             VARCHAR(7)    NOT NULL COMMENT 'YYYY-MM format for fast grouping',
    merchant_id           VARCHAR(10)   NOT NULL,
    merchant_city         VARCHAR(50)   NOT NULL,
    customer_id           VARCHAR(10)   NOT NULL,
    amount                DECIMAL(14,2) NOT NULL CHECK (amount > 0),
    payment_mode          VARCHAR(20)   NOT NULL,
    status                ENUM('Success','Failed','Disputed','Reversed') NOT NULL,
    dispute_reason        VARCHAR(100)  NULL,
    settlement_date       DATE          NULL,
    risk_flag             ENUM('Yes','No') NOT NULL DEFAULT 'No',
    processing_fee        DECIMAL(10,2) NOT NULL,
    net_settlement_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
    created_at            TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_txn_merchant FOREIGN KEY (merchant_id) REFERENCES merchants(merchant_id),
    CONSTRAINT fk_txn_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE INDEX idx_txns_date     ON transactions(txn_date);
CREATE INDEX idx_txns_month    ON transactions(txn_month);
CREATE INDEX idx_txns_merchant ON transactions(merchant_id);
CREATE INDEX idx_txns_customer ON transactions(customer_id);
CREATE INDEX idx_txns_status   ON transactions(status);
CREATE INDEX idx_txns_risk     ON transactions(risk_flag);
CREATE INDEX idx_txns_amount   ON transactions(amount);

-- ─── 4. DISPUTES ─────────────────────────────────────────────
CREATE TABLE disputes (
    dispute_id        VARCHAR(10)  PRIMARY KEY,
    txn_id            VARCHAR(15)  NOT NULL,
    customer_id       VARCHAR(10)  NOT NULL,
    merchant_id       VARCHAR(10)  NOT NULL,
    dispute_reason    VARCHAR(100) NOT NULL,
    dispute_date      DATE         NOT NULL,
    resolution_status ENUM('Resolved','Pending','Escalated') NOT NULL,
    resolution_days   TINYINT      NULL COMMENT 'NULL = unresolved',
    amount            DECIMAL(14,2) NOT NULL,
    created_at        TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_disp_txn      FOREIGN KEY (txn_id)      REFERENCES transactions(txn_id),
    CONSTRAINT fk_disp_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT fk_disp_merchant FOREIGN KEY (merchant_id) REFERENCES merchants(merchant_id)
);

CREATE INDEX idx_disputes_merchant ON disputes(merchant_id);
CREATE INDEX idx_disputes_status   ON disputes(resolution_status);
CREATE INDEX idx_disputes_date     ON disputes(dispute_date);

SELECT 'Schema created successfully' AS status;
