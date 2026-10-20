CREATE VIEW [gold].[vw_top_10_most_sold_products] AS 
SELECT TOP 10 oi.product_id, 
    COUNT(*) AS total_units_sold, 
    COUNT(DISTINCT oi.order_id) AS total_orders, 
    SUM(oi.price) AS total_revenue 
FROM [gold].[fact_order_items] AS oi 
INNER JOIN [gold].[fact_orders] AS o 
    ON oi.order_id = o.order_id 
WHERE o.is_canceled = 0 
GROUP BY oi.product_id 
ORDER BY total_units_sold DESC;