-- DATA CLEANING
-- PRODUCTS TABLE
-- Checking for missing values 
SELECT COUNT(DISTINCT "ProductKey")
FROM global_electronics_retailer."Products"
WHERE "Product Name" IS NULL OR
	"Brand" IS NULL OR
	"Color" IS NULL OR
	"Unit Cost USD" IS NULL OR
	"Unit Price USD" IS NULL OR
	"SubcategoryKey" IS NULL OR
	"Subcategory" IS NULL OR
	"CategoryKey" IS NULL OR
	"Category" IS NULL;
-- There is no missing values

-- Checking for duplicates 
SELECT "ProductKey", COUNT(DISTINCT "ProductKey")
FROM global_electronics_retailer."Products"
GROUP BY "ProductKey"
HAVING COUNT(DISTINCT "ProductKey") > 1;
-- No duplicates

-- Standardizing Unit Cost USD and Unit Price USD columns by removing the '$' and ',' signs and converting to numeric data type
SELECT "ProductKey", "Product Name", "Brand", "Color", 
	TRIM('$' FROM REPLACE("Unit Cost USD", ',', ''))::NUMERIC AS "Unit Cost USD",
	TRIM('$' FROM REPLACE("Unit Price USD", ',', ''))::NUMERIC AS "Unit Price USD", 
	"SubcategoryKey", "Subcategory", "CategoryKey", "Category"
FROM global_electronics_retailer."Products";

-- Creating a copy of the Products table
CREATE TABLE global_electronics_retailer.products_cleaned AS
SELECT "ProductKey", "Product Name", "Brand", "Color", 
	TRIM('$' FROM REPLACE("Unit Cost USD", ',', ''))::NUMERIC AS "Unit Cost USD",
	TRIM('$' FROM REPLACE("Unit Price USD", ',', ''))::NUMERIC AS "Unit Price USD", 
	"SubcategoryKey", "Subcategory", "CategoryKey", "Category"
FROM global_electronics_retailer."Products";

-- SALES TABLE
-- Checking for missing values
SELECT COUNT(*)
FROM global_electronics_retailer."Sales"
WHERE "Delivery Date" IS NULL;
-- The Delivery Date column is missing 49719 values

-- Filling the missing values in the Delivery Date column with the Average Delivery day based on Country and Products
WITH avg_delivery_day AS (
    SELECT "Country", "ProductKey", 
           ROUND(AVG("Delivery Date"::date - "Order Date"::date)) AS "Average Delivery Day"
    FROM global_electronics_retailer."Sales" AS s
    INNER JOIN global_electronics_retailer."Customers" AS c
        ON s."CustomerKey" = c."CustomerKey"
    WHERE "Delivery Date" IS NOT NULL
    GROUP BY "Country", "ProductKey"
),
global_avg AS (
    SELECT ROUND(AVG("Delivery Date"::date - "Order Date"::date)) AS "Global Average Delivery Day"
    FROM global_electronics_retailer."Sales"
    WHERE "Delivery Date" IS NOT NULL
)
SELECT "Order Number", "Line Item", "Order Date"::date, 
       COALESCE(
           "Delivery Date"::date, 
           ("Order Date"::date + (
               SELECT "Average Delivery Day" * INTERVAL '1 DAY'
               FROM avg_delivery_day
               WHERE avg_delivery_day."Country" = c."Country"
                 AND avg_delivery_day."ProductKey" = s."ProductKey"
           )),
           ("Order Date"::date + (
               SELECT "Global Average Delivery Day" * INTERVAL '1 DAY'
               FROM global_avg
           ))
       )::date AS "Imputed Delivery Date",
       s."CustomerKey", s."StoreKey", s."ProductKey", s."Quantity", s."Currency Code"
FROM global_electronics_retailer."Sales" AS s
INNER JOIN global_electronics_retailer."Customers" AS c
		ON s."CustomerKey" = c."CustomerKey";

-- Creating a copy of Sales Table
CREATE TABLE global_electronics_retailer.sales_cleaned AS
WITH avg_delivery_day AS (
    SELECT "Country", "ProductKey", 
           ROUND(AVG("Delivery Date"::date - "Order Date"::date)) AS "Average Delivery Day"
    FROM global_electronics_retailer."Sales" AS s
    INNER JOIN global_electronics_retailer."Customers" AS c
        ON s."CustomerKey" = c."CustomerKey"
    WHERE "Delivery Date" IS NOT NULL
    GROUP BY "Country", "ProductKey"
),
global_avg AS (
    SELECT ROUND(AVG("Delivery Date"::date - "Order Date"::date)) AS "Global Average Delivery Day"
    FROM global_electronics_retailer."Sales"
    WHERE "Delivery Date" IS NOT NULL
)
SELECT "Order Number", "Line Item", "Order Date"::date, 
       COALESCE(
           "Delivery Date"::date, 
           ("Order Date"::date + (
               SELECT "Average Delivery Day" * INTERVAL '1 DAY'
               FROM avg_delivery_day
               WHERE avg_delivery_day."Country" = c."Country"
                 AND avg_delivery_day."ProductKey" = s."ProductKey"
           )),
           ("Order Date"::date + (
               SELECT "Global Average Delivery Day" * INTERVAL '1 DAY'
               FROM global_avg
           ))
       )::date AS "Imputed Delivery Date",
       s."CustomerKey", s."StoreKey", s."ProductKey", s."Quantity", s."Currency Code"
FROM global_electronics_retailer."Sales" AS s
INNER JOIN global_electronics_retailer."Customers" AS c
		ON s."CustomerKey" = c."CustomerKey";

-- Customers Table
-- Cheking for missing values
SELECT COUNT(DISTINCT "CustomerKey")
FROM global_electronics_retailer."Customers"
WHERE "CustomerKey" IS NULL OR
	"Gender" IS NULL OR
	"Name" IS NULL OR
	"City" IS NULL OR
	"State Code" IS NULL OR
	"State" IS NULL OR
	"Zip Code" IS NULL OR
	"Country" IS NULL OR
	"Continent" IS NULL OR
	"Birthday" IS NULL;
-- No Missing Value

-- Checking for duplicate record
SELECT "CustomerKey", COUNT(DISTINCT "CustomerKey") AS customer_count
FROM global_electronics_retailer."Customers"
GROUP BY "CustomerKey"
HAVING COUNT(DISTINCT "CustomerKey") > 1;
-- No duplicte record

-- Casting Birthday column from 'text' to 'date' and creating a copy of the Customers table
CREATE TABLE global_electronics_retailer.customers_cleaned AS
SELECT "CustomerKey", "Gender", "Name", "City", "State Code", "State", "Zip Code", "Country", "Continent", "Birthday"::date
FROM global_electronics_retailer."Customers";

-- Stores Table
-- Cheking for duplicate record
SELECT "Country", "State", COUNT(*)
FROM global_electronics_retailer."Stores"
GROUP BY "Country", "State";
-- No duplicate record

-- Casting Open Date column from 'text' to 'date' and creating a copy of the Stores table
CREATE TABLE global_electronics_retailer.stores_cleaned AS
SELECT "StoreKey", "Country", "State", "Square Meters", "Open Date"::date
FROM global_electronics_retailer."Stores";

-- Exchange_Rates Table
-- Checking for missing values
SELECT *
FROM global_electronics_retailer."Exchange_Rates"
WHERE "Date" IS NULL OR
	"Currency" IS NULL OR
	"Exchange" IS NULL;
-- No Missing Values

-- Checking for duplicate records
SELECT "Date", "Currency", "Exchange", COUNT(DISTINCT "Date")
FROM global_electronics_retailer."Exchange_Rates"
GROUP BY "Date", "Currency", "Exchange"
ORDER BY COUNT(DISTINCT "Date") DESC;
-- No Duplicate records

-- Casting Date column from 'text' to 'date' and creating a copy of the Exchange_Rates Table
CREATE TABLE global_electronics_retailer.exchange_rates_cleaned AS
SELECT "Date"::date, "Currency", "Exchange"
FROM global_electronics_retailer."Exchange_Rates";

-- EXPLORATORY DATA ANALYSIS
-- Total # of orders, Total Cost, Total Revenue and Total Profit
SELECT COUNT ("Order Number") AS number_of_orders,
	SUM("Unit Cost USD" * "Quantity") AS total_cost,
	SUM("Unit Price USD" * "Quantity") AS total_revenue,
	(SUM("Unit Price USD" * "Quantity") - SUM("Unit Cost USD" * "Quantity")) AS total_profit
FROM global_electronics_retailer.sales_cleaned AS s
INNER JOIN global_electronics_retailer.products_cleaned AS p
	ON p."ProductKey" = s."ProductKey";


-- Total # of orders, Total Cost, Total Revenue and Total Profit by countries
SELECT "Country",
	COUNT ("Order Number") AS number_of_orders,
	SUM("Unit Cost USD" * "Quantity") AS total_cost,
	SUM("Unit Price USD" * "Quantity") AS total_revenue,
	(SUM("Unit Price USD" * "Quantity") - SUM("Unit Cost USD" * "Quantity")) AS total_profit
FROM global_electronics_retailer.sales_cleaned AS s
INNER JOIN global_electronics_retailer.customers_cleaned AS c
	ON s."CustomerKey" = c."CustomerKey"
INNER JOIN global_electronics_retailer.products_cleaned AS p
	ON p."ProductKey" = s."ProductKey"
GROUP BY "Country"
ORDER BY number_of_orders DESC;

-- Total # of orders, Total Cost, Total Revenue and Total Profit by States
SELECT "Country", "State",
	COUNT ("Order Number") AS number_of_orders,
	SUM("Unit Cost USD" * "Quantity") AS total_cost,
	SUM("Unit Price USD" * "Quantity") AS total_revenue,
	(SUM("Unit Price USD" * "Quantity") - SUM("Unit Cost USD" * "Quantity")) AS total_profit
FROM global_electronics_retailer.sales_cleaned AS s
INNER JOIN global_electronics_retailer.customers_cleaned AS c
	ON s."CustomerKey" = c."CustomerKey"
INNER JOIN global_electronics_retailer.products_cleaned AS p
	ON p."ProductKey" = s."ProductKey"
GROUP BY "Country", "State"
ORDER BY "Country", number_of_orders DESC;

-- Average # of Items per order
SELECT ROUND(AVG("Quantity"), 2) AS avg_item
FROM global_electronics_retailer.sales_cleaned;

-- Top performing Stores
SELECT "State",
	COUNT("Order Number") AS num_orders,
	SUM("Quantity") AS num_items
FROM global_electronics_retailer.sales_cleaned AS s
INNER JOIN global_electronics_retailer.stores_cleaned AS st
	ON st."StoreKey" = s."StoreKey"
GROUP BY "State"
ORDER BY num_orders DESC, num_items DESC
LIMIT 10;

-- Top selling Categories
SELECT "Category",
	SUM("Quantity") AS quantity_sold
FROM global_electronics_retailer.sales_cleaned AS s
INNER JOIN global_electronics_retailer.products_cleaned AS p
	ON p."ProductKey" = s."ProductKey"
GROUP BY "Category"
ORDER BY quantity_sold DESC;

-- Top selling products per category
SELECT "Category", "Product Name",
	SUM("Quantity") AS quantity_sold
FROM global_electronics_retailer.sales_cleaned AS s
INNER JOIN global_electronics_retailer.products_cleaned AS p
	ON p."ProductKey" = s."ProductKey"
GROUP BY "Category", "Product Name"
ORDER BY quantity_sold DESC;

-- Monthly Sales Trends
SELECT TO_CHAR("Order Date", 'Month YYYY') AS month,
	COUNT("Order Number") AS num_orders,
	SUM("Quantity") AS quantity_sold,
	SUM("Unit Cost USD" * "Quantity") AS total_cost,
	SUM("Unit Price USD" * "Quantity") AS total_revenue,
	(SUM("Unit Price USD" * "Quantity") - SUM("Unit Cost USD" * "Quantity")) AS total_profit
FROM global_electronics_retailer.sales_cleaned AS s
INNER JOIN global_electronics_retailer.products_cleaned AS p
	ON p."ProductKey" = s."ProductKey"
GROUP BY TO_CHAR("Order Date", 'Month YYYY')
ORDER BY MIN("Order Date");

-- Average delivery day in each Country and State
SELECT "Country", "State", ROUND(AVG("Imputed Delivery Date" - "Order Date"), 2) AS avg_delivery_day
FROM global_electronics_retailer.sales_cleaned AS s
INNER JOIN global_electronics_retailer.stores_cleaned AS st
	ON st."StoreKey" = s."StoreKey"
GROUP BY "Country", "State"
ORDER BY avg_delivery_day ASC;

-- Comparing Average Order Value (AOV) Between Online and In-store sales
WITH channel AS
	(
	SELECT "StoreKey", 
			CASE 
			   WHEN "State" = 'Online' AND "Country" = 'Online' THEN 'Online Sales'
			   ELSE 'in-store sales'
			END AS sales_channel
	FROM global_electronics_retailer.stores_cleaned
	)
SELECT sales_channel,
	COUNT("Order Number") AS num_orders,
	ROUND(AVG("Quantity"), 2) AS avg_item_per_order,
	ROUND(AVG("Imputed Delivery Date" - "Order Date"), 2) AS avg_delivery_day,
	ROUND(AVG("Unit Price USD"), 2) avg_order_price,
	ROUND(AVG("Unit Price USD" * "Quantity"), 2) avg_order_value
FROM global_electronics_retailer.sales_cleaned AS s
INNER JOIN global_electronics_retailer.products_cleaned AS p
	ON p."ProductKey" = s."ProductKey"
INNER JOIN channel AS c
	ON s."StoreKey" = c."StoreKey"
GROUP BY sales_channel

SELECT *
FROM global_electronics_retailer.customers_cleaned

SELECT *
FROM global_electronics_retailer.exchange_rates_cleaned

SELECT *
FROM global_electronics_retailer.products_cleaned

SELECT *
FROM global_electronics_retailer.sales_cleaned

SELECT *
FROM global_electronics_retailer.stores_cleaned