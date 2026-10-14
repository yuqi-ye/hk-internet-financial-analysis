-- =============================================================
-- 分析模块 06：偿债能力与资产质量
-- 业务问题：
--   1) 各家的资产负债表是否稳健？（资产负债率、流动比率）
--   2) 账上现金能否覆盖短期负债？（现金比率）
--   3) 商誉占净资产比重——并购历史留下的减值风险有多大？
-- SQL 技能点：多条件 CASE 风险分层、横向排名、阈值标记
-- =============================================================

USE internet_finance;

-- 6.1 偿债能力三指标全景
SELECT
  c.company_name,
  b.fiscal_year,
  ROUND(b.total_liabilities / NULLIF(b.total_assets, 0) * 100, 1)      AS debt_ratio_pct,
  ROUND(b.current_assets / NULLIF(b.current_liabilities, 0), 2)        AS current_ratio,
  ROUND(b.cash_and_short_invest / NULLIF(b.current_liabilities, 0), 2) AS cash_ratio
FROM balance_sheet b
JOIN companies c ON c.ticker = b.ticker
ORDER BY c.company_name, b.fiscal_year;

-- 6.2 最新财年风险分层（CASE 多维打分）
WITH latest AS (
  SELECT
    ticker,
    total_liabilities / NULLIF(total_assets, 0) * 100        AS debt_ratio,
    current_assets / NULLIF(current_liabilities, 0)          AS current_ratio,
    cash_and_short_invest / NULLIF(current_liabilities, 0)   AS cash_ratio,
    goodwill / NULLIF(total_equity, 0) * 100                 AS goodwill_to_equity
  FROM balance_sheet
  WHERE fiscal_year = (SELECT MAX(fiscal_year) FROM balance_sheet)
)
SELECT
  c.company_name,
  ROUND(l.debt_ratio, 1)          AS debt_ratio_pct,
  ROUND(l.current_ratio, 2)       AS current_ratio,
  ROUND(l.cash_ratio, 2)          AS cash_ratio,
  ROUND(l.goodwill_to_equity, 1)  AS goodwill_to_equity_pct,
  CASE WHEN l.debt_ratio < 40 THEN 2 WHEN l.debt_ratio < 60 THEN 1 ELSE 0 END +
  CASE WHEN l.current_ratio > 2 THEN 2 WHEN l.current_ratio > 1 THEN 1 ELSE 0 END +
  CASE WHEN l.cash_ratio > 1 THEN 2 WHEN l.cash_ratio > 0.5 THEN 1 ELSE 0 END AS safety_score,  -- 满分6分
  RANK() OVER (ORDER BY l.debt_ratio ASC) AS debt_ratio_rank_low2high
FROM latest l
JOIN companies c ON c.ticker = l.ticker
ORDER BY safety_score DESC;

-- 6.3 合同负债（递延收入）观察：游戏/会员业务的"预收蓄水池"
-- 递延收入增长往往领先于收入确认，是游戏公司下季度收入的先行指标
SELECT
  c.company_name,
  b.fiscal_year,
  ROUND(b.deferred_revenue_current / 1e8, 1) AS deferred_revenue_yi,
  ROUND(b.deferred_revenue_current / NULLIF(i.revenue, 0) * 100, 1) AS deferred_to_rev_pct
FROM balance_sheet b
JOIN income_statement i ON i.ticker = b.ticker AND i.fiscal_year = b.fiscal_year
JOIN companies c ON c.ticker = b.ticker
WHERE b.deferred_revenue_current IS NOT NULL
ORDER BY c.company_name, b.fiscal_year;
