CREATE VIEW [gold].[vw_total_orders_per_customer] AS 
SELECT c.customer_unique_id, 
    COUNT(DISTINCT o.order_id) AS total_orders 
FROM [gold].[fact_orders] AS o 
INNER JOIN [gold].[dim_customer] AS c 
    ON o.customer_id = c.customer_id 
WHERE o.is_canceled = 0 
GROUP BY c.customer_unique_id;