# 📊 MIS Reporting System — Merchant Network (MySQL)

**SQL Portfolio Project | Vijay | Data Analyst**

---

## 🔍 Project Summary

- Built an automated MIS reporting system replacing manual Excel-based reporting
- Processed **12,000+ transactions** across **120+ merchants**
- Delivered insights on revenue, risk, disputes, and SLA compliance using SQL

---

## 🎯 Business Problem

A payments company managing a network of merchants relied on manual Excel reports to track performance. This led to:

- Delayed reporting
- Inconsistent calculations
- Limited visibility into risk and merchant performance

---

## 💡 Solution

Designed a normalized MySQL database and developed reusable SQL components:

- 4 relational tables
- 3 analytical views
- 3 stored procedures
- 7 business-focused MIS reports

The system enables automated, repeatable reporting with minimal manual effort.

---

## 📊 Key Insights

- Majority of transactions are successful, indicating stable operations
- Risk-flagged transactions are low but concentrated among specific merchants
- SLA breaches highlight delayed settlements in certain contract types
- Dispute resolution performance varies across merchant categories

---

## 📁 Project Structure

```
project1_mysql_mis/
├── schema/
│   ├── 01_create_database.sql
│   └── 02_load_data.sql
├── queries/
│   └── 03_mis_queries.sql
├── reports/
│   └── MIS_Report_December_2023.pdf
├── data/
│   ├── merchants.csv
│   ├── customers.csv
│   ├── transactions.csv
│   └── disputes.csv
└── README.md
```

---

## 🗃️ Database Schema

| Table        | Rows   | Description                                        |
| ------------ | ------ | -------------------------------------------------- |
| merchants    | 120    | Merchant details (category, region, contract type) |
| customers    | 800    | Customer segments and credit limits                |
| transactions | 12,000 | Transaction records with status and risk flags     |
| disputes     | 747    | Dispute cases and resolution timelines             |

---

## ⚙️ Core Components

### Views

- `vw_monthly_mis_summary` → Monthly KPI aggregation
- `vw_merchant_scorecard` → Merchant health classification
- `vw_customer_profile` → Customer behavior analysis

### Stored Procedures

- `sp_monthly_mis_report(month)` → Generates monthly MIS report
- `sp_merchant_health_report(status)` → Filters merchants by health status
- `sp_sla_breach_report()` → Identifies SLA violations

---

## 📈 Reports Generated

- Monthly performance summary
- Top & bottom merchants
- Dispute resolution analysis
- SLA breach tracking
- Regional performance
- Payment mode trends

---

## 💼 Business Value

- Reduced manual reporting effort
- Enabled faster decision-making
- Improved visibility into merchant performance and risk
- Standardized reporting across the organization

---

## 🔑 SQL Skills Demonstrated

`Joins` · `Aggregations` · `CASE WHEN` · `Views` · `Stored Procedures` · `Data Modeling` · `Foreign Keys` · `DATEDIFF` · `Conditional Logic`

---

## 🚀 How to Run

```sql
-- Step 1: Run database setup
01_create_database.sql

-- Step 2: Load data
02_load_data.sql

-- Step 3: Run queries (views + procedures + reports)
03_mis_queries.sql

-- Example usage
CALL sp_monthly_mis_report('2023-08');
CALL sp_merchant_health_report('RED');
CALL sp_sla_breach_report();
```

---

## 📌 Output

A structured MIS reporting system capable of generating business insights and supporting operational decisions using SQL.
