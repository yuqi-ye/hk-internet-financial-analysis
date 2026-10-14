-- =============================================================
-- 分析模块 04：杜邦分析 —— ROE 三因素拆解
-- 业务问题：
--   ROE = 净利率 × 总资产周转率 × 权益乘数
--   各家的股东回报是靠"高利润"（网易模式）、"高周转"（美团模式）
--   还是"高杠杆"驱动的？
-- SQL 技能点：跨三表 JOIN、平均值处理（期末 vs 平均口径说明）、多步骤 CTE
-- =============================================================

USE internet_finance;

-- 4.1 杜邦三因素五年全景
-- 口径说明：周转率与杠杆用"期末余额"近似（数据源为期末快照）；
-- 严谨做法是用 (期初+期末)/2 的平均资产，本项目用 LAG 自取期初值实现。
WITH dupont AS (
  SELECT
    i.ticker,
    i.fiscal_year,
    i.net_profit_attributable / NULLIF(i.revenue, 0)                       AS net_margin,
    i.revenue / NULLIF((b.total_assets + LAG(b.total_assets) OVER (
                          PARTITION BY i.ticker ORDER BY i.fiscal_year)) / 2, 0) AS asset_turnover,
    (b.total_assets + LAG(b.total_assets) OVER (
        PARTITION BY i.ticker ORDER BY i.fiscal_year)) / 2 /
      NULLIF((b.total_equity + LAG(b.total_equity) OVER (
        PARTITION BY i.ticker ORDER BY i.fiscal_year)) / 2, 0)             AS equity_multiplier
  FROM income_statement i
  JOIN balance_sheet b ON b.ticker = i.ticker AND b.fiscal_year = i.fiscal_year
)
SELECT
  c.company_name,
  d.fiscal_year,
  ROUND(d.net_margin * 100, 1)        AS net_margin_pct,
  ROUND(d.asset_turnover, 2)          AS asset_turnover_x,
  ROUND(d.equity_multiplier, 2)       AS equity_multiplier_x,
  ROUND(d.net_margin * d.asset_turnover * d.equity_multiplier * 100, 1) AS roe_pct
FROM dupont d
JOIN companies c ON c.ticker = d.ticker
WHERE d.asset_turnover IS NOT NULL   -- 首年无期初资产，剔除
ORDER BY c.company_name, d.fiscal_year;

-- 4.2 最新财年：五家公司 ROE 驱动模式对比与分型
WITH dupont_latest AS (
  SELECT
    i.ticker,
    i.net_profit_attributable / NULLIF(i.revenue, 0)  AS net_margin,
    i.revenue / NULLIF(b.total_assets, 0)             AS asset_turnover,
    b.total_assets / NULLIF(b.total_equity, 0)        AS equity_multiplier
  FROM income_statement i
  JOIN balance_sheet b ON b.ticker = i.ticker AND b.fiscal_year = i.fiscal_year
  WHERE i.fiscal_year = (SELECT MAX(fiscal_year) FROM income_statement)
)
SELECT
  c.company_name,
  ROUND(d.net_margin * 100, 1)        AS net_margin_pct,
  ROUND(d.asset_turnover, 2)          AS asset_turnover_x,
  ROUND(d.equity_multiplier, 2)       AS equity_multiplier_x,
  ROUND(d.net_margin * d.asset_turnover * d.equity_multiplier * 100, 1) AS roe_pct,
  CASE
    WHEN d.net_margin >= 0.15 THEN '利润率驱动型'
    WHEN d.asset_turnover >= 1.0 THEN '周转驱动型'
    ELSE '杠杆/混合型'
  END AS roe_driver_type
FROM dupont_latest d
JOIN companies c ON c.ticker = d.ticker
ORDER BY roe_pct DESC;
