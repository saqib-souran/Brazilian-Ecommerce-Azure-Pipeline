CREATE VIEW [gold].[vw_top_10_customers_by_spending] AS 
SELECT TOP 10 c.customer_unique_id, 
    COUNT(DISTINCT o.order_id) AS total_orders, 
    SUM(o.order_revenue) AS total_spending, 
    SUM(o.order_freight) AS total_freight, 
    SUM(o.order_revenue + COALESCE(o.order_freight, 0)) AS total_spending_with_freight 
FROM [gold].[fact_orders] AS o 
INNER JOIN [gold].[dim_customer] AS c 
    ON o.customer_id = c.customer_id 
WHERE o.is_canceled = 0 
GROUP BY c.customer_unique_id 
ORDER BY total_spending DESC;