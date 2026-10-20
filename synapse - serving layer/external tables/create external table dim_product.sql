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

CREATE EXTERNAL TABLE gold.dim_product (
	[product_category_name] nvarchar(120),
	[product_id] nvarchar(120),
	[product_name_lenght] int,
	[product_description_lenght] int,
	[product_photos_qty] int,
	[product_weight_g] int,
	[product_length_cm] int,
	[product_height_cm] int,
	[product_width_cm] int,
	[product_size_category] nvarchar(120),
	[product_category_name_english] nvarchar(120)
	)
	WITH (
	LOCATION = 'gold/dim_product/**',
	DATA_SOURCE = [olistdata_souranolistdatastorage_dfs_core_windows_net],
	FILE_FORMAT = [SynapseParquetFormat]
	)
GO


SELECT TOP 100 * FROM gold.dim_product
GO