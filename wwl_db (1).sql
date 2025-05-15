----שאילתה מספר 1

with sce as(
select 
year(orderdate) as year , 
sum(Quantity*UnitPrice) as IncomePerYear ,
COUNT(DISTINCT MONTH(ORDERDATE)) as NumberOfDistinctMonths,
cast(sum(Quantity*UnitPrice)/COUNT(DISTINCT MONTH(ORDERDATE))*12 as decimal(10,2))  as LinearYearlyIncome
from [Sales].[Orders] o  join [Sales].Invoices i on o.OrderID = i.OrderID
inner join Sales.InvoiceLines il on i.InvoiceID = IL.InvoiceID
GROUP BY year(orderdate)
) 
select year , IncomePerYear , NumberOfDistinctMonths ,LinearYearlyIncome,
CASE
     when lag(LinearYearlyIncome) over ( order by year) is not null
	 then cast(( (LinearYearlyIncome - cast(LAG(LinearYearlyIncome) OVER (ORDER BY year)as decimal(10,2))) 
                        / LAG(LinearYearlyIncome) OVER (ORDER BY year)) * 100 as decimal(10,2))
	ELSE NULL
	 end as GrowthRate 
from sce 
order by year


--שאילתה מספר 2

WITH cte AS (  
				SELECT YEAR(orderdate) AS TheYear,
				DATEPART(QUARTER, orderdate) AS TheQuarter,
				[CustomerName],
				SUM(Quantity * UnitPrice) AS Income,
				DENSE_RANK() OVER (partition by YEAR(orderdate),DATEPART(QUARTER, orderdate) ORDER BY SUM(Quantity * UnitPrice) desc) AS DNR


		FROM [Sales].[Customers] c inner join [Sales].[Invoices] i on c.CustomerID = i.CustomerID
		inner join [Sales].[InvoiceLines] ii on i.InvoiceID=ii.InvoiceID
		inner join [Sales].[Orders] o on i.OrderID = o.OrderID


    GROUP BY YEAR(orderdate),DATEPART(QUARTER, orderdate),[CustomerName])

SELECT TheYear,TheQuarter,[CustomerName],Income,DNR
FROM cte
WHERE DNR <= 5
ORDER BY TheYear, TheQuarter , DNR ;


--שאילתה מספר 3

select top 10  si.[StockItemID],[StockItemName],SUM([ExtendedPrice] - il.TaxAmount) AS TotalProfit
from [Warehouse].[StockItems] si inner join [Sales].[InvoiceLines] il on il.StockItemID = si.StockItemID
group by si.[StockItemID],[StockItemName]
order by TotalProfit desc

--שאילתה מס 4

Select ROW_NUMBER() over(order by NominalProductProdit desc) as rn,* , 
DENSE_RANK() over (order by NominalProductProdit desc) as DNR
from ( select 
[StockItemID],[StockItemName],[UnitPrice],[RecommendedRetailPrice],
[RecommendedRetailPrice] - [UnitPrice] as NominalProductProdit
from [Warehouse].[StockItems] ) a

--שאילתה מספק 5

select * from (
Select 
cast(s.SupplierID as varchar)  + ' ' + s.SupplierName as SupplierDetails,
STUFF((
	select '/, ' + cast(si.StockItemID as varchar) + ' ' + si.StockItemName
	from [Warehouse].[StockItems] si
	where si.SupplierID = s.SupplierID 
	FOR XML PATH('')), 1, 2, '') AS ProductDetails
from [Purchasing].[Suppliers] s) a 

where ProductDetails is not null



--שאילתה מספר 6

select top 5 
c.CustomerID, ac.CityName , acc.CountryName , acc.Continent , acc.Region,
format(sum(ExtendedPrice), '#,##0.00') as TotalExtendedPrice


from [Sales].[Customers] c inner join [Sales].[Invoices] i on c.CustomerID=i.CustomerID
inner join [Sales].[InvoiceLines] il on i.InvoiceID = il.InvoiceID
inner join [Application].[Cities] ac on c.DeliveryCityID = ac.CityID
inner join [Application].[StateProvinces] sp on ac.StateProvinceID = sp.StateProvinceID
inner join [Application].[Countries] acc on sp.CountryID = acc.CountryID

group by c.CustomerID, ac.CityName , acc.CountryName , acc.Continent , acc.Region
order by sum(ExtendedPrice) desc


--שאילתה 7 

WITH cte AS (
    SELECT DISTINCT 
        YEAR(O.OrderDate) AS OrderYear, MONTH(O.OrderDate) AS OrderMonth,
        SUM(OL.UnitPrice * OL.Quantity) OVER (PARTITION BY MONTH(O.OrderDate) order by  YEAR(O.OrderDate)) AS Sales,
        SUM(OL.UnitPrice * OL.Quantity) OVER (PARTITION BY YEAR(O.OrderDate) ORDER BY MONTH(O.OrderDate)) AS RunningTotal
        from [Sales].[Orders] o 
    INNER JOIN [Sales].[OrderLines] ol ON o.OrderID = ol.OrderID
    INNER JOIN [Sales].[Invoices] i ON o.OrderID = i.OrderID
		
    UNION ALL

    SELECT distinct
        YEAR(O.OrderDate) AS OrderYear,NULL AS OrderMonth,SUM(OL.UnitPrice * OL.Quantity) AS Sales,SUM(OL.UnitPrice * OL.Quantity) AS RunningTotal
    from [Sales].[Orders] o 
    INNER JOIN [Sales].[OrderLines] ol ON o.OrderID = ol.OrderID
    INNER JOIN [Sales].[Invoices] i ON o.OrderID = i.OrderID
    GROUP BY YEAR(O.OrderDate))

SELECT 
    OrderYear,
    CASE 
        WHEN OrderMonth IS NULL THEN 'GrandTotal' 
        ELSE CAST(OrderMonth AS VARCHAR) 
    END  as OrderMonth,
    format(Sales,'#,##0.00') as 'MounthlyTotal', 
    format(RunningTotal,'#,##0.00') as 'CumulativeTotal'
FROM cte
ORDER BY 1, ISNULL(OrderMonth,13)


--שאילתה מספר 8 

select * from(
select distinct month(orderdate) as monthorder,OrderID,YEAR(orderdate) as yearorder
from [Sales].[Orders]) a
pivot(count(orderid) for yearorder in ([2013],[2014],[2015],[2016])) as piv
order by monthorder


--שאילתה מספר 9 

WITH cte AS (
    SELECT 
        c.CustomerID,
        c.CustomerName,
        o.OrderDate,
        LAG(OrderDate) OVER (PARTITION BY c.CustomerID ORDER BY OrderDate) AS PreviousOrderDate,

		CASE 
        WHEN LAG(OrderDate) OVER (PARTITION BY c.CustomerID ORDER BY OrderDate) IS NOT NULL 
        THEN DATEDIFF(DAY, LAG(OrderDate) OVER (PARTITION BY c.CustomerID ORDER BY OrderDate), OrderDate)
        ELSE NULL
    END AS DaysSinceLastOrder

    FROM 
        [Sales].[Customers] c
    INNER JOIN 
        [Sales].[Orders] o 
        ON c.CustomerID = o.CustomerID
)
SELECT 
    CustomerID,
    CustomerName,
    OrderDate,
	PreviousOrderDate,
	DaysSinceLastOrder,
	avg(DaysSinceLastOrder) over (partition by CustomerID) as AvgSinceLastOrder,

	case
		when day(PreviousOrderDate) > 2 * avg(DaysSinceLastOrder) over (partition by CustomerID)  
		then 'Potentiali Churn' 
		else 'active'
		end as CustomerStatus

FROM  cte
where customerid in (24,25)


--שאילתה מס 10
With cte as(
select 
cc.CustomerCategoryName,
		case when CustomerName like 'Wingtip%' then 'Wingtip'
		when CustomerName like 'tailspin%' then 'tailspin'
		else CustomerName end as customerName

from sales.CustomerCategories as cc inner join sales.Customers as c
on cc.CustomerCategoryID = c.CustomerCategoryID)

select CustomerCategoryName , count( distinct customerName) as cc,
sum(count (distinct customerName )) over () as ccc,
concat(cast((cast(count( distinct customerName) as decimal(10,2))/ cast((sum(count (distinct customerName )) over ())as decimal(10,2))) * 100 as decimal(10,2)),'%') as cccc

from cte
group by CustomerCategoryName
order by CustomerCategoryName

















