# Ad-hoc Requests - Provide Insights to Management in Consumer Goods Domain

# 1. Provide the list of markets in which customer "Atliq Exclusive" 
# operates its business in the APAC region.
# endeavor to provide a pictorial/shape-map view of this

SELECT distinct market 
FROM gdb023.dim_customer
WHERE customer = "Atliq Exclusive" 
AND region = "APAC"
ORDER BY market ASC;

/*
2. What is the percentage of unique product increase in 2021 vs. 2020? The
final output contains these fields,
unique_products_2020
unique_products_2021
percentage_chg
*/

# No of unique products in 2020 vs unique products in 2021
with cte1 as (
	SELECT 
		count(distinct product_code) 
        as unique_products_2020 
	FROM gdb023.fact_sales_monthly
	where fiscal_year= 2020), 
cte2 as (
	SELECT 
		count(distinct product_code) 
        as unique_products_2021 
	FROM gdb023.fact_sales_monthly
	where fiscal_year= 2021)

select *,  
	round(
    (unique_products_2021-unique_products_2020)
    *100/unique_products_2020,2) 
    as percentage_chg
from cte1, cte2;


/*
3. Provide a report with all the unique product counts for each segment and
sort them in descending order of product counts. The final output contains 2 fields,
- segment
- product_count
*/

# for the sales period 2020-2021, here's the unique_product_count_by_segment
select segment, count(distinct product_code) as unique_product_count
from dim_product
join fact_sales_monthly using(product_code)
group by segment
order by unique_product_count desc;

/*
4. Follow-up: Which segment had the most increase in unique products in
2021 vs 2020? The final output contains these fields,
segment
product_count_2020
product_count_2021
difference
*/

with cte1 as (
	select segment, 
    count(distinct product_code) as product_count_2020 
from dim_product
join fact_sales_monthly using(product_code)
where fiscal_year=2020
group by segment),

cte2 as (
	select segment, 
    count(distinct product_code) as product_count_2021 
from dim_product
join fact_sales_monthly using(product_code)
where fiscal_year=2021
group by segment)

select cte1.segment, 
	product_count_2020, product_count_2021,
	(product_count_2021 - product_count_2020) 
    as difference
from cte1 join cte2 using(segment)
order by difference desc;


/*
5. Get the products that have the highest (max) and lowest (min) manufacturing costs.
The final output should contain these fields,
product_code
product
manufacturing_cost

== we need to look at this on overall basis, and then by category, 
segment and division as well as considering fiscal_year; 2020 & 2021
== you can get a stored procedure for this with variables...fiscal year, sgement etc...

*** Approach::: 
-- I created a View for Prodcuts + Manufacturing_cost
-- Created stored procedures to get the highest and lowest
	across fiscal years and categories.
*/
# Categories mouse, keyboard, batteries and External Solid State Drives 
# have same manufacturing cost for all products

# sample result
select product_code, product, 
	manufacturing_cost
from gdb023.product_man_cost
where manufacturing_cost = (
	SELECT max(manufacturing_cost)
FROM gdb023.product_man_cost)

union

select product_code, product, 
	manufacturing_cost
from gdb023.product_man_cost
where manufacturing_cost = (
	SELECT min(manufacturing_cost)
FROM gdb023.product_man_cost)
limit 2;

# for more insights, we can create a stored procedure
# to filter by fiscal_year only or in addition with categories.  
CREATE DEFINER=`root`@`localhost` 
PROCEDURE `get_highest_lowest_mc_by_category`(
		in_cost_year int,
		in_category varchar(100))
BEGIN
select product_code, product, manufacturing_cost
from gdb023.product_man_cost
where manufacturing_cost = (
	SELECT max(manufacturing_cost)
FROM gdb023.product_man_cost
where cost_year = in_cost_year 
or category = in_category ) 
union
select product_code, product, manufacturing_cost
from gdb023.product_man_cost
where manufacturing_cost = (
	SELECT min(manufacturing_cost)
FROM gdb023.product_man_cost
where cost_year = in_cost_year 
or category = in_category )
limit 2 END;


/*
6. Generate a report which contains the top 5 customers who received an
average high pre_invoice_discount_pct for the fiscal year 2021 and in the
Indian market. The final output contains these fields,
customer_code
customer
average_discount_percentage
*/

SELECT c.customer_code, c.customer, f.pre_invoice_discount_pct	
FROM gdb023.fact_pre_invoice_deductions f
left join gdb023.dim_customer c using(customer_code)
where fiscal_year = 2021 and market = "India"
order by pre_invoice_discount_pct desc
;
# From this query, Amazon and Atliq Exclusive appeared twice...
# so we need to calculte an average_discount_pct 
SELECT c.customer_code, c.customer,
	round(avg(f.pre_invoice_discount_pct), 4) 
    as avg_discount_pct  
FROM gdb023.fact_pre_invoice_deductions f
left join gdb023.dim_customer c 
using(customer_code)
where fiscal_year = 2021 and market = "India"
group by customer
order by pre_invoice_discount_pct desc
limit 5;

/*
7. Get the complete report of the Gross sales amount for the customer “Atliq
Exclusive” for each month. This analysis helps to get an idea of low and
high-performing months and take strategic decisions.
The final report contains these columns:
Month
Year
Gross sales Amount
*/

with cte1 as (select monthname(f.date) as month, f.fiscal_year, f.product_code, 
    p.gross_price, f.sold_quantity 
from fact_sales_monthly f
join dim_customer c using(customer_code)
join fact_gross_price p using(product_code, fiscal_year)
where customer= "Atliq Exclusive")

select month,fiscal_year, sum(round(gross_price*sold_quantity, 2)) as gross_sales_amount
from cte1
group by month, fiscal_year;


/*
8. In which quarter of 2020, got the maximum total_sold_quantity? The final
output contains these fields sorted by the total_sold_quantity,
Quarter
total_sold_quantity
*/

with cte1 as (
	select date, month(date) as mn,
    sold_quantity 
from fact_sales_monthly 
where fiscal_year= 2020),

cte2 as (select case
		when mn between 9 and 11 then 'Q1'
        when mn in (12, 1, 2) then 'Q2'
        when mn between 3 and 5 then 'Q3'
        when mn between 6 and 8 then 'Q4'
        end as Quarter,
        sold_quantity
     from cte1)
select Quarter, 
	sum(sold_quantity) as total_sold_quantity
from cte2
group by quarter;


/*
9. Which channel helped to bring more gross sales in the fiscal year 2021
and the percentage of contribution? The final output contains these fields,
channel
gross_sales_mln
percentage
*/

with cte1 as (
	select *, (sold_quantity*sold_quantity) as gross_sales
	from fact_sales_monthly f
	join fact_gross_price p 
    using(product_code, fiscal_year)
	where f.fiscal_year= 2021),

cte2 as (
	select date,dim_customer.customer_code, channel, sold_quantity, 
	gross_price, gross_sales
	from cte1 join dim_customer using(customer_code)),

cte3 as (
	select channel, sum(gross_sales)/1000000 as gross_sales_mln
	from cte2
	group by channel)

select channel, round(gross_sales_mln,2), 
	round((gross_sales_mln*100)/sum(gross_sales_mln) over(),2) as percentage
from cte3
order by gross_sales_mln desc;
    
/*
10. Get the Top 3 products in each division that have a high
total_sold_quantity in the fiscal_year 2021? The final output contains these
fields,
division
product_code
product
total_sold_quantity
rank_order
*/
with cte1 as (
	select division, product_code, product, variant, 
		sum(sold_quantity) as total_sold_quantity 
	from gdb023.fact_sales_monthly
	join gdb023.dim_product using(product_code)
	where fiscal_year=2021
	group by product_code, product),

cte2 as (
	select *,
	dense_rank() over(partition by division 
    order by total_sold_quantity desc )
    as rank_order
from cte1)

select * from cte2 where rank_order <=3;
