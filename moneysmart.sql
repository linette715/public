-- Question 1

WITH pageview_tmp AS (
	SELECT
		id,
		user_id,
		page_id,
		visit_date,
		visit_time,
		LAG(visit_time) 
			OVER (PARTITION BY user_id, page_id, visit_date
				  ORDER BY visit_time) AS previous_visit_time
	FROM pageviews	
)

SELECT
	page_id,
	visit_date,
	COUNT(*) AS total_user_sessions
FROM pageview_tmp
WHERE previous_visit_time IS NULL -- first timestamp
   OR DATEDIFF(minutes, previous_visit_time, visit_time) > 10
GROUP BY 1,2


-- Question 2

WITH product_frequence AS (
	SELECT
		productid,
		SUM(quantity) AS quantity, -- determine the demand/bestseller of the products based on total quantity
		COUNT(DISTINCT orderid) AS product_freq -- determine the number of orders a product is included
	FROM sampleorders
	GROUP BY productid
),

orders_count AS (
	SELECT COUNT(DISTINCT orderid) AS count
	FROM sampleorders
),

bestsellers_products AS (
	SELECT TOP 10 productid -- return the top 10 bestsellers products
	FROM product_frequence
	ORDER BY quantity DESC
),

product_pairs AS (
	SELECT
		o1.productid AS productA_id,
		o2.productid AS productB_id,
		COUNT(*) AS product_pairs_freq
	FROM sampleorders o1
	INNER JOIN sampleorders o2
	-- return all the possible combination of two items in each order
		    ON o1.orderid = o2.orderid
		   AND o1.productid != o2.productid
	WHERE o1.productid IN (SELECT productid FROM bestsellers_products) -- products that are part of the bestsellers
	  AND o2.productid NOT IN (SELECT productid FROM bestsellers_products) -- products that are not part of the bestsellers
	GROUP BY 1,2
),

products_analysis AS (

SELECT
	product_pairs.productA_id AS productA,
	product_pairs.productB_id AS productB,
	product_pairs.product_pairs_freq AS occurences,
	product_pairs.product_pairs_freq/CAST(orders_count.count AS DECIMAL) AS support,
	product_pairs.product_pairs_freq/ product_A.product_freq AS confidence,
	(product_pairs.product_pairs_freq/CAST(orders_count.count AS DECIMAL))
		/((product_A.product_freq/CAST(orders_count.count AS DECIMAL)) * (product_B.product_freq/CAST(orders_count.count AS DECIMAL))) AS liftratio
FROM product_pairs
LEFT JOIN product_frequence product_A
       ON product_pairs.productA_id = product_A.productid
LEFT JOIN product_frequence product_B
       ON product_pairs.productB_id = product_B.productid
LEFT JOIN orders_count
	   ON 1=1

)

SELECT *
FROM products_analysis
WHERE support >= 0.2
  AND confidence >= 0.6
  AND liftratio > 1
