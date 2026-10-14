-- =============================================================
-- 分析模块 05：现金流质量分析
-- 业务问题：
--   1) 利润是"纸面富贵"还是真收到了钱？（CFO / 净利润）
--   2) 谁具备自我造血能力（自由现金流持续为正）？
--   3) 股权激励（SBC）对利润的侵蚀有多大？——互联网公司特有议题
-- SQL 技能点：跨表 JOIN、比率指标、符号判断 CASE、聚合稳健性（避免除以负数误读）
-- =============================================================

USE internet_finance;

-- 5.1 净现比（CFO / 净利润）：>1 说明利润含金量高
-- 注意：净利润为负时该比率方向会反，需结合符号判断，不能只看数值
SELECT
  c.company_name,
  i.fiscal_year,
  ROUND(i.net_profit_attributable / 1e8, 1) AS net_profit_yi,
  ROUND(f.cfo / 1e8, 1)                     AS cfo_yi,
  ROUND(f.cfo / NULLIF(i.net_profit_attributable, 0), 2) AS cfo_to_np,
  CASE
    WHEN i.net_profit_attributable > 0 AND f.cfo / NULLIF(i.net_profit_attributable, 0) >= 1 THEN '利润含金量高'
    WHEN i.net_profit_attributable > 0 THEN '利润含金量偏低'
    WHEN f.cfo > 0 THEN '账面亏损但经营仍造血'
    ELSE '亏损且失血'
  END AS cash_quality
FROM income_statement i
JOIN cash_flow f ON f.ticker = i.ticker AND f.fiscal_year = i.fiscal_year
JOIN companies c ON c.ticker = i.ticker
ORDER BY c.company_name, i.fiscal_year;

-- 5.2 自由现金流五年趋势：自我造血能力
SELECT
  c.company_name,
  f.fiscal_year,
  ROUND(f.cfo / 1e8, 1)   AS cfo_yi,
  ROUND(f.capex / 1e8, 1) AS capex_yi,
  ROUND(f.fcf / 1e8, 1)   AS fcf_yi,
  ROUND(f.fcf / NULLIF(i.revenue, 0) * 100, 1) AS fcf_margin_pct
FROM cash_flow f
JOIN income_statement i ON i.ticker = f.ticker AND i.fiscal_year = f.fiscal_year
JOIN companies c ON c.ticker = f.ticker
ORDER BY c.company_name, f.fiscal_year;

-- 5.3 股权激励侵蚀度：SBC 占净利润 / 占 CFO 比重（互联网公司"隐形费用"）
SELECT
  c.company_name,
  f.fiscal_year,
  ROUND(f.stock_based_comp / 1e8, 1) AS sbc_yi,
  ROUND(f.stock_based_comp / NULLIF(i.net_profit_attributable, 0) * 100, 1) AS sbc_to_np_pct,
  ROUND(f.stock_based_comp / NULLIF(f.cfo, 0) * 100, 1) AS sbc_to_cfo_pct
FROM cash_flow f
JOIN income_statement i ON i.ticker = f.ticker AND i.fiscal_year = f.fiscal_year
JOIN companies c ON c.ticker = f.ticker
ORDER BY c.company_name, f.fiscal_year;
