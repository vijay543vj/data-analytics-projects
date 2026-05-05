-- ============================================================
-- PROJECT 1: Load CSV Data into MySQL
-- Run AFTER 01_create_database.sql
-- ============================================================
-- NOTE: Update the file paths below to match where you saved
-- the CSV files on your PC before running this script.
-- Example Windows path: C:/Users/Vijay/portfolio3/project1_mysql_mis/data/
-- Example Mac/Linux path: /home/vijay/portfolio3/project1_mysql_mis/data/
-- ============================================================

USE merchant_mis;

-- Allow local file loading (run once per session if needed)
-- SET GLOBAL local_infile = 1;

-- ─── LOAD MERCHANTS ──────────────────────────────────────────
LOAD DATA LOCAL INFILE 'data/merchants.csv'
INTO TABLE merchants
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(merchant_id, merchant_name, category, city, region,
 onboarding_date, contract_type, settlement_cycle_days, monthly_txn_limit);

SELECT CONCAT('merchants loaded: ', COUNT(*), ' rows') AS status FROM merchants;

-- ─── LOAD CUSTOMERS ──────────────────────────────────────────
LOAD DATA LOCAL INFILE 'data/customers.csv'
INTO TABLE customers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(customer_id, customer_name, city, customer_segment, credit_limit, join_date);

SELECT CONCAT('customers loaded: ', COUNT(*), ' rows') AS status FROM customers;

-- ─── LOAD TRANSACTIONS ───────────────────────────────────────
LOAD DATA LOCAL INFILE 'data/transactions.csv'
INTO TABLE transactions
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(txn_id, txn_date, txn_time, txn_month, merchant_id, merchant_city,
 customer_id, amount, payment_mode, status, @dispute_reason,
 @settlement_date, risk_flag, processing_fee, net_settlement_amount)
SET
  dispute_reason   = NULLIF(@dispute_reason, ''),
  settlement_date  = NULLIF(@settlement_date, '');

SELECT CONCAT('transactions loaded: ', COUNT(*), ' rows') AS status FROM transactions;

-- ─── LOAD DISPUTES ───────────────────────────────────────────
LOAD DATA LOCAL INFILE 'data/disputes.csv'
INTO TABLE disputes
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(dispute_id, txn_id, customer_id, merchant_id, dispute_reason,
 dispute_date, resolution_status, @resolution_days, amount)
SET resolution_days = NULLIF(@resolution_days, '');

SELECT CONCAT('disputes loaded: ', COUNT(*), ' rows') AS status FROM disputes;

-- ─── VERIFY ──────────────────────────────────────────────────
SELECT
    'merchants'    AS table_name, COUNT(*) AS row_count FROM merchants UNION ALL
SELECT 'customers',    COUNT(*) FROM customers          UNION ALL
SELECT 'transactions', COUNT(*) FROM transactions       UNION ALL
SELECT 'disputes',     COUNT(*) FROM disputes;
