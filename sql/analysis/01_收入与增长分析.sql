-- =============================================================
-- 分析模块 01：收入规模与增长分析
-- 业务问题：
--   1) 五家公司过去五年的收入体量差距如何变化？
--   2) 谁的成长性最好？谁在失速？
--   3) 按最新财年，各家在"盘子"里占多大份额？
-- SQL 技能点：窗口函数（LAG/SUM OVER）、同比计算、CTE、复合排序
-- =============================================================

USE internet_finance;

-- 1.1 各公司收入及同比增速（LAG 窗口函数实现同比）
SELECT
  c.company_name,
  i.fiscal_year,
  ROUND(i.revenue / 1e8, 1)                                   AS revenue_yi,   -- 统一换算为"亿"
  ROUND((i.revenue / LAG(i.revenue) OVER (
            PARTITION BY i.ticker ORDER BY i.fiscal_year) - 1) * 100, 1) AS rev_yoy_pct
FROM income_statement i
JOIN companies c ON c.ticker = i.ticker
ORDER BY c.company_name, i.fiscal_year;

-- 1.2 五年收入复合增速 CAGR（首末年聚合 + 幂运算）
SELECT
  c.company_name,
  ROUND(MIN(CASE WHEN i.fiscal_year = 2021 THEN i.revenue END) / 1e8, 1) AS rev_2021_yi,
  ROUND(MAX(CASE WHEN i.fiscal_year = 2025 THEN i.revenue END) / 1e8, 1) AS rev_2025_yi,
  ROUND((POWER(
        MAX(CASE WHEN i.fiscal_year = 2025 THEN i.revenue END) /
        MIN(CASE WHEN i.fiscal_year = 2021 THEN i.revenue END),
        1 / 4) - 1) * 100, 1) AS cagr_4y_pct
FROM income_statement i
JOIN companies c ON c.ticker = i.ticker
GROUP BY c.company_name
ORDER BY cagr_4y_pct DESC;

-- 1.3 最新财年市场份额（窗口函数求总盘，计算占比）
-- 注意：company_name 在维度表 companies 中，需 JOIN 获取（income_statement 只有 ticker）
WITH latest AS (
  SELECT i.ticker, c.company_name, i.revenue
  FROM income_statement i
  JOIN companies c ON c.ticker = i.ticker
  WHERE i.fiscal_year = (SELECT MAX(fiscal_year) FROM income_statement)
)
SELECT
  company_name,
  ROUND(revenue / 1e8, 1) AS revenue_yi,
  ROUND(revenue / SUM(revenue) OVER () * 100, 1) AS share_pct,
  RANK() OVER (ORDER BY revenue DESC) AS revenue_rank
FROM latest
ORDER BY revenue DESC;

-- 1.4 增长质量：连续加速 / 减速识别（业务视角的"拐点"信号）
WITH yoy AS (
  SELECT
    ticker,
    fiscal_year,
    (revenue / LAG(revenue) OVER (PARTITION BY ticker ORDER BY fiscal_year) - 1) * 100 AS yoy_pct
  FROM income_statement
),
yoy_with_lag AS (
  SELECT
    ticker,
    fiscal_year,
    yoy_pct,
    LAG(yoy_pct) OVER (PARTITION BY ticker ORDER BY fiscal_year) AS prev_yoy_pct
  FROM yoy
)
SELECT
  c.company_name,
  y.fiscal_year,
  ROUND(y.yoy_pct, 1) AS yoy_pct,
  ROUND(y.yoy_pct - y.prev_yoy_pct, 1) AS yoy_change_pp,
  CASE
    WHEN y.yoy_pct - y.prev_yoy_pct > 0 THEN '加速'
    WHEN y.yoy_pct - y.prev_yoy_pct < 0 THEN '减速'
    ELSE '持平'
  END AS momentum
FROM yoy_with_lag y
JOIN companies c ON c.ticker = y.ticker
WHERE y.fiscal_year > 2021
ORDER BY c.company_name, y.fiscal_year;