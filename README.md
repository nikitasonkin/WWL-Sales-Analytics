# WWL Sales Analytics 📊

> **Author:** Nikita Sonkin  
> **Database:** Wide World Importers  
> **License:** MIT

## Overview
This repository contains a curated set of **10 advanced T-SQL queries** designed to extract business-critical insights from Microsoft’s *Wide World Importers* (WWI) sample database.  
The script `annual_sales_queries.sql` can be used as a ready-made analytics toolkit for answering questions around yearly revenue, customer performance, product profitability, churn detection and more.

## File Structure



## Prerequisites
* SQL Server 2019 + (or Azure SQL) with the **WideWorldImporters** and **WideWorldImportersDW** databases installed.
* Sufficient privileges to create CTEs, run window functions, and use `PIVOT`.

## How to Run
1. Open SQL Server Management Studio (SSMS) / Azure Data Studio.  
2. Select the **WideWorldImporters** context.  
3. Execute `annual_sales_queries.sql` as-is or copy individual queries as needed.  
4. Review result sets and adjust `WHERE` filters or date ranges to fit your reporting cycle.

## Query Catalogue

| # | Topic | Business Question |
|---|-------|-------------------|
| 1 | **Yearly Income & CAGR** | What is the total income per year, linearized income, and YoY growth? |
| 2 | **Top-5 Customers per Quarter** | Which customers generated the highest revenue each quarter? |
| 3 | **Most Profitable Stock Items** | Top 10 products by net profit (ex. tax). |
| 4 | **Price Spread Analysis** | Rank items by margin between RRP and unit cost. |
| 5 | **Supplier-Product Roll-Up** | Show each supplier with a comma-separated list of products. |
| 6 | **High-Value Regions** | Identify the five customers that generated the most extended price by region. |
| 7 | **Monthly & Cumulative Sales** | Display month-to-date and running totals. |
| 8 | **Orders Pivot Table** | Orders count per month across years (pivot view). |
| 9 | **Customer Activity & Churn Risk** | Days since last order and churn flag. |
| 10| **Customer Category Distribution** | How are customers distributed across categories? |

*(See inline comments in `annual_sales_queries.sql` for detailed logic.)* :contentReference[oaicite:0]{index=0}:contentReference[oaicite:1]{index=1}

## Customisation Tips
* Replace hard-coded years or categories with parameters if automating in SSIS/ADF.  
* Wrap each query into a view or stored procedure for easier reuse.  

## Contributing
Pull requests are welcome for performance tuning, additional KPIs, or adaptations to other sample DBs.

---
