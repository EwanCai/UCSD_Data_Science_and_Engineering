﻿set search_path to sales;

/***
* 1: Show the total sales (quantity sold and dollar value) for each customer.
****/

-- Simplest solution (it adds up quantities across product types).
-- Note that we need to include even customers with no sales, hence the outer join.

CREATE VIEW q1 AS

SELECT   c.customer_id, 
	 coalesce (sum (s.quantity), 0) AS quantity_sold, 
	 coalesce (sum (s.quantity*s.price), 0.0) AS dollar_value
FROM     customer c LEFT  JOIN sale s ON c.customer_id = s.customer_id
GROUP BY c.customer_id;


-- more refined: per product

DISCARD ALL;
CREATE INDEX sales_cust_id ON sales.sale(customer_id); -- No index needed
EXPLAIN ANALYZE
SELECT   c.customer_id, s.product_id,
	 coalesce (sum (s.quantity), 0) AS quantity_sold, 
	 coalesce (sum (s.quantity*s.price), 0.0) AS dollar_value
FROM     sales.customer c LEFT  JOIN sales.sale s ON c.customer_id = s.customer_id
GROUP BY c.customer_id, s.product_id;


/***
* 2: Show the total sales for each state.
****/
DISCARD ALL;
CREATE INDEX sales_cust_id ON sales.sale(customer_id); -- doesn't help
CREATE INDEX cust_state_id ON sales.customer(state_id); -- doesn't help
-- CREATE INDEX combo_id ON sales.customer(customer_id, state_id);
EXPLAIN ANALYZE
-- CREATE VIEW q1 AS
WITH q1 AS
(SELECT   c.customer_id, 
	 coalesce (sum (s.quantity), 0) AS quantity_sold, 
	 coalesce (sum (s.quantity*s.price), 0.0) AS dollar_value
FROM     sales.customer c LEFT  JOIN sales.sale s ON c.customer_id = s.customer_id
GROUP BY c.customer_id)

-- CREATE VIEW q2 AS
SELECT   s.state_name, 
	 coalesce (SUM (q.quantity_sold), 0) AS quantity_sold, 
	 coalesce (SUM (q.dollar_value), 0.0) AS dollar_value

FROM     (sales.state s LEFT  JOIN sales.customer c ON s.state_id = c.state_id)
	 LEFT  JOIN q1 q ON c.customer_id = q.customer_id

GROUP BY s.state_id;

/***
* 3: Show the total sales for each product, for a given customer.
*    Only products that were actually bought by the given customer are listed. 
*    Order by dollar value. 
****/

-- PREPARE Q3 (int) AS
DISCARD ALL;
CREATE INDEX sales_cust_id ON sales.sale(customer_id); -- this helped
EXPLAIN ANALYZE
SELECT    product_id, 
	  SUM (quantity) AS quantity_sold, 
	  SUM (quantity*price) AS dollar_value
FROM      sales.sale
WHERE     customer_id = 13
GROUP BY  product_id
ORDER BY  dollar_value DESC;


-- for customer of id 13, invoke this as
-- EXECUTE Q3(13);


/***
* 4: Show the total sales for each product and customer. Order by dollar value.
***/

-- we will reuse this query later, 
-- so we output two more columns than required by the question:

DISCARD ALL;
CREATE INDEX sales_cust_id ON sales.sale(customer_id); -- didn't help
CREATE INDEX sales_prod_id ON sales.sale(product_id); -- didn't help
-- CREATE VIEW q4 AS
EXPLAIN ANALYZE 
SELECT	  c.customer_id, c.customer_name, p.product_id, 
	  coalesce (SUM (s.quantity), 0) AS quantity_sold, 
	  coalesce (SUM (s.quantity*s.price), 0.0) AS dollar_value,
	  -- needed later:
	  c.state_id, p.category_id

FROM      (sales.customer c CROSS JOIN sales.product p) LEFT  JOIN sales.sale s 
	  ON c.customer_id = s.customer_id AND p.product_id = s.product_id

GROUP BY  c.customer_id, p.product_id
ORDER BY  c.customer_id, dollar_value DESC;

/***
* 5: Show the total sales for each product category and state.
***/

-- CREATE VIEW q5 AS
-- reusing Q4

DISCARD ALL;
CREATE INDEX sales_cust_id ON sales.sale(customer_id); -- didn't help
CREATE INDEX sales_prod_id ON sales.sale(product_id); -- didn't help
-- CREATE VIEW q4 AS
EXPLAIN ANALYZE
WITH q4 AS
(SELECT	  c.customer_id, c.customer_name, p.product_id, 
	  coalesce (SUM (s.quantity), 0) AS quantity_sold, 
	  coalesce (SUM (s.quantity*s.price), 0.0) AS dollar_value,
	  -- needed later:
	  c.state_id, p.category_id

FROM      (sales.customer c CROSS JOIN sales.product p) LEFT  JOIN sales.sale s 
	  ON c.customer_id = s.customer_id AND p.product_id = s.product_id

GROUP BY  c.customer_id, p.product_id
ORDER BY  c.customer_id, dollar_value DESC)

SELECT    s.state_id, c.category_id, 
	  coalesce (SUM (q.quantity_sold), 0) AS quantity_sold,
	  coalesce (SUM (q.dollar_value), 0.0) AS dollar_value

FROM      (sales.state s CROSS JOIN sales.category c)
	  LEFT  JOIN q4 q ON s.state_id = q.state_id AND c.category_id = q.category_id

GROUP BY  s.state_id, c.category_id;


/***
* 6: For each one of the top 20 product categories and top 20 customers, 
*    return a tuple (top product category, top customer, quantity sold, dollar value)
***/

-- simpler: if several categories/customers are tied, such that there are really more than
--         20 in the top-20 category, break ties randomly (according to what the postgres implementation of LIMIT 20 does)

CREATE VIEW sales.q1 AS

SELECT   c.customer_id, 
	 coalesce (sum (s.quantity), 0) AS quantity_sold, 
	 coalesce (sum (s.quantity*s.price), 0.0) AS dollar_value
FROM     sales.customer c LEFT  JOIN sales.sale s ON c.customer_id = s.customer_id
GROUP BY c.customer_id;

CREATE VIEW sales.q4 AS

SELECT	  c.customer_id, c.customer_name, p.product_id, 
	  coalesce (SUM (s.quantity), 0) AS quantity_sold, 
	  coalesce (SUM (s.quantity*s.price), 0.0) AS dollar_value,
	  -- needed later:
	  c.state_id, p.category_id

FROM      (sales.customer c CROSS JOIN sales.product p) LEFT  JOIN sales.sale s 
	  ON c.customer_id = s.customer_id AND p.product_id = s.product_id

GROUP BY  c.customer_id, p.product_id
ORDER BY  c.customer_id, dollar_value DESC;

CREATE VIEW sales.q5 AS
-- reusing Q4

SELECT    s.state_id, c.category_id, 
	  coalesce (SUM (q.quantity_sold), 0) AS quantity_sold,
	  coalesce (SUM (q.dollar_value), 0.0) AS dollar_value

FROM      (sales.state s CROSS JOIN sales.category c)
	  LEFT  JOIN sales.q4 q ON s.state_id = q.state_id AND c.category_id = q.category_id

GROUP BY  s.state_id, c.category_id;

-- DISCARD ALL


CREATE VIEW sales.top_customer (customer_id) AS
-- reusing Q1:
SELECT    customer_id
FROM	  sales.q1
ORDER BY  dollar_value DESC
LIMIT 	  20;


CREATE VIEW top_category (category_id) AS
-- reusing Q5:
SELECT    category_id, SUM (dollar_value) AS dollar_value
FROM	  sales.q5
GROUP BY  category_id
ORDER BY  dollar_value DESC
LIMIT 	  20;


-- CREATE VIEW sales.q6 AS
-- reusing Q4:
DISCARD ALL;
CREATE INDEX sales_cust_id ON sales.sale(customer_id); -- didn't help
CREATE INDEX sales_prod_id ON sales.sale(product_id); -- didn't help
EXPLAIN ANALYZE
SELECT	  ca.category_id, cu.customer_id, 
	  coalesce (SUM (q.quantity_sold), 0) AS quantity_sold,
	  coalesce (SUM (q.dollar_value), 0.0) AS dollar_value

FROM      (SELECT    customer_id
		FROM	  sales.q1
ORDER BY  dollar_value DESC
LIMIT 	  20) cu CROSS JOIN (SELECT    category_id, SUM (dollar_value) AS dollar_value
FROM	  sales.q5
GROUP BY  category_id
ORDER BY  dollar_value DESC
LIMIT 	  20) ca LEFT JOIN sales.q4 q 
	  ON q.customer_id = cu.customer_id AND q.category_id = ca.category_id

GROUP BY  ca.category_id, cu.customer_id;
	  


-- better (extra credit): 
-- include in top customers all customers whose total sale value is among the top 20
-- dollar values (could be more than 20 customers). Analgously for top categories.

-- replace in above query top_customer with all_top_customers, and top_category with
-- all_top_categories, defined below:


CREATE VIEW top_customer_values AS
SELECT    DISTINCT dollar_value 
FROM      q1
ORDER BY  dollar_value DESC
LIMIT 	  20;


CREATE VIEW all_top_customers AS
SELECT customer_id
FROM   q1
WHERE  dollar_value I’d (SELECT dollar_value FROM top_customer_values);



CREATE VIEW top_category_values AS
SELECT    DISTINCT SUM (dollar_value) AS dollar_value
FROM	  q5
GROUP BY  category_id
ORDER BY  dollar_value DESC
LIMIT 	  20;

CREATE VIEW all_top_categories AS
SELECT    category_id
FROM	  q5
GROUP BY  category_id
HAVING	  SUM (dollar_value) IN (SELECT dollar_value FROM top_category_values);


CREATE VIEW q6_all AS
SELECT	  ca.category_id, cu.customer_id, 
	  coalesce (SUM (q.quantity_sold), 0) AS quantity_sold,
	  coalesce (SUM (q.dollar_value), 0.0) AS dollar_value

FROM      (all_top_customers cu CROSS JOIN all_top_categories ca) LEFT JOIN q4 q 
	  ON q.customer_id = cu.customer_id AND q.category_id = ca.category_id

GROUP BY  ca.category_id, cu.customer_id;
	  