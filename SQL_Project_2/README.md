# 🚨 Credit Card Transaction Risk Flagging System (MySQL)

**SQL Portfolio Project | Vijay | Data Analyst**

---

## 🔍 Project Summary

- Designed a rule-based risk detection system for transaction monitoring
- Analyzed **12,000+ transactions** to identify fraud patterns and anomalies
- Flagged high-risk customers and merchants using SQL-based logic

---

## 🎯 Business Problem

A financial services company required an automated system to detect suspicious transactions in real time. Manual monitoring was inefficient and failed to identify:

- High-value anomalies
- Rapid transaction spikes (velocity)
- Repeated failures and risky merchant behavior

---

## 💡 Solution

Developed a SQL-based risk detection engine with:

- 5 rule-based fraud detection mechanisms
- 4 analytical views for monitoring
- 3 stored procedures for automation and reporting
- Centralized alert logging system (`risk_alerts` table)

---

## 📊 Key Insights

- ~5% of transactions were flagged as high risk
- High-value anomalies formed the largest risk category
- A small group of customers and merchants contributed disproportionately to risk
- Velocity spikes and repeated failures were strong indicators of suspicious behavior

---

## 📁 Project Structure

```id="r5k3xp"
project2_mysql_risk/
├── schema/
│   ├── 01_create_database.sql
│   └── 02_load_data.sql
├── queries/
│   └── 03_risk_detection.sql
├── reports/
│   └── Risk_Analyst_Report.pdf
├── data/
│   ├── merchants.csv
│   ├── customers.csv
│   └── transactions.csv
└── README.md
```

---

## 🔍 Risk Detection Rules

| Rule                | Description                                                |
| ------------------- | ---------------------------------------------------------- |
| High-Value Anomaly  | Transaction significantly exceeds customer’s average spend |
| Velocity Check      | Multiple transactions within a short time window           |
| Repeated Failure    | Multiple failed attempts indicating potential fraud        |
| Credit Limit Breach | Transaction nearing or exceeding credit limit              |
| Merchant Anomaly    | Merchants with high failure rate and large transactions    |

---

## 🗃️ Database Components

### Tables

- `risk_alerts` → Stores all flagged transactions

### Views

- `vw_high_value_anomalies` → High-value transaction flags
- `vw_customer_risk_profile` → Customer-level risk aggregation
- `vw_merchant_risk_profile` → Merchant-level risk categorization
- `vw_risk_executive_summary` → Overall risk KPIs

### Stored Procedures

- `sp_risk_dashboard()` → Complete risk overview (multiple result sets)
- `sp_customer_risk_deepdive(id)` → Detailed customer-level analysis
- `sp_populate_risk_alerts()` → Executes all rules and updates alerts table

---

## 📈 Results (2023)

| Metric                    | Value  |
| ------------------------- | ------ |
| Total Transactions        | 12,000 |
| Risk-Flagged Transactions | 600    |
| High-Value Anomalies      | 975    |
| Critical Alerts           | 50     |
| High-Risk Customers       | 37     |
| High-Risk Merchants       | 65     |

---

## 💼 Business Value

- Enables early detection of fraudulent transactions
- Reduces financial risk through proactive monitoring
- Provides actionable insights for compliance and risk teams
- Forms a foundation for advanced fraud detection systems

---

## 🔑 SQL Skills Demonstrated

`Joins` · `Subqueries` · `CASE WHEN` · `Views` · `Stored Procedures` · `Data Modeling` · `Conditional Logic` · `Date Functions` · `Aggregation`

---

## 🚀 How to Run

```sql id="t8mb1w"
-- Step 1: Create database and tables
01_create_database.sql

-- Step 2: Load data
02_load_data.sql

-- Step 3: Execute risk detection logic
03_risk_detection.sql

-- Example usage
SELECT * FROM vw_risk_executive_summary;
CALL sp_risk_dashboard();
CALL sp_customer_risk_deepdive('C00058');
CALL sp_populate_risk_alerts();
```

---

## 📌 Output

A rule-based transaction monitoring system capable of identifying high-risk behavior and supporting fraud prevention efforts.
