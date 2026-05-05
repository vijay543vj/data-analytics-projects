-- ============================================================
-- PROJECT 1: MIS Report Queries, Views & Stored Procedures
-- Author   : Vijay | Data Analyst Portfolio
-- Database : merchant_mis
-- Run AFTER 02_load_data.sql
-- ============================================================

USE merchant_mis;

-- ════════════════════════════════════════════════════════════
-- SECTION A: VIEWS (Permanent reusable reporting layers)
-- ════════════════════════════════════════════════════════════

-- ─── VIEW 1: Monthly MIS Summary ─────────────────────────────
-- Purpose: Auto-refreshing monthly KPI view. Query this view
--          from any BI tool or dashboard to get current numbers.
CREATE OR REPLACE VIEW vw_monthly_mis_summary AS
SELECT
    txn_month,
    COUNT(*)                                                       AS total_txns,
    SUM(status = 'Success')                                        AS successful_txns,
    SUM(status = 'Failed')                                         AS failed_txns,
    SUM(status = 'Disputed')                                       AS disputed_txns,
    SUM(status = 'Reversed')                                       AS reversed_txns,
    ROUND(SUM(CASE WHEN status='Success' THEN amount     ELSE 0 END)/100000, 2) AS gross_revenue_lakhs,
    ROUND(SUM(CASE WHEN status='Success' THEN net_settlement_amount ELSE 0 END)/100000, 2) AS net_settlement_lakhs,
    ROUND(SUM(processing_fee)/100000, 2)                           AS fees_collected_lakhs,
    ROUND(100.0 * SUM(status='Success') / COUNT(*), 2)            AS success_rate_pct,
    ROUND(100.0 * SUM(status='Disputed') / COUNT(*), 2)           AS dispute_rate_pct,
    ROUND(AVG(amount), 2)                                          AS avg_txn_amount,
    SUM(risk_flag = 'Yes')                                         AS risk_flagged_txns
FROM transactions
GROUP BY txn_month
ORDER BY txn_month;

-- ─── VIEW 2: Merchant Scorecard ──────────────────────────────
-- Purpose: Per-merchant KPI dashboard with GREEN/AMBER/RED
--          health classification for account managers.
CREATE OR REPLACE VIEW vw_merchant_scorecard AS
SELECT
    m.merchant_id,
    m.merchant_name,
    m.category,
    m.region,
    m.city,
    m.contract_type,
    m.settlement_cycle_days,
    COUNT(t.txn_id)                                                AS total_txns,
    ROUND(SUM(CASE WHEN t.status='Success' THEN t.amount ELSE 0 END)/100000, 2) AS revenue_lakhs,
    ROUND(100.0 * SUM(t.status='Success') / COUNT(*), 2)          AS success_rate_pct,
    SUM(t.risk_flag = 'Yes')                                       AS risk_txns,
    (SELECT COUNT(*) FROM disputes d WHERE d.merchant_id = m.merchant_id) AS total_disputes,
    ROUND(
        (SELECT AVG(d.resolution_days) FROM disputes d
         WHERE d.merchant_id = m.merchant_id AND d.resolution_status = 'Resolved'), 1
    )                                                              AS avg_dispute_resolution_days,
    CASE
        WHEN ROUND(100.0 * SUM(t.status='Success')/COUNT(*), 2) >= 90
         AND SUM(t.risk_flag='Yes') = 0  THEN 'GREEN'
        WHEN ROUND(100.0 * SUM(t.status='Success')/COUNT(*), 2) >= 75 THEN 'AMBER'
        ELSE 'RED'
    END                                                            AS health_status
FROM merchants m
JOIN transactions t ON m.merchant_id = t.merchant_id
GROUP BY m.merchant_id, m.merchant_name, m.category, m.region,
         m.city, m.contract_type, m.settlement_cycle_days;

-- ─── VIEW 3: Customer Spend Profile ──────────────────────────
CREATE OR REPLACE VIEW vw_customer_profile AS
SELECT
    c.customer_id,
    c.customer_name,
    c.customer_segment,
    c.credit_limit,
    COUNT(t.txn_id)                                                AS total_txns,
    ROUND(SUM(CASE WHEN t.status='Success' THEN t.amount ELSE 0 END)/100000, 2) AS total_spend_lakhs,
    ROUND(AVG(CASE WHEN t.status='Success' THEN t.amount END), 2) AS avg_spend,
    ROUND(100.0 * SUM(t.status='Failed') / COUNT(*), 2)           AS failure_rate_pct,
    SUM(t.risk_flag='Yes')                                         AS risk_txns,
    MAX(t.txn_date)                                                AS last_txn_date
FROM customers c
LEFT JOIN transactions t ON c.customer_id = t.customer_id
GROUP BY c.customer_id, c.customer_name, c.customer_segment, c.credit_limit;


-- ════════════════════════════════════════════════════════════
-- SECTION B: STORED PROCEDURES
-- ════════════════════════════════════════════════════════════

DELIMITER $$

-- ─── PROCEDURE 1: Monthly MIS Report ─────────────────────────
-- Usage: CALL sp_monthly_mis_report('2023-08');
-- Pass any YYYY-MM value to get that month's full MIS report.
DROP PROCEDURE IF EXISTS sp_monthly_mis_report $$
CREATE PROCEDURE sp_monthly_mis_report(IN p_month VARCHAR(7))
BEGIN
    -- Summary KPIs
    SELECT
        txn_month                              AS report_month,
        total_txns,
        successful_txns,
        failed_txns,
        disputed_txns,
        gross_revenue_lakhs,
        net_settlement_lakhs,
        fees_collected_lakhs,
        success_rate_pct,
        dispute_rate_pct,
        risk_flagged_txns
    FROM vw_monthly_mis_summary
    WHERE txn_month = p_month;

    -- Top 5 merchants that month
    SELECT
        m.merchant_name,
        m.category,
        COUNT(t.txn_id)                        AS txns,
        ROUND(SUM(CASE WHEN t.status='Success' THEN t.amount ELSE 0 END)/100000,2) AS revenue_lakhs,
        ROUND(100.0 * SUM(t.status='Success')/COUNT(*),2) AS success_rate_pct
    FROM transactions t
    JOIN merchants m ON t.merchant_id = m.merchant_id
    WHERE t.txn_month = p_month
    GROUP BY m.merchant_id, m.merchant_name, m.category
    ORDER BY revenue_lakhs DESC
    LIMIT 5;

    -- Payment mode breakdown that month
    SELECT
        payment_mode,
        COUNT(*)                               AS txns,
        ROUND(SUM(CASE WHEN status='Success' THEN amount ELSE 0 END)/100000,2) AS revenue_lakhs,
        ROUND(100.0 * SUM(status='Success')/COUNT(*),2) AS success_rate_pct
    FROM transactions
    WHERE txn_month = p_month
    GROUP BY payment_mode
    ORDER BY txns DESC;
END $$

-- ─── PROCEDURE 2: Merchant Health Report ─────────────────────
-- Usage: CALL sp_merchant_health_report('RED');
-- Pass 'GREEN', 'AMBER', or 'RED' to filter by health status.
DROP PROCEDURE IF EXISTS sp_merchant_health_report $$
CREATE PROCEDURE sp_merchant_health_report(IN p_status VARCHAR(10))
BEGIN
    SELECT
        merchant_id,
        merchant_name,
        category,
        region,
        contract_type,
        total_txns,
        revenue_lakhs,
        success_rate_pct,
        risk_txns,
        total_disputes,
        avg_dispute_resolution_days,
        health_status
    FROM vw_merchant_scorecard
    WHERE health_status = p_status
    ORDER BY revenue_lakhs DESC;
END $$

-- ─── PROCEDURE 3: SLA Breach Report ──────────────────────────
-- Usage: CALL sp_sla_breach_report();
-- Identifies merchants settling payments beyond their SLA.
DROP PROCEDURE IF EXISTS sp_sla_breach_report $$
CREATE PROCEDURE sp_sla_breach_report()
BEGIN
    SELECT
        m.merchant_id,
        m.merchant_name,
        m.contract_type,
        m.settlement_cycle_days                AS sla_days,
        COUNT(t.txn_id)                        AS settled_txns,
        SUM(
            DATEDIFF(t.settlement_date, t.txn_date) > m.settlement_cycle_days
        )                                      AS sla_breaches,
        ROUND(100.0 * SUM(
            DATEDIFF(t.settlement_date, t.txn_date) > m.settlement_cycle_days
        ) / COUNT(t.txn_id), 2)               AS breach_rate_pct,
        ROUND(AVG(DATEDIFF(t.settlement_date, t.txn_date)), 2) AS avg_settlement_days
    FROM merchants m
    JOIN transactions t ON m.merchant_id = t.merchant_id
    WHERE t.status = 'Success'
      AND t.settlement_date IS NOT NULL
    GROUP BY m.merchant_id, m.merchant_name, m.contract_type, m.settlement_cycle_days
    HAVING COUNT(t.txn_id) >= 20
    ORDER BY breach_rate_pct DESC
    LIMIT 20;
END $$

DELIMITER ;


-- ════════════════════════════════════════════════════════════
-- SECTION C: MIS REPORT QUERIES (Run individually)
-- ════════════════════════════════════════════════════════════

-- ─── REPORT 1: Full Year Monthly Summary ─────────────────────
SELECT * FROM vw_monthly_mis_summary;

-- ─── REPORT 2: Top 10 Merchants by Revenue ───────────────────
SELECT
    merchant_id, merchant_name, category, region,
    total_txns, revenue_lakhs, success_rate_pct,
    total_disputes, health_status
FROM vw_merchant_scorecard
ORDER BY revenue_lakhs DESC
LIMIT 10;

-- ─── REPORT 3: Bottom 10 Merchants by Success Rate ───────────
SELECT
    merchant_id, merchant_name, category,
    total_txns, revenue_lakhs, success_rate_pct, health_status
FROM vw_merchant_scorecard
WHERE total_txns >= 50
ORDER BY success_rate_pct ASC
LIMIT 10;

-- ─── REPORT 4: Dispute Resolution by Category ────────────────
SELECT
    m.category,
    COUNT(d.dispute_id)                                           AS total_disputes,
    SUM(d.resolution_status = 'Resolved')                        AS resolved,
    SUM(d.resolution_status = 'Pending')                         AS pending,
    SUM(d.resolution_status = 'Escalated')                       AS escalated,
    ROUND(100.0 * SUM(d.resolution_status='Resolved')/COUNT(*),2) AS resolution_rate_pct,
    ROUND(AVG(d.resolution_days),1)                              AS avg_resolution_days,
    ROUND(SUM(d.amount)/100000,2)                                AS disputed_amount_lakhs
FROM disputes d
JOIN merchants m ON d.merchant_id = m.merchant_id
GROUP BY m.category
ORDER BY total_disputes DESC;

-- ─── REPORT 5: Regional Performance ─────────────────────────
SELECT
    m.region,
    COUNT(DISTINCT m.merchant_id)                                 AS active_merchants,
    COUNT(t.txn_id)                                               AS total_txns,
    ROUND(SUM(CASE WHEN t.status='Success' THEN t.amount ELSE 0 END)/100000,2) AS revenue_lakhs,
    ROUND(100.0 * SUM(t.status='Success')/COUNT(*),2)            AS success_rate_pct,
    ROUND(100.0 * SUM(t.status='Disputed')/COUNT(*),2)           AS dispute_rate_pct,
    ROUND(AVG(t.amount),2)                                        AS avg_txn_amount
FROM merchants m
JOIN transactions t ON m.merchant_id = t.merchant_id
GROUP BY m.region
ORDER BY revenue_lakhs DESC;

-- ─── REPORT 6: Payment Mode Analysis ─────────────────────────
SELECT
    payment_mode,
    COUNT(*)                                                      AS total_txns,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM transactions),2) AS volume_share_pct,
    ROUND(SUM(CASE WHEN status='Success' THEN amount ELSE 0 END)/100000,2) AS revenue_lakhs,
    ROUND(100.0 * SUM(status='Success')/COUNT(*),2)              AS success_rate_pct,
    ROUND(100.0 * SUM(status='Failed')/COUNT(*),2)               AS failure_rate_pct
FROM transactions
GROUP BY payment_mode
ORDER BY total_txns DESC;

-- ─── REPORT 7: Category Performance ─────────────────────────
SELECT
    m.category,
    COUNT(DISTINCT m.merchant_id)                                 AS merchants,
    COUNT(t.txn_id)                                               AS total_txns,
    ROUND(SUM(CASE WHEN t.status='Success' THEN t.amount ELSE 0 END)/100000,2) AS revenue_lakhs,
    ROUND(100.0 * SUM(t.status='Success')/COUNT(*),2)            AS success_rate_pct,
    ROUND(AVG(t.amount),2)                                        AS avg_txn_amount
FROM merchants m
JOIN transactions t ON m.merchant_id = t.merchant_id
GROUP BY m.category
ORDER BY revenue_lakhs DESC;

-- ─── CALL STORED PROCEDURES ──────────────────────────────────
-- Get full MIS report for a specific month:
CALL sp_monthly_mis_report('2023-08');

-- Get all RED health merchants:
CALL sp_merchant_health_report('RED');

-- Get SLA breach report:
CALL sp_sla_breach_report();
