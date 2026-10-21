# Brazilian E-commerce Data Pipeline on Azure

**An Azure data engineering portfolio project that turns Olist e-commerce data into validated analytical tables using a Bronze → Silver → Gold architecture.**

CSV files hosted on GitHub and payment records stored in MySQL are ingested with Azure Data Factory into Azure Data Lake Storage Gen2. Azure Databricks cleans the data with PySpark and enriches product categories with English translations from MongoDB. Gold dimension and fact tables are exposed through Azure Synapse SQL external tables and analytical views.

**Stack:** Azure Data Factory · ADLS Gen2 · Azure Databricks · PySpark · MySQL · MongoDB · Azure Synapse Analytics · SQL

## Contents

- [Project objective](#project-objective)
- [Architecture](#architecture)
- [Data sources](#data-sources)
- [Pipeline implementation](#pipeline-implementation)
- [Gold data model](#gold-data-model)
- [Validation and results](#validation-and-results)
- [Analytical views](#analytical-views)
- [Repository guide](#repository-guide)
- [How to run](#how-to-run)
- [Design decisions](#design-decisions)
- [Current limitations and next steps](#current-limitations-and-next-steps)
- [Learning background and acknowledgements](#learning-background-and-acknowledgements)

## Project objective

The objective is to practise building a complete batch data pipeline: prepare different source systems, ingest raw data, apply justified cleaning rules, model business entities and make the results available through SQL.

The analytical layer supports questions such as:

- Which products have the highest number of items sold?
- Which sellers generate the highest merchandise value?
- Which customers place repeat orders or spend the most?
- How do order volumes and item value vary over time?

The project focuses on data engineering and SQL serving. A dashboard is a planned extension.

## Architecture

![Olist e-commerce data pipeline architecture](<Data Pipeline Architecture Diagram.png>)

There are two ingestion paths:

1. **Main pipeline:** GitHub CSV files + MySQL payments → Azure Data Factory → ADLS Bronze → Databricks → ADLS Silver → Databricks → ADLS Gold → Synapse SQL.
2. **Enrichment path:** MongoDB category translations → Databricks → enriched products in Silver.

Bronze, Silver and Gold are directories in ADLS Gen2. Databricks performs the transformations; Synapse queries the Gold Parquet files through external tables.

## Data sources

The source is the [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce), containing anonymised orders placed between 2016 and 2018.

All source data originally comes from CSV files. Selected files are loaded into MySQL and MongoDB to simulate different source systems and practise working with relational tables and document collections.

| Dataset | Source used by the pipeline | Purpose |
| --- | --- | --- |
| Customers | GitHub CSV | Customer identifiers and location |
| Orders | GitHub CSV | Order status and lifecycle timestamps |
| Order items | GitHub CSV | Products, sellers, prices and freight per order item |
| Order payments | MySQL | Payment methods, sequences, instalments and amounts |
| Products | GitHub CSV | Product categories and physical attributes |
| Sellers | GitHub CSV | Seller identifiers and location |
| Geolocation | GitHub CSV | ZIP prefixes and geographic coordinates |
| Order reviews | GitHub CSV | Review scores, comments and timestamps |
| Product category translations | MongoDB | Portuguese-to-English category enrichment |

The translation dataset contains category labels, rather than individual product names. MongoDB documents provide a small reference dataset for enrichment.

## Pipeline implementation

### 1. Prepare the sources

The source-preparation notebook:

- Reads payment records from the source CSV and loads them into MySQL in batches.
- Uses a `DECIMAL(18,2)` column for payment values in MySQL.
- Loads category translations into a MongoDB collection.
- Compares loaded row/document counts with the input counts.

The notebook recreates its target table and collection for a full refresh. It is intended for dedicated project databases.

### 2. Ingest into Bronze

Azure Data Factory copies the seven GitHub CSV datasets and the MySQL payment table into ADLS Bronze.

A JSON input list supplies CSV relative URLs and destination filenames. A Lookup activity and a ForEach activity drive the CSV copies, followed by a MySQL copy activity.

![Azure Data Factory ingestion pipeline](<azure data factory/ADF Pipeline Screenshot.png>)

### 3. Clean and enrich into Silver

Databricks reads Bronze and writes eight cleaned source datasets as Parquet.

| Dataset | Main implemented transformations |
| --- | --- |
| Orders | Remove records missing required identifiers/status, preserve timestamps, derive purchase date and delivery duration |
| Items | Cast price and freight to decimal; flag prices outside the 1st–99th percentile range while retaining the transactions |
| Payments | Cast amounts to decimal; check missing amounts and duplicate payment keys |
| Customers | Pad ZIP prefixes to five characters and deduplicate customer IDs |
| Products | Derive a weight-based size category, retain an `Unknown` category for missing/non-positive weights and left-join MongoDB translations |
| Geolocation | Pad ZIP prefixes, standardise city/state text, validate coordinate ranges and remove exact duplicates |
| Reviews | Cast score/date fields, trim comments, validate scores and derive a score-based sentiment label |
| Sellers | Standardise text, handle empty values, pad ZIP prefixes and deduplicate seller IDs |

**Financial amounts are preserved:** unusual item prices are flagged for investigation instead of removed, and payment amounts are not replaced by statistical estimates.

The review sentiment field is derived from the numeric rating; it is not an NLP model applied to comment text.

![Silver datasets in ADLS](<adls/silver/Silver Layer Screenshot.png>)

### 4. Model into Gold

A second Databricks notebook reads Silver and builds four dimensions and two fact tables. Item values are aggregated to the order level before joining to orders.

Gold datasets are saved as Parquet in separate table directories.

### 5. Serve through Synapse SQL

The serving layer contains:

- External tables pointing to Gold Parquet directories.
- SQL views for customer, seller and product analysis.
- A purchase-timestamp definition of `datetime2(7)` matching the timestamp retained in Gold.

![Synapse SQL serving layer](<synapse - serving layer/Synapse Studio Screenshot.png>)

## Gold data model

| Table | Grain: what one row represents | Key |
| --- | --- | --- |
| `dim_customer` | One source customer record | `customer_id` |
| `dim_product` | One product | `product_id` |
| `dim_seller` | One seller | `seller_id` |
| `dim_date` | One calendar date within the purchase-date range | `date_key` |
| `fact_orders` | One order | `order_id` |
| `fact_order_items` | One item within an order | `order_id` + `order_item_id` |

`fact_orders` links to customers and purchase dates. `fact_order_items` links to customers, products, sellers and purchase dates. Both facts retain `order_id` for order-level analysis.

Two customer identifiers have different purposes:

- `customer_id` links an order to its source customer record.
- `customer_unique_id` identifies customers across multiple orders and is used in customer-level views.

### Metric definitions

| Metric | Definition |
| --- | --- |
| `price` | Merchandise value of one order item, excluding freight |
| `order_revenue` | Sum of item prices per order; merchandise order value rather than verified accounting revenue |
| `order_freight` | Sum of freight values per order |
| `item_count` | Number of order-item records per order |
| `delivery_days` | Difference in calendar days between purchase and customer delivery; null when delivery date is missing |
| Payment value | Actual source payment amount, retained in Silver; not currently exposed as a Gold payment fact |

The current analytical views exclude cancelled orders using `is_canceled = 0`. They do not restrict results to delivered orders. The validation totals below include all order statuses.

## Validation and results

The committed notebook outputs record the following results from the corrected pipeline run:

| Check | Recorded result |
| --- | ---: |
| Silver orders | 99,441 |
| Silver order items | 112,650 |
| Silver payment records | 103,886 |
| Silver customers | 99,441 |
| Silver products | 32,951 |
| Silver sellers | 3,095 |
| Silver geolocation records after cleaning/deduplication | 720,469 |
| Silver review records | 99,224 |
| Gold orders | 99,441 |
| Gold order items | 112,650 |
| Gold total item value, excluding freight | R$13,591,643.70 |

Implemented assertions check:

- Required keys are non-null and unique in the selected Silver datasets.
- Item and payment row counts and amount totals are preserved during cleaning.
- All eight Silver outputs are non-empty.
- Gold fact row counts match their Silver inputs.
- Order and order-item fact keys are unique.
- Silver item value equals Gold item value.
- Order-level revenue, freight and item counts agree with the item fact.
- Fact references to customer, product, seller and date dimensions are valid.

Saved notebook output is evidence of a recorded run. Run the checks again after changing source data or transformation rules.

> **Add image here:** a readable screenshot of the final Gold validation output showing counts, total item value and successful checks.

### Verify the serving layer

After creating the external tables, run these queries in the Synapse BI database:

```sql
SELECT
    COUNT_BIG(*) AS total_orders,
    SUM(order_revenue) AS total_item_value
FROM gold.fact_orders;

SELECT
    COUNT_BIG(*) AS total_order_items,
    SUM(price) AS total_item_value
FROM gold.fact_order_items;
```

For the source version used above, expect 99,441 orders, 112,650 items and the same item-value total of R$13,591,643.70 in both queries.

> **Add image here:** Synapse query results confirming the counts and matching totals. Use results from your own run.

## Analytical views

| View | Output |
| --- | --- |
| `gold.vw_total_orders_per_customer` | Order count per unique customer |
| `gold.vw_top_10_customers_by_spending` | Top customers by merchandise order value, with freight reported separately |
| `gold.vw_top_10_most_sold_products` | Top products by item count, with distinct order count and item value |
| `gold.vw_total_revenues_per_seller` | Seller-level order counts, item counts, merchandise value and freight |

Example:

```sql
SELECT TOP 10
    seller_id,
    total_orders,
    total_items_sold,
    total_revenue,
    total_freight
FROM gold.vw_total_revenues_per_seller
ORDER BY total_revenue DESC;
```

View names use “revenue” and “spending”; their current calculations are based on item prices and freight, not reconciled payments or accounting recognition rules.

## Repository guide

| Location | Contents |
| --- | --- |
| `data/` | Source Olist CSV files used for source preparation and HTTP ingestion |
| `databricks notebooks/` | Source preparation, Bronze exploration, Silver transformation and Gold modelling notebooks |
| `azure data factory/` | CSV input configuration and ingestion-pipeline screenshot |
| `adls/` | Storage-layer screenshots and committed Bronze data copies |
| `synapse - serving layer/external tables/` | External-table creation scripts for the six Gold tables |
| `synapse - serving layer/views/` | Analytical view definitions |
| `mySQL source/` | MySQL source screenshot |
| `mongoDB source enrichment/` | MongoDB reference-data screenshot |
| `Data Pipeline Architecture Diagram.png` | Architecture diagram |

## How to run

### Prerequisites

- An Azure subscription with permissions to configure ADF, ADLS Gen2, Databricks and Synapse.
- An ADLS Gen2 account with hierarchical namespace enabled and a project container.
- MySQL and MongoDB databases accessible from the relevant compute environments.
- A Python notebook environment for source preparation, with `pandas`, `mysql-connector-python` and `pymongo`.
- A Databricks runtime supporting PySpark and access to the required Python dependencies.
- Appropriate storage permissions for Databricks and the Synapse querying identity.

Azure services may incur charges. Stop unused compute after completing a run.

### Execution order

1. **Clone the repository.**

   ```bash
   git clone https://github.com/saqib-souran/Brazilian-Ecommerce-Azure-Pipeline.git
   cd Brazilian-Ecommerce-Azure-Pipeline
   ```

2. **Configure your environment.** Create the project resources and the Bronze, Silver and Gold storage directories. Replace the notebook configuration values with your own storage, container, identity and database settings. Use private secret storage for actual credentials; the committed credential values are documented as placeholders.

3. **Prepare the databases.** Run `0. Data Source Preparation.ipynb` in your source-preparation environment. Confirm the MySQL payment count and MongoDB document count. This step recreates the configured targets.

4. **Configure and run ADF ingestion.** Create the HTTP, MySQL and ADLS linked services and datasets. Configure Lookup/ForEach CSV ingestion using `ForEachInputFiles_DataFactory.json`, then copy the MySQL payment table. Ensure linked-service base URLs and the JSON relative URLs resolve to the intended raw GitHub files.

   **Reproduction note:** the repository currently includes the input list and a screenshot, rather than a complete ADF deployment export. The ingestion resources must therefore be configured manually.

5. **Explore Bronze if needed.** Run `1. Data Exploration at Bronze.ipynb` to inspect source schemas and distributions. This notebook is exploratory; it is not required to produce Silver.

6. **Build Silver.** Run `2. Data Cleaning and Transformation to Silver.ipynb` from the beginning in Databricks. Review validation output before allowing the final cell to overwrite the eight Silver directories.

7. **Build Gold.** Run `3. Data Integration and Aggregation to Gold.ipynb` from the beginning. Run both validation cells before writing the six Gold directories.

8. **Create the SQL serving layer.** In the intended Synapse SQL database, create the `gold` schema if it does not exist. Configure storage access for your querying identity and replace storage references in the scripts. Run the six external-table scripts before the four view scripts. The current scripts are not a complete deployment package and may require existing objects to be handled before rerunning.

9. **Validate SQL results.** Run the serving-layer count and amount checks above, then query the analytical views.

There is currently no single command or orchestrator that runs all notebook and SQL steps together.

## Design decisions

- **Different source systems:** MySQL and MongoDB simulate heterogeneous ingestion even though the original dataset is CSV-based.
- **Separate storage layers:** Bronze retains raw inputs, Silver stores cleaned source datasets and Gold stores dimensions and facts.
- **Parquet output:** Silver and Gold use a columnar format that can be consumed by Spark and Synapse.
- **Small reference-data enrichment:** The 71 MongoDB translation documents are read through PyMongo and pandas before conversion to a Spark DataFrame.
- **Separate fact grains:** Order and order-item facts support different analytical questions without mixing their levels of detail.
- **Preserved financial transactions:** Price outliers remain in the data; totals are validated across transformations.
- **Full refresh:** Silver and Gold use overwrite writes. Incremental processing is outside the current implementation.

## Current limitations and next steps

This is a learning and portfolio implementation with manually configured cloud resources.

| Area | Current limitation / next step |
| --- | --- |
| CSV parsing | Add explicit multiline and quote/escape handling for reviews in the committed readers, then validate comment content as well as row counts |
| Payment categories | Preserve original payment codes and add readable labels separately; the current mapping collapses some categories |
| Configuration | Replace repeated configuration blocks with reusable configuration and secret references |
| Source loading | Improve exception handling, connection cleanup and full-refresh failure recovery |
| Deployment | Export ADF pipeline, dataset and linked-service definitions with secrets excluded |
| Scheduling | Connect ingestion and Databricks processing into a managed execution sequence with failure handling |
| Data contracts | Replace schema inference with explicit schemas and expand rejected-record reporting |
| Enrichment | Report missing translations and validate translation-key uniqueness explicitly |
| Payments | Add order-level payment reconciliation or a Gold payment fact if payment analysis is required |
| Reporting | Build a dashboard using the Synapse serving layer |

Incremental loading, CI/CD, infrastructure as code and a dashboard are possible extensions. They are not claimed as implemented features.

## Learning background and acknowledgements

This project was developed while following the Udemy course [Big Data Engineering Bootcamp with GCP and Azure Cloud](https://www.udemy.com/course/big-data-engineering-bootcamp-with-gcp-and-azure-cloud/), then refined through additional implementation review and validation.

The repository includes work on preserving financial totals, retaining price outliers with flags, correcting ZIP prefixes, documenting fact-table grains and adding Silver/Gold validation checks.

- **Author:** [Saqib Souran](https://github.com/saqib-souran)
- **Dataset:** [Olist Brazilian E-Commerce Public Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)

Dataset rights and reuse conditions are governed by the original dataset's licence. The Azure and database services referenced here are used as part of a personal learning project.
