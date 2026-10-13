"""
Proposito : Espejo local del DAG que exporta el Golden Model a analytics.gm_main_metrics_by_day_v2
Autor     : Ivan Laruta
Actualizado: 2026-10-12 (v2.5, sin inventario - NEX-3212)
Proceso   : knowledge/procesos/golden_model_limpieza_inventario_gm_main_metrics.md

Carga LOCAL del Golden Model OLAP -> Postgres via Power BI REST API (executeQueries).
Version v2.5 del Nexus Bridge -> tabla analytics.gm_main_metrics_by_day_v2.

v2.5 (NEX-3212 / NEX-3183): se eliminan las 10 metricas de inventario
(stock FBA/AWD/3PL + pipeline de PO). Ya no se extraen ni se escriben.

Espejo local del DAG pbi_premium_gm_db_main_metrics_by_day_v2.py:
solo necesita 'requests' (Python puro), sin ADOMD.NET ni pythonnet.
SIN filtro de Brand (universo completo, igual que el DAG v2 actual).
El REST tiene limites (100k filas / 1M valores / 15MB / 120s por consulta).
Con 47 columnas por fila, CHUNK_DAYS=15 queda bajo el limite de 1M valores.
Pon CHUNK_DAYS=None para chunks por mes (solo seguro para rangos chicos).
DELETE + INSERT en UNA sola transaccion (atomico, todo-o-nada).

Uso:
    python gm_main_metrics_v2_carga_local.py     # edita START_DATE / END_DATE abajo

Requisitos: pip install requests pandas sqlalchemy psycopg2-binary python-dotenv
.env: PBI_TENANT_ID, PBI_CLIENT_ID, PBI_CLIENT_SECRET, PG_USER, PG_PASSWORD, PG_HOST, PG_PORT, PG_DB
"""
import os
import sys
import json
from datetime import date, timedelta, datetime, timezone

import requests
import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL

load_dotenv()

# ============================================================
# POWER BI REST API  (credenciales SOLO desde .env)
# ============================================================
TENANT_ID     = os.environ["PBI_TENANT_ID"]
CLIENT_ID     = os.environ["PBI_CLIENT_ID"]
CLIENT_SECRET = os.environ["PBI_CLIENT_SECRET"]
GROUP_ID   = "1cea0d33-9c88-4f47-b193-a78037aa8942"  # Analytics
DATASET_ID = "b8f20090-2449-483a-a881-01ca0116e583"  # Golden Model

PBI_URL = (
    f"https://api.powerbi.com/v1.0/myorg/groups/{GROUP_ID}"
    f"/datasets/{DATASET_ID}/executeQueries"
)

def get_pbi_token() -> str:
    resp = requests.post(
        f"https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/token",
        data={
            "grant_type":    "client_credentials",
            "client_id":     CLIENT_ID,
            "client_secret": CLIENT_SECRET,
            "scope":         "https://analysis.windows.net/powerbi/api/.default",
        },
        timeout=30,
    )
    resp.raise_for_status()
    return resp.json()["access_token"]

# ============================================================
# POSTGRES
# ============================================================
engine = create_engine(URL.create(
    "postgresql+psycopg2",
    username=os.environ["PG_USER"],
    password=os.environ["PG_PASSWORD"],
    host=os.environ["PG_HOST"],
    port=int(os.environ["PG_PORT"]),
    database=os.environ["PG_DB"],
))
SCHEMA, TABLE = "analytics", "gm_main_metrics_by_day_v2"

# ============================================================
# RANGO / CHUNKS
# ============================================================
START_DATE = date(2026, 10, 1)
END_DATE   = date(2026, 10, 31)

# None = chunks por mes; N = ventanas de N dias.
CHUNK_DAYS = 15

if START_DATE > END_DATE:
    raise ValueError(f"START_DATE ({START_DATE}) > END_DATE ({END_DATE})")

min_sid = int(START_DATE.strftime("%Y%m%d"))
max_sid = int(END_DATE.strftime("%Y%m%d"))

# ============================================================
# QA: marketplaces aceptados por el guard dbt (accepted_values)
# nexus/dwh/models/staging/legacy_gm/_legacy_gm_models.yml
# stg_legacy_gm__main_metrics_by_day_v2 -> columna marketplace
# Si el yml cambia, actualizar este set tambien (NEX-2602).
# ============================================================
ACCEPTED_MARKETPLACES = {
    "Amazon CA", "Amazon DE", "Amazon ES", "Amazon FR", "Amazon IT",
    "Amazon MX", "Amazon SE", "Amazon UK", "Amazon US",
    "Shopify", "Wholesale",
}

# ============================================================
# RENAME MAP (v2.5)  -- columna export DAX -> columna Postgres
# ============================================================
RENAME_MAP = {
    "Date_Sid":                            "date_sid",
    "Product ID":                          "product_sid",
    "Marketplace":                         "marketplace",
    "ASIN":                                "asin",
    "Actual Sales":                        "actual_sales",
    "Actual Sales after Discounts":        "actual_sales_after_discounts",
    "Actual Quantity":                     "actual_quantity",
    "Actual CM":                           "actual_cm",
    "Amz CM":                              "amz_cm",
    "Shopify CM":                          "shopify_cm",
    "Actual AGP":                          "actual_agp",
    "COGS":                                "cogs",
    "FBA Fee":                             "fba_fee",
    "Referral Fee":                        "referral_fee",
    "PPC Spend":                           "ppc_spend",
    "Amz Total Spend":                     "amz_total_spend",
    "TikTok Total Spend":                  "tiktok_spend",
    "Total Marketing Spend":               "total_marketing_spend",
    "Total Marketing Attributed Sales":    "total_marketing_attributed_sales",
    "PPC Direct AGP":                      "ppc_direct_agp",
    "PPC Attributed Orders":               "ppc_attributed_orders",
    "PPC Attributed Orders Direct":        "ppc_attributed_orders_direct",
    "PPC Attributed Sales":                "ppc_attributed_sales",
    "PPC Clicks":                          "ppc_clicks",
    "PPC Impressions":                     "ppc_impressions",
    "Total Sessions":                      "total_sessions",
    "Organic Sessions":                    "organic_sessions",
    "Total Order Items":                   "total_order_items",
    "Organic Orders":                      "organic_orders",
    "Organic Sales":                       "organic_sales",
    "Amazon Affiliates Quantity":          "amazon_affiliates_quantity",
    "Amazon Affiliates Sales":             "amazon_affiliates_sales",
    "Amazon Affiliates Clicks":            "amazon_affiliates_clicks",
    "Amazon Affiliates Page Views":        "amazon_affiliates_page_views",
    "Quantity Amazon GOJAffiliates":       "quantity_amazon_gojaffiliates",
    "Sales Amazon GOJAffiliates":          "sales_amazon_gojaffiliates",
    "Amazon Affiliates Commission":        "amazon_affiliates_commission",
    "Amz Aff. CM":                         "amz_aff_cm",
    "TikTok Sales":                        "tiktok_sales",
    "TikTok Quantity":                     "tiktok_quantity",
    "TikTok + Shopify Quantity":           "tiktok_plus_shopify_quantity",
    "TikTok AGP":                          "tiktok_agp",
    "TikTok CM":                           "tiktok_cm",
    "Sales Forecast":                      "sales_forecast",
    "Quantity Forecast":                   "quantity_forecast",
    "CM Forecast":                         "cm_forecast",
    "PPC Spend Forecast":                  "ppc_spend_forecast",
}

# ============================================================
# DAX BUILDER (v2.5 - solo bases, sin inventario; SIN filtro de Brand)
# ============================================================
def build_dax(d_from: date, d_to: date) -> str:
    return f"""
EVALUATE
SUMMARIZECOLUMNS(
    Dim_Date[Date_Sid],
    Dim_Products[Product ID],
    Dim_Products[Marketplace],
    Dim_Products[ASIN],
    FILTER(
        Dim_Date,
        Dim_Date[Date] >= DATE({d_from.year},{d_from.month},{d_from.day}) &&
        Dim_Date[Date] <= DATE({d_to.year},{d_to.month},{d_to.day})
    ),
    "Actual Sales",                        [Actual Sales],
    "Actual Sales after Discounts",        [Actual Sales After Discounts],
    "Actual Quantity",                     [Actual Quantity],
    "Actual CM",                           [Actual CM],
    "Amz CM",                              [Amz CM],
    "Shopify CM",                          [Shopify CM],
    "Actual AGP",                          [Actual AGP],
    "COGS",                                [COGS],
    "FBA Fee",                             [FBA Fee],
    "Referral Fee",                        [Referral Fee],
    "PPC Spend",                           [PPC Spend],
    "Amz Total Spend",                     [Amz Total Spend],
    "TikTok Total Spend",                  [TikTok Total Spend],
    "Total Marketing Spend",               [Total Marketing Spend],
    "Total Marketing Attributed Sales",    [Total Marketing Attributed Sales],
    "PPC Direct AGP",                      [PPC Direct AGP],
    "PPC Attributed Orders",               [PPC Attributed Orders],
    "PPC Attributed Orders Direct",        [PPC Attributed Orders Direct],
    "PPC Attributed Sales",                [PPC Attributed Sales],
    "PPC Clicks",                          [PPC Clicks],
    "PPC Impressions",                     [Impressions],
    "Total Sessions",                      [Total Sessions],
    "Organic Sessions",                    [Organic Sessions],
    "Total Order Items",                   [Total Order Items],
    "Organic Orders",                      [Organic Orders],
    "Organic Sales",                       [Organic Sales],
    "Amazon Affiliates Quantity",          [Amazon Affiliates Quantity],
    "Amazon Affiliates Sales",             [Amazon Affiliates Sales],
    "Amazon Affiliates Clicks",            [Amazon Affiliates Clicks],
    "Amazon Affiliates Page Views",        [Amazon Affiliates Page Views],
    "Quantity Amazon GOJAffiliates",       [GOJA Affiliates Quantity],
    "Sales Amazon GOJAffiliates",          [GOJA Affiliates Sales],
    "Amazon Affiliates Commission",        [Amazon Affiliates Commission],
    "Amz Aff. CM",                         [Amazon Affiliates CM],
    "TikTok Sales",                        [TikTok Sales],
    "TikTok Quantity",                     [TikTok Quantity],
    "TikTok + Shopify Quantity",           [TikTok + Shopify Quantity],
    "TikTok AGP",                          [TikTok AGP],
    "TikTok CM",                           [TikTok CM],
    "Sales Forecast",                      [Sales Forecast],
    "Quantity Forecast",                   [Quantity Forecast],
    "CM Forecast",                         [CM Forecast],
    "PPC Spend Forecast",                  [PPC Spend Forecast]
)
"""

def next_month(d: date) -> date:
    return date(d.year + (d.month == 12), (d.month % 12) + 1, 1)

def iter_chunks(start_date: date, end_date: date, chunk_days):
    """Yield (chunk_start, chunk_end). chunk_days=None -> meses; N -> N dias."""
    if chunk_days is None:
        cur = date(start_date.year, start_date.month, 1)
        while cur <= end_date:
            yield max(cur, start_date), min(next_month(cur) - timedelta(days=1), end_date)
            cur = next_month(cur)
    else:
        cur = start_date
        while cur <= end_date:
            yield cur, min(cur + timedelta(days=chunk_days - 1), end_date)
            cur = cur + timedelta(days=chunk_days)

# ============================================================
# REST API QUERY HELPER
# ============================================================
def run_dax(dax: str, headers: dict) -> pd.DataFrame:
    resp = requests.post(
        PBI_URL,
        headers=headers,
        data=json.dumps({
            "queries": [{"query": dax}],
            "serializerSettings": {"includeNulls": True},
        }),
        timeout=600,
    )
    resp.raise_for_status()
    rows = resp.json()["results"][0]["tables"][0]["rows"]
    return pd.DataFrame(rows)

# ============================================================
# MAIN
# ============================================================
print(f"Rango: {START_DATE} -> {END_DATE}  |  date_sid {min_sid} -> {max_sid}")
print(f"REST: group {GROUP_ID}  |  dataset {DATASET_ID}  |  Tabla: {SCHEMA}.{TABLE}")

token = get_pbi_token()
headers = {
    "Authorization":   f"Bearer {token}",
    "Content-Type":    "application/json",
    "Accept-Encoding": "identity",
}

# 1) Chunks
chunk_mode = "mensual" if CHUNK_DAYS is None else f"{CHUNK_DAYS} dias"
print(f"Chunk mode: {chunk_mode}")
dfs = []
t_extract = datetime.now(timezone.utc)
for chunk_start, chunk_end in iter_chunks(START_DATE, END_DATE, CHUNK_DAYS):
    print(f"  {chunk_start} -> {chunk_end} ... ", end="", flush=True)
    t0 = datetime.now(timezone.utc)
    chunk_df = run_dax(build_dax(chunk_start, chunk_end), headers)
    secs = (datetime.now(timezone.utc) - t0).total_seconds()
    print(f"{len(chunk_df)} filas  |  {secs:.1f}s")
    if not chunk_df.empty:
        dfs.append(chunk_df)

df = pd.concat(dfs, ignore_index=True) if dfs else pd.DataFrame()
extract_secs = (datetime.now(timezone.utc) - t_extract).total_seconds()
print(f"Total filas (raw): {len(df)}  |  Tiempo total extraccion (PBI): {extract_secs:.1f}s")

if df.empty:
    print("Sin filas. Nada que escribir.")
    sys.exit(0)

# 2) Limpiar nombres de columnas
df.columns = df.columns.str.replace(r".*\[|\]", "", regex=True).str.strip()

# 2b) Sanity check de columnas
returned   = set(df.columns)
expected   = set(RENAME_MAP.keys())
missing    = expected - returned
unexpected = returned - expected
if missing:
    print(f"  [WARN] columnas esperadas que NO llegaron: {sorted(missing)}")
if unexpected:
    print(f"  [WARN] columnas devueltas SIN mapear: {sorted(unexpected)}")

# 3) Quitar filas con todas las metricas en NULL/0
#    Nota v2.5: filas que antes solo tenian inventario ahora se descartan (esperado).
id_cols     = ["Date_Sid", "Product ID", "Marketplace", "ASIN"]
metric_cols = [c for c in df.columns if c not in id_cols]
df[metric_cols] = df[metric_cols].apply(pd.to_numeric, errors="coerce")
df = df.loc[~(
    df[metric_cols].isna().all(axis=1) |
    df[metric_cols].fillna(0).eq(0).all(axis=1)
)].copy()

# 4) Rename + tipados
df = df.rename(columns=RENAME_MAP)
df["product_sid"] = pd.to_numeric(df["product_sid"], errors="coerce").astype("Int64")

# 4b) Hot-fix: descartar filas invalidas (product_sid 0/NULL, marketplace fuera del guard dbt)
before = len(df)
df = df[df["product_sid"].notna() & (df["product_sid"] != 0)]

marketplace_clean = df["marketplace"].fillna("").astype(str).str.strip()
valid_marketplace = marketplace_clean.eq("") | marketplace_clean.isin(ACCEPTED_MARKETPLACES)
dropped_marketplaces = marketplace_clean[~valid_marketplace].value_counts()
df = df[valid_marketplace]

print(f"Filtro product_sid/marketplace: {before} -> {len(df)} filas")
if not dropped_marketplaces.empty:
    print("  Marketplaces descartados (fuera del guard dbt):")
    for mkt, cnt in dropped_marketplaces.items():
        print(f"    - {mkt!r}: {cnt} filas")

df["last_update_date"] = datetime.now(timezone.utc)
print(f"Total filas (filtradas): {len(df)}")

# 5) Idempotente y ATOMICO: DELETE + INSERT en UNA sola transaccion.
with engine.begin() as conn:
    conn.execute(
        text(f"DELETE FROM {SCHEMA}.{TABLE} WHERE date_sid BETWEEN :a AND :b"),
        {"a": min_sid, "b": max_sid},
    )
    df.to_sql(TABLE, con=conn, schema=SCHEMA, if_exists="append",
              index=False, method="multi", chunksize=5000)

print(f"OK. Carga completa v2.5 (sin inventario). date_sid {min_sid} -> {max_sid}  |  {len(df)} filas insertadas.")
