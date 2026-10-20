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

CREATE EXTERNAL TABLE gold.fact_order_items (
	[order_id] nvarchar(120),
	[order_item_id] int,
	[customer_id] nvarchar(120),
	[product_id] nvarchar(120),
	[seller_id] nvarchar(120),
	[date_key] int,
	[price] numeric(18,2),
	[freight_value] numeric(18,2)
	)
	WITH (
	LOCATION = 'gold/fact_order_items/**',
	DATA_SOURCE = [olistdata_souranolistdatastorage_dfs_core_windows_net],
	FILE_FORMAT = [SynapseParquetFormat]
	)
GO


SELECT TOP 100 * FROM gold.fact_order_items
GO