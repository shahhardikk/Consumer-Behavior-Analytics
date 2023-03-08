Select * from dim_customer;
Select * from dim_product;
Select * from fact_gross_price;
Select * from fact_manufacturing_cost;
Select * from fact_pre_invoice_deductions;
Select * from fact_sales_monthly;

#Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.
Select market as 'APAC Markets for Atliq' from dim_customer
where customer = 'Atliq Exclusive' && region = 'APAC';

#What is the percentage of unique product increase in 2021 vs. 2020? The final output contains these fields - unique_products_2020 unique_products_2021 percentage_chg
SELECT p.product,
		SUM(CASE WHEN fiscal_year = 2020 THEN sold_quantity ELSE 0 END) AS sold_2020,
        SUM(CASE WHEN fiscal_year = 2021 THEN sold_quantity ELSE 0 END) AS sold_2021,
       (SUM(CASE WHEN fiscal_year = 2021 THEN sold_quantity ELSE 0 END) - SUM(CASE WHEN fiscal_year = 2020 THEN sold_quantity ELSE 0 END)) 
       /SUM(CASE WHEN fiscal_year = 2020 THEN sold_quantity ELSE 0 END) * 100 AS percentage_change
FROM fact_sales_monthly f
JOIN dim_product p ON f.product_code = p.product_code
GROUP BY p.product
ORDER BY percentage_change DESC;

/*Provide a report with all the unique product counts for each segment and sort them in descending order of product counts. 
The final output contains 2 fields, segment product_count*/
select segment , count(distinct product_code) As 'product_count' 
from dim_product
group by segment
order by product_code DESC;

/*Follow-up: Which segment had the most increase in unique products in 2021 vs 2020? The final output contains these fields, 
segment product_count_2020 product_count_2021 difference */
SELECT p.segment,
		SUM(CASE WHEN fiscal_year = 2020 THEN sold_quantity ELSE 0 END) AS sold_2020,
        SUM(CASE WHEN fiscal_year = 2021 THEN sold_quantity ELSE 0 END) AS sold_2021,
       (SUM(CASE WHEN fiscal_year = 2021 THEN sold_quantity ELSE 0 END) - SUM(CASE WHEN fiscal_year = 2020 THEN sold_quantity ELSE 0 END)) 
       /SUM(CASE WHEN fiscal_year = 2020 THEN sold_quantity ELSE 0 END) * 100 AS percentage_change,
       (SUM(CASE WHEN fiscal_year = 2021 THEN sold_quantity ELSE 0 END) - SUM(CASE WHEN fiscal_year = 2020 THEN sold_quantity ELSE 0 END)) as difference
FROM fact_sales_monthly f
JOIN dim_product p ON f.product_code = p.product_code
GROUP BY p.segment
ORDER BY difference, percentage_change DESC;

/*Get the products that have the highest and lowest manufacturing costs. 
The final output should contain these fields, product_code product manufacturing_cost */

SELECT p1.product_code, p1.product, fmc1.manufacturing_cost
FROM fact_manufacturing_cost fmc1
JOIN dim_product p1 ON p1.product_code = fmc1.product_code
WHERE fmc1.manufacturing_cost = (
    SELECT MIN(fmc2.manufacturing_cost)
    FROM fact_manufacturing_cost fmc2
)
UNION
SELECT p3.product_code, p3.product, fmc3.manufacturing_cost
FROM fact_manufacturing_cost fmc3
JOIN dim_product p3 ON p3.product_code = fmc3.product_code
WHERE fmc3.manufacturing_cost = (
    SELECT MAX(fmc4.manufacturing_cost)
    FROM fact_manufacturing_cost fmc4
);

/*Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market. 
The final output contains these fields, customer_code customer average_discount_percentage */

select dc.customer_code, dc.customer, avg(fpid.pre_invoice_discount_pct) As avg_discount_price
from fact_pre_invoice_deductions fpid
JOIN dim_customer dc on fpid.customer_code = dc.customer_code
WHERE fpid.fiscal_year = 2021 AND dc.market = 'India'
Group by dc.customer_code
Order by avg_discount_price DESC
Limit 5;

/*Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month . 
This analysis helps to get an idea of low and high-performing months and take strategic decisions.
The final report contains these columns: Month Year Gross sales Amount*/

select DATE_FORMAT(fsm.date, '%Y-%m') as monthly , fsm.fiscal_year,
SUM(fgp.gross_price * fsm.sold_quantity) as total_sales_amount
from fact_sales_monthly fsm
join fact_gross_price fgp on fgp.product_code = fsm.product_code
join dim_customer dc ON fsm.customer_code = dc.customer_code
where dc.customer = 'Atliq Exclusive'
group by monthly
order by monthly;

/*In which quarter of 2020, got the maximum total_sold_quantity? 
The final output contains these fields sorted by the total_sold_quantity, Quarter total_sold_quantity*/

SELECT CONCAT('Q', CAST(QUARTER(date) AS CHAR(1))) AS quarter, SUM(sold_quantity) AS total_sold_quantity
FROM fact_sales_monthly
WHERE YEAR(date) = 2020
GROUP BY quarter
ORDER BY total_sold_quantity DESC;

/*Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution?
The final output contains these fields, channel gross_sales_mln percentage*/

SELECT 
  c.channel,
  SUM(s.sold_quantity * g.gross_price) / 1000000 AS gross_sales_mln,
  SUM(s.sold_quantity * g.gross_price) / (SELECT SUM(s2.sold_quantity * g2.gross_price) FROM fact_sales_monthly s2 JOIN fact_gross_price g2 ON s2.product_code = g2.product_code AND s2.fiscal_year = g2.fiscal_year WHERE s2.fiscal_year = 2021) * 100 AS percentage
FROM fact_sales_monthly s 
JOIN fact_gross_price g ON s.product_code = g.product_code AND s.fiscal_year = g.fiscal_year
JOIN dim_customer c ON s.customer_code = c.customer_code
WHERE s.fiscal_year = 2021
GROUP BY c.channel
ORDER BY gross_sales_mln DESC;

/*Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? 
The final output contains these fields, division product_code*/

WITH sales_2021 AS (
  SELECT 
    p.division, 
    s.product_code, 
    p.product,
    SUM(s.sold_quantity) AS total_sold_quantity
  FROM 
    fact_sales_monthly s
    JOIN dim_product p ON s.product_code = p.product_code
  WHERE 
    s.fiscal_year = 2021
  GROUP BY 
    p.division, 
    s.product_code
),
ranked_products AS (
  SELECT 
    division, 
    product_code, 
    total_sold_quantity,
    product,
    ROW_NUMBER() OVER (PARTITION BY division ORDER BY total_sold_quantity DESC) AS product_rank
  FROM 
    sales_2021
)
SELECT 
  division, 
  product_code,
  product,
  total_sold_quantity,
  product_rank
FROM 
  ranked_products
WHERE 
  product_rank <= 3
ORDER BY 
  division, 
  product_rank