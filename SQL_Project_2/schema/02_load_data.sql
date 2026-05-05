-- ============================================================
-- PROJECT 2: Load CSV Data into risk_flagging database
-- Run AFTER 01_create_database.sql
-- Update file paths to match your PC before running.
-- ============================================================

USE risk_flagging;

-- ─── LOAD MERCHANTS ──────────────────────────────────────────
LOAD DATA LOCAL INFILE 'data/merchants.csv'
INTO TABLE merchants
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(merchant_id, merchant_name, category, city, region,
 onboarding_date, contract_type, settlement_cycle_days, monthly_txn_limit);

SELECT CONCAT('merchants: ', COUNT(*), ' rows loaded') AS status FROM merchants;

-- ─── LOAD CUSTOMERS ──────────────────────────────────────────
LOAD DATA LOCAL INFILE 'data/customers.csv'
INTO TABLE customers
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(customer_id, customer_name, city, customer_segment, credit_limit, join_date);

SELECT CONCAT('customers: ', COUNT(*), ' rows loaded') AS status FROM customers;

-- ─── LOAD TRANSACTIONS ───────────────────────────────────────
LOAD DATA LOCAL INFILE 'data/transactions.csv'
INTO TABLE transactions
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(txn_id, txn_date, txn_time, txn_month, merchant_id, merchant_city,
 customer_id, amount, payment_mode, status, @dispute_reason,
 @settlement_date, risk_flag, processing_fee, net_settlement_amount)
SET
  dispute_reason  = NULLIF(@dispute_reason, ''),
  settlement_date = NULLIF(@settlement_date, '');

SELECT CONCAT('transactions: ', COUNT(*), ' rows loaded') AS status FROM transactions;

-- ─── VERIFY ──────────────────────────────────────────────────
SELECT 'merchants'    AS tbl, COUNT(*) AS rows FROM merchants  UNION ALL
SELECT 'customers',          COUNT(*)           FROM customers UNION ALL
SELECT 'transactions',       COUNT(*)           FROM transactions;
