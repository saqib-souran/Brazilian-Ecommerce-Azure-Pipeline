CREATE VIEW [gold].[vw_total_revenues_per_seller] AS 
SELECT oi.seller_id, 
    COUNT(DISTINCT oi.order_id) AS total_orders, 
    COUNT(*) AS total_items_sold, SUM(oi.price) AS total_revenue, 
    SUM(oi.freight_value) AS total_freight, 
    SUM(oi.price + COALESCE(oi.freight_value, 0)) AS total_revenue_with_freight 
FROM [gold].[fact_order_items] AS oi 
INNER JOIN [gold].[fact_orders] AS o 
    ON oi.order_id = o.order_id 
WHERE o.is_canceled = 0 
GROUP BY oi.seller_id;