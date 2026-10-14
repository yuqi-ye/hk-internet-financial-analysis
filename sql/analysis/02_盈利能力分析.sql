-- =============================================================
-- 分析模块 02：盈利能力分析
-- 业务问题：
--   1) 商业模式差异如何体现在毛利率上？（平台抽佣 vs 内容社区 vs 游戏）
--   2) 谁实现了从亏损到盈利的转折？转折点发生在哪一年？
--   3) 毛利率最高的公司为什么净利率未必最高？
-- SQL 技能点：多表 JOIN、CASE WHEN 分层、条件聚合、NULL 处理
-- =============================================================

USE internet_finance;

-- 2.1 五家公司五年三级利润率全景（毛利率 → 经营利润率 → 净利率）
SELECT
  c.company_name,
  i.fiscal_year,
  ROUND(i.gross_profit      / NULLIF(i.revenue, 0) * 100, 1) AS gross_margin_pct,
  ROUND(i.operating_profit  / NULLIF(i.revenue, 0) * 100, 1) AS op_margin_pct,
  ROUND(i.net_profit_attributable / NULLIF(i.revenue, 0) * 100, 1) AS net_margin_pct
FROM income_statement i
JOIN companies c ON c.ticker = i.ticker
ORDER BY c.company_name, i.fiscal_year;

-- 2.2 盈利转折点识别：首次实现年度盈利的财年
WITH profit_flag AS (
  SELECT
    ticker,
    fiscal_year,
    net_profit_attributable,
    CASE WHEN net_profit_attributable > 0 THEN 1 ELSE 0 END AS is_profitable
  FROM income_statement
)
SELECT
  c.company_name,
  MIN(CASE WHEN p.is_profitable = 1 THEN p.fiscal_year END) AS first_profitable_year,
  SUM(CASE WHEN p.is_profitable = 1 THEN 1 ELSE 0 END)      AS profitable_years_of_5,
  SUM(CASE WHEN p.is_profitable = 0 THEN 1 ELSE 0 END)      AS loss_years_of_5
FROM profit_flag p
JOIN companies c ON c.ticker = p.ticker
GROUP BY c.company_name
ORDER BY first_profitable_year IS NULL, first_profitable_year;

-- 2.3 最新财年盈利能力排名 + 与自身五年均值对比（当前水平 vs 历史中枢）
WITH latest AS (
  SELECT
    ticker,
    gross_profit / NULLIF(revenue, 0) * 100 AS gm,
    net_profit_attributable / NULLIF(revenue, 0) * 100 AS nm
  FROM income_statement
  WHERE fiscal_year = (SELECT MAX(fiscal_year) FROM income_statement)
),
hist_avg AS (
  SELECT
    ticker,
    AVG(gross_profit / NULLIF(revenue, 0) * 100) AS avg_gm_5y,
    AVG(net_profit_attributable / NULLIF(revenue, 0) * 100) AS avg_nm_5y
  FROM income_statement
  GROUP BY ticker
)
SELECT
  c.company_name,
  ROUND(l.gm, 1)              AS gross_margin_now,
  ROUND(h.avg_gm_5y, 1)       AS gross_margin_5y_avg,
  ROUND(l.gm - h.avg_gm_5y, 1) AS gm_vs_hist_pp,
  ROUND(l.nm, 1)              AS net_margin_now,
  RANK() OVER (ORDER BY l.nm DESC) AS net_margin_rank
FROM latest l
JOIN hist_avg h ON h.ticker = l.ticker
JOIN companies c ON c.ticker = l.ticker
ORDER BY net_margin_rank;
