-- =============================================================
-- 分析模块 03：费用结构与经营杠杆
-- 业务问题：
--   1) 各家的钱花在哪：销售、管理还是研发？
--   2) 经营杠杆：收入增长时，利润是否增长得更快？（费用率是否随规模摊薄）
--   3) 美团 2025 年转亏，是收入问题还是费用问题？（归因拆解）
-- SQL 技能点：NULL 的显式处理、窗口函数差分、命名窗口、归因分析
-- =============================================================

USE internet_finance;

-- 3.1 费用率三件套（销售 / 管理 / 研发占收入比）
-- 注意：腾讯 rd_expense 为 NULL（该数据源未单独披露），
--       绝不能用 0 填充——0 和"未披露"是完全不同的业务含义。
SELECT
  c.company_name,
  i.fiscal_year,
  ROUND(i.selling_expense / NULLIF(i.revenue, 0) * 100, 1) AS selling_ratio_pct,
  ROUND(i.admin_expense   / NULLIF(i.revenue, 0) * 100, 1) AS admin_ratio_pct,
  ROUND(i.rd_expense      / NULLIF(i.revenue, 0) * 100, 1) AS rd_ratio_pct   -- 腾讯为 NULL
FROM income_statement i
JOIN companies c ON c.ticker = i.ticker
ORDER BY c.company_name, i.fiscal_year;

-- 3.2 经营杠杆检验：收入增速 vs 经营利润增速
-- 陷阱提示：上期经营利润为负时，百分比增速会失去意义（分母为负，方向反转）。
--           因此先用 CASE 显式识别"扭亏/转亏"，仅在同号年份比较增速。
WITH growth AS (
  SELECT
    ticker,
    fiscal_year,
    revenue,
    operating_profit,
    LAG(revenue) OVER w          AS prev_revenue,
    LAG(operating_profit) OVER w AS prev_op
  FROM income_statement
  WINDOW w AS (PARTITION BY ticker ORDER BY fiscal_year)
)
SELECT
  c.company_name,
  g.fiscal_year,
  ROUND((g.revenue / g.prev_revenue - 1) * 100, 1) AS rev_yoy_pct,
  CASE
    WHEN g.prev_op < 0 AND g.operating_profit > 0 THEN '扭亏为盈'
    WHEN g.prev_op > 0 AND g.operating_profit < 0 THEN '由盈转亏'
    ELSE ROUND((g.operating_profit / NULLIF(g.prev_op, 0) - 1) * 100, 1)
  END AS op_profit_yoy_pct,
  CASE
    WHEN g.prev_op < 0 OR g.operating_profit < 0 THEN '——（跨零年份不比较增速）'
    WHEN (g.operating_profit / g.prev_op - 1) > (g.revenue / g.prev_revenue - 1)
      THEN '杠杆为正（利润弹性>收入弹性）'
    ELSE '杠杆为负'
  END AS operating_leverage
FROM growth g
JOIN companies c ON c.ticker = g.ticker
WHERE g.fiscal_year > 2021
ORDER BY c.company_name, g.fiscal_year;

-- 3.3 案例拆解：美团 2025 年净利润变动的归因（收入 / 毛利率 / 费用率三因素）
WITH meituan AS (
  SELECT
    fiscal_year,
    revenue,
    gross_profit / revenue AS gm,
    (selling_expense + admin_expense + COALESCE(rd_expense, 0)) / revenue AS expense_ratio,
    net_profit_attributable / revenue AS nm
  FROM income_statement
  WHERE ticker = '3690.HK' AND fiscal_year IN (2024, 2025)
),
pivoted AS (
  SELECT
    MAX(CASE WHEN fiscal_year = 2024 THEN revenue END)        AS rev_24,
    MAX(CASE WHEN fiscal_year = 2025 THEN revenue END)        AS rev_25,
    MAX(CASE WHEN fiscal_year = 2024 THEN gm END)             AS gm_24,
    MAX(CASE WHEN fiscal_year = 2025 THEN gm END)             AS gm_25,
    MAX(CASE WHEN fiscal_year = 2024 THEN expense_ratio END)  AS er_24,
    MAX(CASE WHEN fiscal_year = 2025 THEN expense_ratio END)  AS er_25
  FROM meituan
)
SELECT
  ROUND((rev_25 - rev_24) / 1e8, 1)                 AS revenue_change_yi,
  ROUND((gm_25 - gm_24) * 100, 1)                   AS gross_margin_change_pp,
  ROUND((er_25 - er_24) * 100, 1)                   AS expense_ratio_change_pp,
  ROUND((gm_25 - gm_24) * rev_25 / 1e8, 1)          AS gross_margin_effect_yi,
  ROUND(-(er_25 - er_24) * rev_25 / 1e8, 1)         AS expense_ratio_effect_yi
FROM pivoted;