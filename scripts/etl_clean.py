# -*- coding: utf-8 -*-
"""
etl_clean.py — 数据清洗与整合脚本
将 data/raw 下的 iFinD 原始导出 CSV 整合为 data/clean 下的 5 张分析就绪表。
运行方式：python3 scripts/etl_clean.py
"""
import os
import pandas as pd

BASE = os.path.join(os.path.dirname(__file__), "..")
RAW = os.path.join(BASE, "data", "raw")
OUT = os.path.join(BASE, "data", "clean")
os.makedirs(OUT, exist_ok=True)

COMPANY_MAP = {
    "0700.HK": "腾讯控股", "3690.HK": "美团", "1024.HK": "快手",
    "9626.HK": "哔哩哔哩", "9999.HK": "网易",
}
YEARS = range(2021, 2026)


def load_statement(stmt: str) -> pd.DataFrame:
    """合并两个批次、五个年份的同类型报表。"""
    frames = []
    for y in YEARS:
        for b in ["b1", "b2"]:
            df = pd.read_csv(f"{RAW}/statements/{stmt}_{b}_{y}.csv")
            df["fiscal_year"] = y
            frames.append(df)
    df = pd.concat(frames, ignore_index=True)
    df["company_name"] = df["thscode"].map(COMPANY_MAP)
    return df


def build_income() -> pd.DataFrame:
    d = load_statement("is")
    cols = {
        "thscode": "ticker", "revenue_oas": "revenue", "cost_of_revenue_oas": "cost_of_revenue",
        "gross_profit_oas": "gross_profit", "selling_marketing_expenses_oas": "selling_expense",
        "ga_expenses_oas": "admin_expense", "rd_expenses_oas": "rd_expense",
        "operating_income_oas": "operating_profit", "pretax_income_from_continu_op_oas": "pretax_profit",
        "income_tax_expense_oas": "income_tax", "net_income_oas": "net_profit",
        "net_income_attri_to_owners_oas": "net_profit_attributable",
    }
    out = d.rename(columns=cols)[["ticker", "company_name", "fiscal_year", *cols.values()][1:]]
    return out.sort_values(["ticker", "fiscal_year"])


def build_balance() -> pd.DataFrame:
    d = load_statement("bs")
    cols = {
        "thscode": "ticker", "total_assets_oas": "total_assets", "total_liabilities_oas": "total_liabilities",
        "total_equity_oas": "total_equity", "total_current_asset_oas": "current_assets",
        "total_current_liabilities_oas": "current_liabilities", "cash_equi_short_term_inve_oas": "cash_and_short_invest",
        "accou_recei_net_oas": "accounts_receivable", "inventories_oas": "inventory",
        "goodwill_oas": "goodwill", "intangible_assets_oas": "intangible_assets",
        "defer_revenue_current_oas": "deferred_revenue_current",
    }
    out = d.rename(columns=cols)[["ticker", "company_name", "fiscal_year", *cols.values()][1:]]
    return out.sort_values(["ticker", "fiscal_year"])


def build_cashflow() -> pd.DataFrame:
    d = load_statement("cf")
    cols = {
        "thscode": "ticker", "net_cash_flows_from_oa_oas": "cfo", "net_cash_flows_from_ia_oas": "cfi",
        "net_cash_flows_from_fa_oas": "cff", "purchase_of_ppe_and_ia_oas": "capex",
        "depre_and_amortiza_oas": "depreciation_amortization", "stock_based_compensation_oas": "stock_based_comp",
    }
    out = d.rename(columns=cols)[["ticker", "company_name", "fiscal_year", *cols.values()][1:]]
    out["fcf"] = out["cfo"] - out["capex"]
    return out.sort_values(["ticker", "fiscal_year"])


def build_segmentation() -> pd.DataFrame:
    frames = []
    for y in [2023, 2024, 2025]:
        for b in ["b1", "b2"]:
            df = pd.read_csv(f"{RAW}/segmentation/seg_{b}_{y}.csv")
            df["fiscal_year"] = y
            frames.append(df)
    d = pd.concat(frames, ignore_index=True)
    out = d.rename(columns={
        "thscode": "ticker", "project_name_oic_bussiness": "segment_name",
        "project_income_oic_bussiness": "segment_revenue", "project_grpf_oic_bussiness": "segment_gross_profit",
    })[["ticker", "fiscal_year", "segment_name", "segment_revenue", "segment_gross_profit"]]
    out = out.dropna(subset=["segment_name"])
    out["company_name"] = out["ticker"].map(COMPANY_MAP)
    return out.sort_values(["ticker", "fiscal_year", "segment_revenue"], ascending=[True, True, False])


if __name__ == "__main__":
    build_income().to_csv(f"{OUT}/income_statement.csv", index=False)
    build_balance().to_csv(f"{OUT}/balance_sheet.csv", index=False)
    build_cashflow().to_csv(f"{OUT}/cash_flow.csv", index=False)
    build_segmentation().to_csv(f"{OUT}/business_segmentation.csv", index=False)
    print("ETL 完成，输出至 data/clean/")
