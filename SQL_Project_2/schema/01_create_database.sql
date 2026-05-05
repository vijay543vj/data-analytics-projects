-- ============================================================
-- PROJECT 2: Credit Card Transaction Risk Flagging System
-- Author   : Vijay | Data Analyst Portfolio
-- Database : MySQL 8.0+
-- File 1/3 : Schema
-- ============================================================

CREATE DATABASE IF NOT EXISTS risk_flagging
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE risk_flagging;

-- ─── DROP ORDER ──────────────────────────────────────────────
DROP TABLE IF EXISTS risk_alerts;
DROP TABLE IF EXISTS disputes;
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS merchants;

-- ─── 1. MERCHANTS ────────────────────────────────────────────
CREATE TABLE merchants (
    merchant_id           VARCHAR(10)   PRIMARY KEY,
    merchant_name         VARCHAR(100)  NOT NULL,
    category              VARCHAR(50)   NOT NULL,
    city                  VARCHAR(50)   NOT NULL,
    region                VARCHAR(20)   NOT NULL,
    onboarding_date       DATE          NOT NULL,
    contract_type         ENUM('Standard','Premium','Enterprise') NOT NULL,
    settlement_cycle_days TINYINT       NOT NULL DEFAULT 2,
    monthly_txn_limit     INT           NOT NULL
);

CREATE INDEX idx_m_category ON merchants(category);
CREATE INDEX idx_m_region   ON merchants(region);

-- ─── 2. CUSTOMERS ────────────────────────────────────────────
CREATE TABLE customers (
    customer_id      VARCHAR(10)   PRIMARY KEY,
    customer_name    VARCHAR(100)  NOT NULL,
    city             VARCHAR(50)   NOT NULL,
    customer_segment ENUM('Retail','Premium','Corporate') NOT NULL,
    credit_limit     DECIMAL(12,2) NOT NULL,
    join_date        DATE          NOT NULL
);

CREATE INDEX idx_c_segment ON customers(customer_segment);

-- ─── 3. TRANSACTIONS ─────────────────────────────────────────
CREATE TABLE transactions (
    txn_id                VARCHAR(15)   PRIMARY KEY,
    txn_date              DATE          NOT NULL,
    txn_time              TIME          NOT NULL,
    txn_month             VARCHAR(7)    NOT NULL,
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

    CONSTRAINT fk_rt_merchant FOREIGN KEY (merchant_id) REFERENCES merchants(merchant_id),
    CONSTRAINT fk_rt_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE INDEX idx_t_date     ON transactions(txn_date);
CREATE INDEX idx_t_month    ON transactions(txn_month);
CREATE INDEX idx_t_merchant ON transactions(merchant_id);
CREATE INDEX idx_t_customer ON transactions(customer_id);
CREATE INDEX idx_t_status   ON transactions(status);
CREATE INDEX idx_t_amount   ON transactions(amount);
CREATE INDEX idx_t_risk     ON transactions(risk_flag);

-- ─── 4. RISK ALERTS LOG ──────────────────────────────────────
-- Stores every flagged transaction with rule + severity.
-- In production, this is the table compliance teams query daily.
CREATE TABLE risk_alerts (
    alert_id     INT           AUTO_INCREMENT PRIMARY KEY,
    txn_id       VARCHAR(15)   NOT NULL,
    customer_id  VARCHAR(10)   NOT NULL,
    merchant_id  VARCHAR(10)   NOT NULL,
    alert_type   VARCHAR(30)   NOT NULL
                               COMMENT 'HIGH_VALUE / VELOCITY / REPEAT_FAIL / CREDIT_BREACH / MERCHANT_ANOMALY',
    alert_level  ENUM('LOW','MEDIUM','HIGH','CRITICAL') NOT NULL,
    alert_detail TEXT          NOT NULL,
    amount       DECIMAL(14,2) NOT NULL,
    txn_date     DATE          NOT NULL,
    created_at   TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_alerts_customer (customer_id),
    INDEX idx_alerts_type     (alert_type),
    INDEX idx_alerts_level    (alert_level),
    INDEX idx_alerts_date     (txn_date)
);

SELECT 'Risk Flagging schema created successfully' AS status;
