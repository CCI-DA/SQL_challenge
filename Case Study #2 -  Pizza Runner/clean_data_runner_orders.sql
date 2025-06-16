-- Runner_orders has to be cleaned
UPDATE runner_orders
SET distance = REPLACE(REPLACE(distance,'km',''), ' km', '')
;

UPDATE runner_orders
SET duration = REPLACE(REPLACE(REPLACE(duration, 'mins',''), 'minutes',''),'minute','')
;

UPDATE runner_orders
SET cancellation = NULL
WHERE cancellation = ''
;

UPDATE runner_orders
SET cancellation = NULL
WHERE cancellation = 'null'
;
-- Rename columns names 
EXEC sp_rename 'runner_orders.distance', 'distance_km', 'COLUMN';
EXEC sp_rename 'runner_orders.duration', 'duration_min', 'COLUMN';

