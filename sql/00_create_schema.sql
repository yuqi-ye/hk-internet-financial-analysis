-- =============================================================
-- 00_create_schema.sql
-- 互联网企业财报指标拆解项目 · 数据库与表结构
-- 环境：MySQL 8.0+（窗口函数、CTE 均需 8.0 以上）
-- =============================================================

CREATE DATABASE IF NOT EXISTS internet_finance
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_0900_ai_ci;

USE internet_finance;

-- ---------- 维度表：公司 ----------
DROP TABLE IF EXISTS companies;
CREATE TABLE companies (
  ticker          VARCHAR(10)  PRIMARY KEY COMMENT '证券代码',
  company_name    VARCHAR(50)  NOT NULL COMMENT '公司中文名',
  company_name_en VARCHAR(50)  COMMENT '公司英文名',
  main_business   VARCHAR(100) COMMENT '主营业务',
  market          VARCHAR(10)  COMMENT '上市市场',
  listing_year    INT          COMMENT '上市年份'
) COMMENT '公司维度表';

-- ---------- 事实表：利润表（年度） ----------
DROP TABLE IF EXISTS income_statement;
CREATE TABLE income_statement (
  ticker                  VARCHAR(10)   NOT NULL,
  fiscal_year             INT           NOT NULL COMMENT '财年',
  revenue                 DECIMAL(20,2) COMMENT '营业收入',
  cost_of_revenue         DECIMAL(20,2) COMMENT '营业成本',
  gross_profit            DECIMAL(20,2) COMMENT '毛利润',
  selling_expense         DECIMAL(20,2) COMMENT '销售及营销费用',
  admin_expense           DECIMAL(20,2) COMMENT '管理费用',
  rd_expense              DECIMAL(20,2) COMMENT '研发费用（腾讯未单独披露，为 NULL）',
  operating_profit        DECIMAL(20,2) COMMENT '经营利润',
  pretax_profit           DECIMAL(20,2) COMMENT '税前利润',
  income_tax              DECIMAL(20,2) COMMENT '所得税',
  net_profit              DECIMAL(20,2) COMMENT '净利润',
  net_profit_attributable DECIMAL(20,2) COMMENT '归母净利润',
  PRIMARY KEY (ticker, fiscal_year),
  FOREIGN KEY (ticker) REFERENCES companies(ticker)
) COMMENT '利润表（年度）';

-- ---------- 事实表：资产负债表（年末） ----------
DROP TABLE IF EXISTS balance_sheet;
CREATE TABLE balance_sheet (
  ticker                   VARCHAR(10)   NOT NULL,
  fiscal_year              INT           NOT NULL,
  total_assets             DECIMAL(20,2) COMMENT '总资产',
  total_liabilities        DECIMAL(20,2) COMMENT '总负债',
  total_equity             DECIMAL(20,2) COMMENT '股东权益',
  current_assets           DECIMAL(20,2) COMMENT '流动资产',
  current_liabilities      DECIMAL(20,2) COMMENT '流动负债',
  cash_and_short_invest    DECIMAL(20,2) COMMENT '现金及短期投资',
  accounts_receivable      DECIMAL(20,2) COMMENT '应收账款',
  inventory                DECIMAL(20,2) COMMENT '存货',
  goodwill                 DECIMAL(20,2) COMMENT '商誉',
  intangible_assets        DECIMAL(20,2) COMMENT '无形资产',
  deferred_revenue_current DECIMAL(20,2) COMMENT '合同负债/递延收入（流动）',
  PRIMARY KEY (ticker, fiscal_year),
  FOREIGN KEY (ticker) REFERENCES companies(ticker)
) COMMENT '资产负债表（年末时点）';

-- ---------- 事实表：现金流量表（年度） ----------
DROP TABLE IF EXISTS cash_flow;
CREATE TABLE cash_flow (
  ticker                 VARCHAR(10)   NOT NULL,
  fiscal_year            INT           NOT NULL,
  cfo                    DECIMAL(20,2) COMMENT '经营活动现金流净额',
  cfi                    DECIMAL(20,2) COMMENT '投资活动现金流净额',
  cff                    DECIMAL(20,2) COMMENT '筹资活动现金流净额',
  capex                  DECIMAL(20,2) COMMENT '资本开支（购建固定资产无形资产）',
  depreciation_amortization DECIMAL(20,2) COMMENT '折旧摊销',
  stock_based_comp       DECIMAL(20,2) COMMENT '股权激励费用',
  fcf                    DECIMAL(20,2) COMMENT '自由现金流 = CFO - CapEx',
  PRIMARY KEY (ticker, fiscal_year),
  FOREIGN KEY (ticker) REFERENCES companies(ticker)
) COMMENT '现金流量表（年度）';

-- ---------- 事实表：分业务收入（FY2023-2025） ----------
DROP TABLE IF EXISTS business_segmentation;
CREATE TABLE business_segmentation (
  id                 INT AUTO_INCREMENT PRIMARY KEY,
  ticker             VARCHAR(10)   NOT NULL,
  fiscal_year        INT           NOT NULL,
  segment_name       VARCHAR(50)   NOT NULL COMMENT '业务分部名称',
  segment_revenue    DECIMAL(20,2) COMMENT '分部收入',
  segment_gross_profit DECIMAL(20,2) COMMENT '分部毛利（部分缺失）',
  FOREIGN KEY (ticker) REFERENCES companies(ticker),
  UNIQUE KEY uk_seg (ticker, fiscal_year, segment_name)
) COMMENT '分业务收入构成';
