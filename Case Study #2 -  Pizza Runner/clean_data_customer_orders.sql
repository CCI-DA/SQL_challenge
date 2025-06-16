UPDATE customer_orders
SET exclusions = NULL
WHERE exclusions = ''
;

UPDATE customer_orders
SET extras = NULL
WHERE extras = ''
;