-- 1. What is the total amount each customer spent at the restaurant?

SELECT customer_id, SUM(price) AS total_spent
FROM sales
INNER JOIN menu ON sales.product_id = menu.product_id
GROUP BY customer_id
;



-- 2. How many days has each customer visited the restaurant?

SELECT customer_id , COUNT(DISTINCT(order_date)) AS count_days
FROM sales
GROUP BY customer_id
;



-- 3. What was the first item from the menu purchased by each customer?

WITH first_purchases AS (
    SELECT customer_id, 
    order_date, 
    product_id,
    ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date ASC) AS rn
    FROM sales
)
SELECT  customer_id, order_date AS first_order_date, product_id AS first_product_id
FROM first_purchases
WHERE rn = 1
;



-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT TOP 1
menu.product_name AS most_purchased_item, count(sales.product_id) AS times_purchased
FROM sales
INNER JOIN menu ON sales.product_id = menu.product_id 
GROUP BY menu.product_name
ORDER BY times_purchased DESC
; 



-- 5. Which item was the most popular for each customer?

WITH most_popular_item AS ( 
    SELECT customer_id,product_id, COUNT(*) AS times_bought ,
    RANK() OVER( PARTITION BY customer_id ORDER BY COUNT(*)DESC) AS rnk
    FROM sales 
    GROUP BY customer_id, product_id )

SELECT customer_id , product_id , times_bought 
FROM most_popular_item
WHERE rnk = 1 
;



-- 6. Which item was purchased first by the customer after they became a member?

WITH purchases_after_join AS (
  SELECT
    s.customer_id,
    s.order_date,
    s.product_id,
    mn.product_name,
    ROW_NUMBER() OVER (
      PARTITION BY s.customer_id
      ORDER BY s.order_date
    ) AS rn
  FROM sales AS s
  INNER JOIN members AS mb ON s.customer_id = mb.customer_id
  INNER JOIN menu AS mn ON s.product_id = mn.product_id
  WHERE s.order_date >= mb.join_date
)

SELECT product_name, customer_id, order_date
FROM purchases_after_join
WHERE rn = 1;



-- 7. Which item was purchased just before the customer became a member?

WITH last_purchase_before_membership AS (
  SELECT
    s.customer_id,
    s.order_date,
    s.product_id,
    mn.product_name,
    ROW_NUMBER() OVER (
      PARTITION BY s.customer_id
      ORDER BY s.order_date DESC , s.product_id DESC
    ) AS rn
  FROM sales AS s
  INNER JOIN members AS mb ON s.customer_id = mb.customer_id
  INNER JOIN menu AS mn ON s.product_id = mn.product_id
  WHERE s.order_date < mb.join_date
)

SELECT product_name, customer_id, order_date
FROM last_purchase_before_membership
WHERE rn = 1;



-- 8. What is the total items and amount spent for each member before they became a member?

SELECT s.customer_id, COUNT(s.product_id) AS total_items , SUM(mn.price) AS total_amount
 FROM sales AS s
 INNER JOIN members AS mb ON s.customer_id = mb.customer_id
 INNER JOIN menu AS mn ON s.product_id = mn.product_id
 WHERE s.order_date < mb.join_date
 GROUP BY s.customer_id
;



-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

SELECT s.customer_id,
    SUM(
      CASE 
        WHEN mn.product_name = 'sushi' THEN mn.price *20
        ELSE mn.price * 10
      END) 
      AS total_points

FROM sales AS s
INNER JOIN menu AS mn ON s.product_id = mn.product_id
GROUP BY customer_id
;



-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

SELECT s.customer_id,
    SUM(
      CASE 
      -- First week of membership: everything 2x points
        WHEN s.order_date BETWEEN mb.join_date AND DATEADD(DAY, 6, mb.join_date) THEN mn.price * 20
      
      -- Out of first week of membership: only sushi 2x points
        WHEN mn.product_name = 'sushi' THEN mn.price * 20

      -- Rest 10 points
        ELSE mn.price * 10 
        END) 
        AS total_points_end_january

FROM sales AS s
INNER JOIN menu AS mn ON s.product_id = mn.product_id
LEFT JOIN members AS mb ON s.customer_id = mb.customer_id
WHERE s.order_date <= '2021-01-31' AND s.customer_id IN ('A','B')
GROUP BY s.customer_id
;
