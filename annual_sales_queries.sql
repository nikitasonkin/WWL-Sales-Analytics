/*  Query 1 – Year-over-Year Income & Growth  */
WITH sce AS (
    SELECT 
        YEAR(o.OrderDate) AS [Year],
        SUM(il.Quantity * il.UnitPrice)                    AS IncomePerYear,
        COUNT(DISTINCT MONTH(o.OrderDate))                AS NumberOfDistinctMonths,
        CAST(SUM(il.Quantity * il.UnitPrice)
             / COUNT(DISTINCT MONTH(o.OrderDate)) * 12
             AS DECIMAL(10,2))                            AS LinearYearlyIncome
    FROM  Sales.Orders        AS o
    JOIN  Sales.Invoices      AS i  ON o.OrderID  = i.OrderID
    JOIN  Sales.InvoiceLines  AS il ON i.InvoiceID = il.InvoiceID
    GROUP BY YEAR(o.OrderDate)
)
SELECT  [Year],
        IncomePerYear,
        NumberOfDistinctMonths,
        LinearYearlyIncome,
        /* % growth vs. previous year */
        CASE
            WHEN LAG(LinearYearlyIncome) OVER (ORDER BY [Year]) IS NOT NULL
            THEN CAST(
                (LinearYearlyIncome 
                 - LAG(LinearYearlyIncome) OVER (ORDER BY [Year]))
                / LAG(LinearYearlyIncome) OVER (ORDER BY [Year]) * 100
                AS DECIMAL(10,2))
        END AS GrowthRate
FROM  sce
ORDER BY [Year];


/*  Query 2 –  Top-5 Customers per Quarter (By Income)   */
WITH cte AS (
    SELECT
        YEAR(o.OrderDate)   AS TheYear,   -- Calendar year of the order
        DATEPART(QUARTER, o.OrderDate)   AS TheQuarter, -- 1..4 quarter number
        c.CustomerName,  -- Customer being analysed
        SUM(ii.Quantity * ii.UnitPrice)  AS Income,-- Total sales value
        /* Dense rank: 1 = highest Income within each year-quarter */
        DENSE_RANK() OVER (PARTITION BY
                           YEAR(o.OrderDate),
                           DATEPART(QUARTER, o.OrderDate)
                           ORDER BY SUM(ii.Quantity * ii.UnitPrice) DESC) AS DNR
    FROM  Sales.Customers     AS c
    INNER JOIN Sales.Invoices       AS i  ON c.CustomerID = i.CustomerID
    INNER JOIN Sales.InvoiceLines   AS ii ON i.InvoiceID  = ii.InvoiceID
    INNER JOIN Sales.Orders         AS o  ON i.OrderID    = o.OrderID
    /* Aggregate per customer, year & quarter */
    GROUP BY
        YEAR(o.OrderDate),
        DATEPART(QUARTER, o.OrderDate),
        c.CustomerName
)

/* Select only the top-5 (DNR ≤ 5) for each year-quarter */
SELECT  TheYear,
        TheQuarter,
        CustomerName,
        Income,
        DNR    -- Rank position (1-5)
FROM    cte
WHERE   DNR <= 5  -- keep Top-5 per quarter
ORDER BY TheYear, TheQuarter, DNR;  -- chronological then rank order


/*  Query 3 –  Top-10 Most Profitable Stock Items  */
SELECT TOP 10
       si.StockItemID,
       si.StockItemName,
       SUM(il.ExtendedPrice - il.TaxAmount) AS TotalProfit  -- gross profit per item
FROM   Warehouse.StockItems  AS si
INNER JOIN Sales.InvoiceLines AS il
       ON il.StockItemID = si.StockItemID -- link each invoice line to its stock item
GROUP BY
       si.StockItemID,
       si.StockItemName
ORDER BY
       TotalProfit DESC;  -- highest profit first


/*  Query 4 –  Nominal Product Profit & Ranking  */
Select ROW_NUMBER() over(order by NominalProductProdit desc) as rn,* , 
DENSE_RANK() over (order by NominalProductProdit desc) as DNR
from ( select 
[StockItemID],[StockItemName],[UnitPrice],[RecommendedRetailPrice],
[RecommendedRetailPrice] - [UnitPrice] as NominalProductProdit
from [Warehouse].[StockItems] ) a

	
/*  Query 5 – Supplier-Product Roll-Up (Comma-Separated List) */
SELECT *
FROM (
    SELECT
        /* Combine ID + name for readability */
        CAST(s.SupplierID AS VARCHAR) + ' ' + s.SupplierName      AS SupplierDetails,

        /* Build CSV-style list of all items sold by this supplier */
        STUFF((
            SELECT '/, ' + CAST(si.StockItemID AS VARCHAR) + ' ' + si.StockItemName
            FROM   Warehouse.StockItems AS si
            WHERE  si.SupplierID = s.SupplierID
            FOR XML PATH('')             -- concatenate into one XML string
        ), 1, 2, '')                                            AS ProductDetails
    FROM Purchasing.Suppliers AS s
) a
/* Keep only suppliers that have at least one product */
WHERE ProductDetails IS NOT NULL;


/*  Query 6 – Top-5 Customers by Total Extended Price + Geo Details */
SELECT TOP 5
       c.CustomerID,
       ac.CityName,
       acc.CountryName,
       acc.Continent,
       acc.Region,
       FORMAT(SUM(il.ExtendedPrice), '#,##0.00') AS TotalExtendedPrice
FROM   Sales.Customers      AS c
INNER JOIN Sales.Invoices        AS i  ON c.CustomerID   = i.CustomerID
INNER JOIN Sales.InvoiceLines    AS il ON i.InvoiceID    = il.InvoiceID
INNER JOIN Application.Cities            AS ac ON c.DeliveryCityID = ac.CityID
INNER JOIN Application.StateProvinces    AS sp ON ac.StateProvinceID = sp.StateProvinceID
INNER JOIN Application.Countries         AS acc ON sp.CountryID      = acc.CountryID
GROUP BY
       c.CustomerID,
       ac.CityName,
       acc.CountryName,
       acc.Continent,
       acc.Region
ORDER BY
       SUM(il.ExtendedPrice) DESC;    -- highest spend first


/*  Query 7 – Monthly Sales, Running Totals, and Yearly Grand Totals */
WITH cte AS (
    /* ——— 1. Detail rows: one for each distinct Year-Month ——— */
    SELECT DISTINCT
           YEAR(o.OrderDate)  AS OrderYear,
           MONTH(o.OrderDate) AS OrderMonth,
           /* Total sales for that month across all years, by month key */
           SUM(ol.UnitPrice * ol.Quantity)
               OVER (PARTITION BY MONTH(o.OrderDate)
                     ORDER BY YEAR(o.OrderDate))                     AS Sales,
           /* Running total within the same year */
           SUM(ol.UnitPrice * ol.Quantity)
               OVER (PARTITION BY YEAR(o.OrderDate)
                     ORDER BY MONTH(o.OrderDate))                    AS RunningTotal
    FROM  Sales.Orders      AS o
    JOIN  Sales.OrderLines  AS ol ON o.OrderID = ol.OrderID
    JOIN  Sales.Invoices    AS i  ON o.OrderID = i.OrderID

    UNION ALL

    /* ——— 2. Summary rows: one GrandTotal per year ——— */
    SELECT DISTINCT
           YEAR(o.OrderDate)  AS OrderYear,
           NULL               AS OrderMonth,          -- flag for GrandTotal row
           SUM(ol.UnitPrice * ol.Quantity)            AS Sales,        -- yearly total
           SUM(ol.UnitPrice * ol.Quantity)            AS RunningTotal  -- same as yearly total
    FROM  Sales.Orders      AS o
    JOIN  Sales.OrderLines  AS ol ON o.OrderID = ol.OrderID
    JOIN  Sales.Invoices    AS i  ON o.OrderID = i.OrderID
    GROUP BY YEAR(o.OrderDate)
)
SELECT
    OrderYear,
    /* Convert NULL month to the label “GrandTotal” */
    CASE WHEN OrderMonth IS NULL
         THEN 'GrandTotal'
         ELSE CAST(OrderMonth AS VARCHAR)
    END                                     AS OrderMonth,
    FORMAT(Sales,        '#,##0.00')        AS MonthlyTotal,
    FORMAT(RunningTotal, '#,##0.00')        AS CumulativeTotal
FROM   cte
ORDER BY
    OrderYear,
    ISNULL(OrderMonth, 13);   -- GrandTotal after month 12


/*  Query 8 – Pivot: Order Counts by Month and Year */
SELECT *
FROM (
    /* Base set: one row per OrderID with its year and month */
    SELECT DISTINCT
           MONTH(OrderDate) AS MonthOrder,   -- 1 = January … 12 = December
           OrderID,
           YEAR(OrderDate)  AS YearOrder
    FROM   Sales.Orders
) AS a
PIVOT (
    COUNT(OrderID)                     -- aggregate: number of orders
    FOR YearOrder IN ([2013],[2014],[2015],[2016])  -- create 1 column per year
) AS piv
ORDER BY MonthOrder;                   -- chronological month order


/*  Query 9 – Customer Order Gaps & Churn Flag */
WITH cte AS (                        -- Step 1: compute per-order gap
    SELECT
        c.CustomerID,
        c.CustomerName,
        o.OrderDate,

        /* previous order date for the same customer */
        LAG(o.OrderDate) OVER (PARTITION BY c.CustomerID
                               ORDER BY     o.OrderDate)  AS PreviousOrderDate,

        /* days between current and previous order (NULL for first) */
        CASE
            WHEN LAG(o.OrderDate) OVER (PARTITION BY c.CustomerID
                                        ORDER BY     o.OrderDate) IS NOT NULL
            THEN DATEDIFF(DAY,
                          LAG(o.OrderDate) OVER (PARTITION BY c.CustomerID
                                                 ORDER BY     o.OrderDate),
                          o.OrderDate)
        END                                               AS DaysSinceLastOrder
    FROM  Sales.Customers AS c
    JOIN  Sales.Orders    AS o ON c.CustomerID = o.CustomerID
)

SELECT
    CustomerID,
    CustomerName,
    OrderDate,
    PreviousOrderDate,
    DaysSinceLastOrder,

    /* customer-level mean gap (window aggregate) */
    AVG(DaysSinceLastOrder) OVER (PARTITION BY CustomerID) AS AvgSinceLastOrder,

    /* churn logic: gap > 2 × average → “Potential Churn” */
    CASE
        WHEN DaysSinceLastOrder >
             2 * AVG(DaysSinceLastOrder) OVER (PARTITION BY CustomerID)
        THEN 'Potential Churn'
        ELSE 'Active'
    END AS CustomerStatus
FROM cte
WHERE CustomerID IN (24, 25);        -- focus on two example customers


/*  Query 10 – Customer Counts & Percent Share by Category */
WITH cte AS (               -- Step 1: normalise names inside a CTE
    SELECT
        cc.CustomerCategoryName,
        CASE
            WHEN CustomerName LIKE 'Wingtip%'  THEN 'Wingtip'   -- bucket all Wingtip* names
            WHEN CustomerName LIKE 'tailspin%' THEN 'tailspin'  -- bucket all tailspin* names
            ELSE CustomerName                                   -- otherwise keep original
        END AS CustomerName
    FROM Sales.CustomerCategories AS cc
    INNER JOIN Sales.Customers   AS c
           ON cc.CustomerCategoryID = c.CustomerCategoryID
)

/* Step 2: counts and percentages */
SELECT
    CustomerCategoryName,

    COUNT(DISTINCT CustomerName)                           AS CategoryCount,     -- cc
    SUM(COUNT(DISTINCT CustomerName)) OVER ()              AS TotalCustomers,    -- ccc
    CONCAT(
        CAST(
            CAST(COUNT(DISTINCT CustomerName) AS DECIMAL(10,2))
            / CAST(SUM(COUNT(DISTINCT CustomerName)) OVER () AS DECIMAL(10,2))
            * 100 AS DECIMAL(10,2)
        ), '%')                                            AS CategoryPct        -- cccc
FROM   cte
GROUP BY CustomerCategoryName
ORDER BY CustomerCategoryName;
















