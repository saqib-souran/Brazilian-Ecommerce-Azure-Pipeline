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

CREATE EXTERNAL TABLE gold.dim_customer (
	[customer_id] nvarchar(100),
	[customer_unique_id] nvarchar(100),
	[customer_zip_code_prefix] nvarchar(100),
	[customer_city] nvarchar(100),
	[customer_state] nvarchar(100)
	)
	WITH (
	LOCATION = 'gold/dim_customer/**',
	DATA_SOURCE = [olistdata_souranolistdatastorage_dfs_core_windows_net],
	FILE_FORMAT = [SynapseParquetFormat]
	)
GO


SELECT TOP 100 * FROM gold.dim_customer
GO