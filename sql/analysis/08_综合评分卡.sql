-- =============================================================
-- 分析模块 08：综合评分卡 —— 一张表看懂五家公司
-- 业务问题：
--   如果只能推荐一家"基本面最健康"的公司，选谁？
--   从成长性、盈利性、现金质量、安全性四个维度综合打分。
-- SQL 技能点：多 CTE 串联、窗口排名打分、加权汇总（本项目的"收口"查询）
-- =============================================================

USE internet_finance;

WITH latest_year AS (
  SELECT MAX(fiscal_year) AS y FROM income_statement
),
growth AS (   -- 成长性：收入 CAGR（4年）
  SELECT
    ticker,
    POWER(
      MAX(CASE WHEN fiscal_year = (SELECT y FROM latest_year) THEN revenue END) /
      MIN(CASE WHEN fiscal_year = (SELECT y FROM latest_year) - 4 THEN revenue END),
      1 / 4) - 1 AS cagr
  FROM income_statement
  GROUP BY ticker
),
profit AS (   -- 盈利性：最新净利率
  SELECT ticker, net_profit_attributable / NULLIF(revenue, 0) AS net_margin
  FROM income_statement
  WHERE fiscal_year = (SELECT y FROM latest_year)
),
cashq AS (    -- 现金质量：最新 CFO/净利润（净利润为负时以 CFO 符号代替）
  SELECT
    f.ticker,
    CASE WHEN i.net_profit_attributable > 0
         THEN LEAST(f.cfo / NULLIF(i.net_profit_attributable, 0), 2)   -- 截断极值
         ELSE SIGN(f.cfo) END AS cash_quality
  FROM cash_flow f
  JOIN income_statement i ON i.ticker = f.ticker AND i.fiscal_year = f.fiscal_year
  WHERE f.fiscal_year = (SELECT y FROM latest_year)
),
safety AS (   -- 安全性：资产负债率（越低越好）
  SELECT ticker, total_liabilities / NULLIF(total_assets, 0) AS debt_ratio
  FROM balance_sheet
  WHERE fiscal_year = (SELECT y FROM latest_year)
),
scored AS (
  SELECT
    g.ticker,
    g.cagr,
    p.net_margin,
    q.cash_quality,
    s.debt_ratio,
    -- 各维度 1-5 名打分（名次即分数基数）
    RANK() OVER (ORDER BY g.cagr DESC)        AS growth_rank,
    RANK() OVER (ORDER BY p.net_margin DESC)  AS profit_rank,
    RANK() OVER (ORDER BY q.cash_quality DESC) AS cash_rank,
    RANK() OVER (ORDER BY s.debt_ratio ASC)   AS safety_rank
  FROM growth g
  JOIN profit p  ON p.ticker = g.ticker
  JOIN cashq q   ON q.ticker = g.ticker
  JOIN safety s  ON s.ticker = g.ticker
)
SELECT
  c.company_name,
  ROUND(sc.cagr * 100, 1)          AS revenue_cagr_pct,
  ROUND(sc.net_margin * 100, 1)    AS net_margin_pct,
  ROUND(sc.cash_quality, 2)        AS cfo_to_np,
  ROUND(sc.debt_ratio * 100, 1)    AS debt_ratio_pct,
  -- 加权总分：成长 30%、盈利 30%、现金 20%、安全 20%（名次越小越好，故用 6-名次 转为正向分）
  ROUND(
    (6 - sc.growth_rank) * 0.3 +
    (6 - sc.profit_rank) * 0.3 +
    (6 - sc.cash_rank)   * 0.2 +
    (6 - sc.safety_rank) * 0.2, 2) AS composite_score
FROM scored sc
JOIN companies c ON c.ticker = sc.ticker
ORDER BY composite_score DESC;
