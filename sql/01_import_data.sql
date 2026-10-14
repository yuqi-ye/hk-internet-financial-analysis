-- =============================================================
-- 01_import_data.sql
-- 将清洗后的 CSV 导入 MySQL
-- 注意：路径需替换为你本地 data/clean 目录的绝对路径；
-- 若开启 secure_file_priv，请将 CSV 放入 `SHOW VARIABLES LIKE 'secure_file_priv';` 所示目录，
-- 或改用 `LOAD DATA LOCAL INFILE`（客户端需启用 local_infile=1）。
-- =============================================================

USE internet_finance;

SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE companies;
TRUNCATE TABLE income_statement;
TRUNCATE TABLE balance_sheet;
TRUNCATE TABLE cash_flow;
TRUNCATE TABLE business_segmentation;
SET FOREIGN_KEY_CHECKS = 1;

LOAD DATA LOCAL INFILE '/path/to/data/clean/companies.csv'
INTO TABLE companies
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE '/path/to/data/clean/income_statement.csv'
INTO TABLE income_statement
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(ticker, company_name, fiscal_year, revenue, cost_of_revenue, gross_profit,
 selling_expense, admin_expense, rd_expense, operating_profit,
 pretax_profit, income_tax, net_profit, net_profit_attributable);

LOAD DATA LOCAL INFILE '/path/to/data/clean/balance_sheet.csv'
INTO TABLE balance_sheet
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(ticker, company_name, fiscal_year, total_assets, total_liabilities, total_equity,
 current_assets, current_liabilities, cash_and_short_invest,
 accounts_receivable, inventory, goodwill, intangible_assets, deferred_revenue_current);

LOAD DATA LOCAL INFILE '/path/to/data/clean/cash_flow.csv'
INTO TABLE cash_flow
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(ticker, company_name, fiscal_year, cfo, cfi, cff, capex,
 depreciation_amortization, stock_based_comp, fcf);

LOAD DATA LOCAL INFILE '/path/to/data/clean/business_segmentation.csv'
INTO TABLE business_segmentation
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(ticker, fiscal_year, segment_name, segment_revenue, segment_gross_profit, @skip);

-- 导入校验：每张表应为 companies=5 行，三表各 25 行，分部表 57 行
SELECT 'companies' AS tbl, COUNT(*) AS rows_cnt FROM companies
UNION ALL SELECT 'income_statement', COUNT(*) FROM income_statement
UNION ALL SELECT 'balance_sheet', COUNT(*) FROM balance_sheet
UNION ALL SELECT 'cash_flow', COUNT(*) FROM cash_flow
UNION ALL SELECT 'business_segmentation', COUNT(*) FROM business_segmentation;
