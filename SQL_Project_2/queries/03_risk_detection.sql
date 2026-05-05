-- ============================================================
-- PROJECT 2: Risk Detection Rules, Views & Stored Procedures
-- Author   : Vijay | Data Analyst Portfolio
-- Database : risk_flagging
-- Run AFTER 02_load_data.sql
-- ============================================================

USE risk_flagging;

-- ════════════════════════════════════════════════════════════
-- SECTION A: DETECTION QUERIES (Run individually to explore)
-- ════════════════════════════════════════════════════════════

-- ────────────────────────────────────────────────────────────
-- RULE 1: HIGH-VALUE ANOMALY
-- Flag transactions where amount > 3× the customer's
-- average successful spend (minimum 3 txns to set baseline).
-- Business logic: Sudden large spend vs. established baseline
-- is the most reliable early fraud signal.
-- ────────────────────────────────────────────────────────────
SELECT
    t.txn_id,
    t.customer_id,
    t.merchant_id,
    t.txn_date,
    t.amount                                                   AS txn_amount,
    ROUND(baseline.avg_spend, 2)                               AS customer_avg_spend,
    ROUND(t.amount / baseline.avg_spend, 2)                    AS spend_multiplier,
    CASE
        WHEN t.amount / baseline.avg_spend > 10 THEN 'CRITICAL'
        WHEN t.amount / baseline.avg_spend > 5  THEN 'HIGH'
        ELSE 'MEDIUM'
    END                                                        AS alert_level,
    m.category                                                 AS merchant_category,
    t.payment_mode,
    t.status
FROM transactions t
JOIN merchants m ON t.merchant_id = m.merchant_id
JOIN (
    SELECT
        customer_id,
        AVG(amount) AS avg_spend
    FROM transactions
    WHERE status = 'Success'
    GROUP BY customer_id
    HAVING COUNT(*) >= 3
) baseline ON t.customer_id = baseline.customer_id
WHERE t.status IN ('Success', 'Failed')
  AND t.amount > (3 * baseline.avg_spend)
ORDER BY (t.amount / baseline.avg_spend) DESC;


-- ────────────────────────────────────────────────────────────
-- RULE 2: VELOCITY CHECK
-- Flag customers with 5+ transactions in any 24-hour window.
-- Business logic: Rapid-fire transactions = card testing
-- or account takeover by a bot.
-- Uses a self-JOIN on transactions table.
-- ────────────────────────────────────────────────────────────
SELECT
    t1.customer_id,
    t1.txn_date,
    COUNT(t2.txn_id)                                           AS txns_in_24h_window,
    ROUND(SUM(t2.amount), 2)                                   AS total_amount_in_window,
    GROUP_CONCAT(DISTINCT t2.merchant_city ORDER BY t2.merchant_city) AS cities_transacted,
    CASE
        WHEN COUNT(t2.txn_id) >= 10 THEN 'CRITICAL'
        WHEN COUNT(t2.txn_id) >= 7  THEN 'HIGH'
        ELSE 'MEDIUM'
    END                                                        AS alert_level
FROM transactions t1
JOIN transactions t2
    ON  t1.customer_id = t2.customer_id
    AND t1.txn_id     != t2.txn_id
    AND t2.txn_date BETWEEN
        DATE_SUB(t1.txn_date, INTERVAL 1 DAY)
        AND DATE_ADD(t1.txn_date, INTERVAL 1 DAY)
GROUP BY t1.customer_id, t1.txn_date
HAVING COUNT(t2.txn_id) >= 5
ORDER BY txns_in_24h_window DESC;


-- ────────────────────────────────────────────────────────────
-- RULE 3: REPEATED FAILURE PATTERN
-- Flag customers with 3+ failed transactions in one month.
-- Business logic: Repeated declines suggest a stolen card
-- being tested across multiple merchants.
-- ────────────────────────────────────────────────────────────
SELECT
    t.customer_id,
    c.customer_name,
    c.customer_segment,
    t.txn_month,
    COUNT(*)                                                   AS failed_txns,
    ROUND(SUM(t.amount), 2)                                    AS total_attempted_amount,
    COUNT(DISTINCT t.merchant_id)                              AS distinct_merchants_tried,
    MIN(t.txn_date)                                            AS first_failure_date,
    MAX(t.txn_date)                                            AS last_failure_date,
    CASE
        WHEN COUNT(*) >= 8 THEN 'CRITICAL'
        WHEN COUNT(*) >= 5 THEN 'HIGH'
        ELSE 'MEDIUM'
    END                                                        AS alert_level
FROM transactions t
JOIN customers c ON t.customer_id = c.customer_id
WHERE t.status = 'Failed'
GROUP BY t.customer_id, c.customer_name, c.customer_segment, t.txn_month
HAVING COUNT(*) >= 3
ORDER BY failed_txns DESC;


-- ────────────────────────────────────────────────────────────
-- RULE 4: CREDIT LIMIT BREACH PROXIMITY
-- Flag transactions at or above 80% of the customer's
-- credit limit in a single transaction.
-- Business logic: Maxing out credit = high fraud probability
-- or financial distress signal.
-- ────────────────────────────────────────────────────────────
SELECT
    t.txn_id,
    t.customer_id,
    c.customer_name,
    c.customer_segment,
    c.credit_limit,
    t.amount                                                   AS txn_amount,
    ROUND(t.amount / c.credit_limit * 100, 1)                 AS pct_of_credit_limit,
    t.txn_date,
    t.status,
    m.category                                                 AS merchant_category,
    CASE
        WHEN t.amount / c.credit_limit >= 1.0  THEN 'CRITICAL'
        WHEN t.amount / c.credit_limit >= 0.9  THEN 'HIGH'
        ELSE 'MEDIUM'
    END                                                        AS alert_level
FROM transactions t
JOIN customers c ON t.customer_id = c.customer_id
JOIN merchants  m ON t.merchant_id = m.merchant_id
WHERE t.amount >= (0.8 * c.credit_limit)
  AND t.status IN ('Success', 'Failed')
ORDER BY (t.amount / c.credit_limit) DESC;


-- ────────────────────────────────────────────────────────────
-- RULE 5: MERCHANT ANOMALY — HIGH FAILURE + HIGH VALUE
-- Flag merchants with >25% failure rate AND avg txn > ₹20,000
-- Business logic: A high-value merchant with poor success
-- rates may indicate a compromised terminal or fraud scheme.
-- ────────────────────────────────────────────────────────────
SELECT
    m.merchant_id,
    m.merchant_name,
    m.category,
    m.region,
    m.contract_type,
    COUNT(t.txn_id)                                            AS total_txns,
    ROUND(AVG(t.amount), 2)                                    AS avg_txn_amount,
    SUM(t.status = 'Failed')                                   AS failed_txns,
    ROUND(100.0 * SUM(t.status='Failed') / COUNT(*), 2)       AS failure_rate_pct,
    ROUND(SUM(CASE WHEN t.status='Success' THEN t.amount ELSE 0 END)/100000, 2) AS revenue_lakhs,
    CASE
        WHEN SUM(t.status='Failed')/COUNT(*) >= 0.4
         AND AVG(t.amount) > 30000                             THEN 'CRITICAL'
        WHEN SUM(t.status='Failed')/COUNT(*) >= 0.3           THEN 'HIGH'
        ELSE 'MEDIUM'
    END                                                        AS risk_level
FROM merchants m
JOIN transactions t ON m.merchant_id = t.merchant_id
GROUP BY m.merchant_id, m.merchant_name, m.category, m.region, m.contract_type
HAVING COUNT(t.txn_id) >= 30
   AND (SUM(t.status='Failed') / COUNT(t.txn_id)) > 0.25
   AND AVG(t.amount) > 20000
ORDER BY failure_rate_pct DESC;


-- ════════════════════════════════════════════════════════════
-- SECTION B: VIEWS (Reusable risk lenses)
-- ════════════════════════════════════════════════════════════

-- ─── VIEW 1: High-Value Anomalies ────────────────────────────
CREATE OR REPLACE VIEW vw_high_value_anomalies AS
SELECT
    t.txn_id,
    t.customer_id,
    t.merchant_id,
    t.txn_date,
    t.amount                                                   AS txn_amount,
    ROUND(b.avg_spend, 2)                                      AS customer_avg_spend,
    ROUND(t.amount / b.avg_spend, 2)                           AS spend_multiplier,
    CASE
        WHEN t.amount / b.avg_spend > 10 THEN 'CRITICAL'
        WHEN t.amount / b.avg_spend > 5  THEN 'HIGH'
        ELSE 'MEDIUM'
    END                                                        AS alert_level,
    'HIGH_VALUE'                                               AS alert_type,
    m.category,
    m.region
FROM transactions t
JOIN merchants m ON t.merchant_id = m.merchant_id
JOIN (
    SELECT customer_id, AVG(amount) AS avg_spend
    FROM transactions
    WHERE status = 'Success'
    GROUP BY customer_id
    HAVING COUNT(*) >= 3
) b ON t.customer_id = b.customer_id
WHERE t.status IN ('Success','Failed')
  AND t.amount > (3 * b.avg_spend);


-- ─── VIEW 2: Customer Risk Profile ───────────────────────────
CREATE OR REPLACE VIEW vw_customer_risk_profile AS
SELECT
    c.customer_id,
    c.customer_name,
    c.customer_segment,
    c.credit_limit,
    COUNT(t.txn_id)                                            AS total_txns,
    SUM(t.status = 'Failed')                                   AS failed_txns,
    SUM(t.status = 'Disputed')                                 AS disputed_txns,
    SUM(t.risk_flag = 'Yes')                                   AS risk_flagged_txns,
    ROUND(AVG(CASE WHEN t.status='Success' THEN t.amount END), 2) AS avg_spend,
    ROUND(MAX(t.amount), 2)                                    AS max_single_txn,
    ROUND(100.0 * SUM(t.status='Failed') / NULLIF(COUNT(*),0), 2) AS failure_rate_pct,
    CASE
        WHEN SUM(t.risk_flag='Yes') >= 3
          OR SUM(t.status='Failed')  >= 8  THEN 'HIGH RISK'
        WHEN SUM(t.risk_flag='Yes') >= 1
          OR SUM(t.status='Failed')  >= 4  THEN 'MEDIUM RISK'
        ELSE 'LOW RISK'
    END                                                        AS risk_category
FROM customers c
LEFT JOIN transactions t ON c.customer_id = t.customer_id
GROUP BY c.customer_id, c.customer_name, c.customer_segment, c.credit_limit;


-- ─── VIEW 3: Merchant Risk Profile ───────────────────────────
CREATE OR REPLACE VIEW vw_merchant_risk_profile AS
SELECT
    m.merchant_id,
    m.merchant_name,
    m.category,
    m.region,
    COUNT(t.txn_id)                                            AS total_txns,
    ROUND(AVG(t.amount), 2)                                    AS avg_txn_amount,
    ROUND(100.0 * SUM(t.status='Failed')   / COUNT(*), 2)     AS failure_rate_pct,
    ROUND(100.0 * SUM(t.status='Disputed') / COUNT(*), 2)     AS dispute_rate_pct,
    SUM(t.risk_flag = 'Yes')                                   AS risk_txns,
    CASE
        WHEN SUM(t.risk_flag='Yes') >= 5
          OR (SUM(t.status='Failed')/COUNT(*)) >= 0.35         THEN 'HIGH RISK'
        WHEN SUM(t.risk_flag='Yes') >= 2
          OR (SUM(t.status='Failed')/COUNT(*)) >= 0.20         THEN 'MEDIUM RISK'
        ELSE 'LOW RISK'
    END                                                        AS risk_category
FROM merchants m
JOIN transactions t ON m.merchant_id = t.merchant_id
GROUP BY m.merchant_id, m.merchant_name, m.category, m.region
HAVING COUNT(t.txn_id) >= 20;


-- ─── VIEW 4: Executive Risk Summary ──────────────────────────
CREATE OR REPLACE VIEW vw_risk_executive_summary AS
SELECT 'Total Transactions'       AS metric, CAST(COUNT(*) AS CHAR)                              AS value FROM transactions UNION ALL
SELECT 'High-Value Anomalies',             CAST(COUNT(*) AS CHAR)                               FROM vw_high_value_anomalies UNION ALL
SELECT 'CRITICAL Alerts',                  CAST(SUM(alert_level='CRITICAL') AS CHAR)            FROM vw_high_value_anomalies UNION ALL
SELECT 'Risk-Flagged Transactions',        CAST(SUM(risk_flag='Yes') AS CHAR)                   FROM transactions UNION ALL
SELECT 'High-Risk Customers',              CAST(COUNT(*) AS CHAR)                               FROM vw_customer_risk_profile WHERE risk_category='HIGH RISK' UNION ALL
SELECT 'High-Risk Merchants',              CAST(COUNT(*) AS CHAR)                               FROM vw_merchant_risk_profile WHERE risk_category='HIGH RISK';


-- ════════════════════════════════════════════════════════════
-- SECTION C: STORED PROCEDURES
-- ════════════════════════════════════════════════════════════

DELIMITER $$

-- ─── PROCEDURE 1: Full Risk Dashboard ────────────────────────
-- Usage: CALL sp_risk_dashboard();
-- Returns 4 result sets: summary, high-value, repeat-fail, credit breach
DROP PROCEDURE IF EXISTS sp_risk_dashboard $$
CREATE PROCEDURE sp_risk_dashboard()
BEGIN
    -- Result set 1: Executive summary
    SELECT * FROM vw_risk_executive_summary;

    -- Result set 2: Top 20 high-value anomalies
    SELECT txn_id, customer_id, merchant_id, txn_date,
           txn_amount, customer_avg_spend, spend_multiplier,
           alert_level, category
    FROM vw_high_value_anomalies
    ORDER BY spend_multiplier DESC
    LIMIT 20;

    -- Result set 3: High-risk customers
    SELECT customer_id, customer_name, customer_segment,
           total_txns, failed_txns, risk_flagged_txns,
           avg_spend, failure_rate_pct, risk_category
    FROM vw_customer_risk_profile
    WHERE risk_category = 'HIGH RISK'
    ORDER BY failed_txns DESC;

    -- Result set 4: High-risk merchants
    SELECT merchant_id, merchant_name, category, region,
           total_txns, failure_rate_pct, dispute_rate_pct,
           risk_txns, risk_category
    FROM vw_merchant_risk_profile
    WHERE risk_category = 'HIGH RISK'
    ORDER BY failure_rate_pct DESC;
END $$


-- ─── PROCEDURE 2: Customer Risk Deep Dive ────────────────────
-- Usage: CALL sp_customer_risk_deepdive('C00058');
-- Pulls full transaction history for one customer with flags.
DROP PROCEDURE IF EXISTS sp_customer_risk_deepdive $$
CREATE PROCEDURE sp_customer_risk_deepdive(IN p_customer_id VARCHAR(10))
BEGIN
    -- Customer profile
    SELECT * FROM vw_customer_risk_profile WHERE customer_id = p_customer_id;

    -- All transactions for this customer
    SELECT
        t.txn_id, t.txn_date, t.merchant_id, m.merchant_name,
        m.category, t.amount, t.status, t.risk_flag, t.payment_mode
    FROM transactions t
    JOIN merchants m ON t.merchant_id = m.merchant_id
    WHERE t.customer_id = p_customer_id
    ORDER BY t.txn_date DESC;

    -- Monthly summary for this customer
    SELECT txn_month,
           COUNT(*)                    AS txns,
           SUM(status='Success')       AS successful,
           SUM(status='Failed')        AS failed,
           ROUND(SUM(CASE WHEN status='Success' THEN amount ELSE 0 END),2) AS total_spend
    FROM transactions
    WHERE customer_id = p_customer_id
    GROUP BY txn_month
    ORDER BY txn_month;
END $$


-- ─── PROCEDURE 3: Populate Risk Alerts Log ───────────────────
-- Usage: CALL sp_populate_risk_alerts();
-- Runs all 5 rules and writes results into risk_alerts table.
-- In production, schedule this to run nightly via cron/event.
DROP PROCEDURE IF EXISTS sp_populate_risk_alerts $$
CREATE PROCEDURE sp_populate_risk_alerts()
BEGIN
    -- Clear previous alerts
    TRUNCATE TABLE risk_alerts;

    -- Rule 1: High-Value Anomaly
    INSERT INTO risk_alerts (txn_id, customer_id, merchant_id, alert_type, alert_level, alert_detail, amount, txn_date)
    SELECT
        t.txn_id, t.customer_id, t.merchant_id,
        'HIGH_VALUE',
        CASE
            WHEN t.amount / b.avg_spend > 10 THEN 'CRITICAL'
            WHEN t.amount / b.avg_spend > 5  THEN 'HIGH'
            ELSE 'MEDIUM'
        END,
        CONCAT('Spend ', ROUND(t.amount/b.avg_spend,1), 'x above customer average of ₹', ROUND(b.avg_spend,0)),
        t.amount,
        t.txn_date
    FROM transactions t
    JOIN (
        SELECT customer_id, AVG(amount) AS avg_spend
        FROM transactions WHERE status='Success'
        GROUP BY customer_id HAVING COUNT(*) >= 3
    ) b ON t.customer_id = b.customer_id
    WHERE t.status IN ('Success','Failed')
      AND t.amount > (3 * b.avg_spend);

    -- Rule 3: Repeated Failure
    INSERT INTO risk_alerts (txn_id, customer_id, merchant_id, alert_type, alert_level, alert_detail, amount, txn_date)
    SELECT
        t.txn_id, t.customer_id, t.merchant_id,
        'REPEAT_FAIL',
        CASE WHEN fc.fail_count >= 8 THEN 'CRITICAL' WHEN fc.fail_count >= 5 THEN 'HIGH' ELSE 'MEDIUM' END,
        CONCAT(fc.fail_count, ' failed transactions in ', t.txn_month),
        t.amount, t.txn_date
    FROM transactions t
    JOIN (
        SELECT customer_id, txn_month, COUNT(*) AS fail_count
        FROM transactions WHERE status='Failed'
        GROUP BY customer_id, txn_month
        HAVING COUNT(*) >= 3
    ) fc ON t.customer_id = fc.customer_id AND t.txn_month = fc.txn_month
    WHERE t.status = 'Failed';

    -- Rule 4: Credit Limit Breach
    INSERT INTO risk_alerts (txn_id, customer_id, merchant_id, alert_type, alert_level, alert_detail, amount, txn_date)
    SELECT
        t.txn_id, t.customer_id, t.merchant_id,
        'CREDIT_BREACH',
        CASE
            WHEN t.amount / c.credit_limit >= 1.0 THEN 'CRITICAL'
            WHEN t.amount / c.credit_limit >= 0.9 THEN 'HIGH'
            ELSE 'MEDIUM'
        END,
        CONCAT('Transaction is ', ROUND(t.amount/c.credit_limit*100,1), '% of ₹', c.credit_limit, ' credit limit'),
        t.amount, t.txn_date
    FROM transactions t
    JOIN customers c ON t.customer_id = c.customer_id
    WHERE t.amount >= (0.8 * c.credit_limit)
      AND t.status IN ('Success','Failed');

    SELECT
        alert_type,
        alert_level,
        COUNT(*) AS alerts_generated
    FROM risk_alerts
    GROUP BY alert_type, alert_level
    ORDER BY alert_type, FIELD(alert_level,'CRITICAL','HIGH','MEDIUM','LOW');
END $$

DELIMITER ;


-- ════════════════════════════════════════════════════════════
-- SECTION D: QUICK-RUN COMMANDS
-- ════════════════════════════════════════════════════════════

-- View executive risk summary
SELECT * FROM vw_risk_executive_summary;

-- View all CRITICAL high-value anomalies
SELECT * FROM vw_high_value_anomalies
WHERE alert_level = 'CRITICAL'
ORDER BY spend_multiplier DESC;

-- View all HIGH RISK customers
SELECT * FROM vw_customer_risk_profile
WHERE risk_category = 'HIGH RISK'
ORDER BY failed_txns DESC;

-- View all HIGH RISK merchants
SELECT * FROM vw_merchant_risk_profile
WHERE risk_category = 'HIGH RISK'
ORDER BY failure_rate_pct DESC;

-- Run full risk dashboard (4 result sets)
CALL sp_risk_dashboard();

-- Deep dive on a specific customer
CALL sp_customer_risk_deepdive('C00058');

-- Populate risk alerts log (run nightly)
CALL sp_populate_risk_alerts();

-- Query alerts log after populating
SELECT alert_type, alert_level, COUNT(*) AS count
FROM risk_alerts
GROUP BY alert_type, alert_level
ORDER BY alert_type, FIELD(alert_level,'CRITICAL','HIGH','MEDIUM','LOW');
