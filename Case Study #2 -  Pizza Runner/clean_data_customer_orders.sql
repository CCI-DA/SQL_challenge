UPDATE customer_orders
SET exclusions = NULL
WHERE exclusions = ''
;

UPDATE customer_orders
SET extras = NULL
WHERE extras = ''
;

UPDATE customer_orders
SET exclusions = NULL
WHERE exclusions = 'null'
;

UPDATE customer_orders
SET extras = NULL
WHERE extras = 'null'
;