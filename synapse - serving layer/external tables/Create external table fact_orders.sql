IF NOT EXISTS (SELECT * FROM sys.external_file_formats WHERE name = 'SynapseParquetFormat') 
	CREATE EXTERNAL FILE FORMAT [SynapseParquetFormat] 
	WITH ( FORMAT_TYPE = PARQUET)
GO

IF NOT EXISTS (SELECT * FROM sys.external_data_sources WHERE name = 'olistdata_souranolistdatastorage_dfs_core_windows_net') 
	CREATE EXTERNAL DATA SOURCE [olistdata_souranolistdatastorage_dfs_core_windows_net] 
	WITH (
		LOCATION = 'abfss://olistdata@souranolistdatastorage.dfs.core.windows.net' 
	)
GO

CREATE EXTERNAL TABLE gold.fact_orders (
	[order_id] nvarchar(120),
	[customer_id] nvarchar(120),
	[date_key] int,
	[order_status] nvarchar(120),
	[order_purchase_timestamp] datetime2(7),
	[order_delivered_customer_date] datetime2(7),
	[order_estimated_delivery_date] datetime2(7),
	[delivery_days] int,
	[is_delivered] int,
	[is_canceled] int,
	[item_count] bigint,
	[order_revenue] numeric(28,2),
	[order_freight] numeric(28,2)
	)
	WITH (
	LOCATION = 'gold/fact_orders/**',
	DATA_SOURCE = [olistdata_souranolistdatastorage_dfs_core_windows_net],
	FILE_FORMAT = [SynapseParquetFormat]
	)
GO


SELECT TOP 100 * FROM gold.fact_orders
GO
