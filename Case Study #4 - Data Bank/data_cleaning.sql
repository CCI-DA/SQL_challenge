UPDATE customer_transactions
SET txn_amount = -txn_amount
WHERE txn_type = 'purchase'
;

UPDATE customer_transactions
SET txn_amount = -txn_amount
WHERE txn_type = 'withdrawal'
;