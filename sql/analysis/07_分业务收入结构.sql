-- =============================================================
-- 分析模块 07：分业务收入结构拆解（FY2023-2025）
-- 业务问题：
--   1) 各家收入结构三年间如何迁移？（如腾讯广告占比提升）
--   2) 谁依赖单一业务，谁更多元？（集中度 HHI 思路）
--   3) 各业务条线谁增长最快？——识别各公司的"第二增长曲线"
-- SQL 技能点：行列转换（条件聚合）、占比窗口计算、集中度指标、同比分板块
-- =============================================================

USE internet_finance;

-- 7.1 各公司分业务收入占比（分部收入 / 分部合计）
SELECT
  c.company_name,
  s.fiscal_year,
  s.segment_name,
  ROUND(s.segment_revenue / 1e8, 1) AS segment_revenue_yi,
  ROUND(s.segment_revenue / SUM(s.segment_revenue) OVER (
          PARTITION BY s.ticker, s.fiscal_year) * 100, 1) AS segment_share_pct
FROM business_segmentation s
JOIN companies c ON c.ticker = s.ticker
ORDER BY c.company_name, s.fiscal_year, segment_revenue_yi DESC;

-- 7.2 收入结构三年迁移透视表（行转列，便于直接观察趋势）
-- 注意：先在 CTE 中算好"占比"，再做条件聚合透视——窗口函数不能直接嵌进 GROUP BY 聚合里
WITH shares AS (
  SELECT
    ticker,
    fiscal_year,
    segment_name,
    segment_revenue / SUM(segment_revenue) OVER (PARTITION BY ticker, fiscal_year) * 100 AS share_pct
  FROM business_segmentation
)
SELECT
  c.company_name,
  s.segment_name,
  ROUND(MAX(CASE WHEN s.fiscal_year = 2023 THEN s.share_pct END), 1) AS share_2023_pct,
  ROUND(MAX(CASE WHEN s.fiscal_year = 2024 THEN s.share_pct END), 1) AS share_2024_pct,
  ROUND(MAX(CASE WHEN s.fiscal_year = 2025 THEN s.share_pct END), 1) AS share_2025_pct
FROM shares s
JOIN companies c ON c.ticker = s.ticker
GROUP BY c.company_name, s.ticker, s.segment_name
ORDER BY c.company_name, share_2025_pct DESC;

-- 7.3 业务集中度 HHI（赫芬达尔指数）：份额平方和，越高越依赖单一业务
WITH shares AS (
  SELECT
    ticker,
    fiscal_year,
    segment_name,
    segment_revenue / SUM(segment_revenue) OVER (PARTITION BY ticker, fiscal_year) AS share
  FROM business_segmentation
)
SELECT
  c.company_name,
  s.fiscal_year,
  ROUND(SUM(POWER(s.share, 2)) * 10000, 0) AS hhi_index   -- 0~10000，>2500 为高集中
FROM shares s
JOIN companies c ON c.ticker = s.ticker
GROUP BY c.company_name, s.fiscal_year
ORDER BY s.fiscal_year, hhi_index DESC;

-- 7.4 各公司分业务同比增速：寻找"第二增长曲线"
SELECT
  c.company_name,
  s.segment_name,
  s.fiscal_year,
  ROUND(s.segment_revenue / 1e8, 1) AS segment_revenue_yi,
  ROUND((s.segment_revenue / LAG(s.segment_revenue) OVER (
           PARTITION BY s.ticker, s.segment_name ORDER BY s.fiscal_year) - 1) * 100, 1) AS segment_yoy_pct
FROM business_segmentation s
JOIN companies c ON c.ticker = s.ticker
ORDER BY c.company_name, s.segment_name, s.fiscal_year;
