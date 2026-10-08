# TikTok — contexto del dominio

## Dónde vive en el repo nexus (solo lectura)
- Ingestas: `airflow/dags/nexus_dags/event_nexus-tiktok_*.py` (~30 DAGs).
  Los reportes de afiliados existen en variantes `_alpha` y `_luna`.
- DAGs legacy relevantes:
  - `airflow/dags/DAG_sync_tiktok_s3_sharepoint.py` → copia S3 → SharePoint (flat files "TT Data")
  - `airflow/dags/DAG_tiktok_sharepoint_daily_check.py`
  - `airflow/dags/DAG_tiktok_pbi_spend_daily_export.py`
  - `airflow/dags/DAG_nex_dwh_tiktok_measures.py`, `DAG_nex_dwh_tiktok_commissions.py`
- dbt: `dwh/models/{staging,intermediate,marts}/tiktok/`
  (`stg_legacy_tiktok__main_measures_daily`, `int_legacy_tiktok_measures_daily__filtered`,
  `fct_legacy_tiktok_measures_daily`, `agg_legacy_tiktok_video_measures_monthly`)

## Power BI (modelo TT / PBI TT V8)
- Hoy lee flat files de SharePoint: `GOJA M&A - BI TT Model/TT Data`.
- Llave de órdenes: **Primary ID = Order ID + SKU ID** (no Order ID solo; hay órdenes multi-SKU).
- Order ID y SKU ID crudos pueden traer **tabs ocultos** → limpiar antes de concatenar o hacer joins
  (ver `knowledge/hallazgos/tiktok_ids_con_tab.md`).

## Proyecto en curso: TikTok files → tablas
Objetivo: reemplazar los flat files por tablas en BD + transformaciones dbt, para acelerar el refresh de PBI.
Plan acordado:
1. Revisar qué existe en marts y ajustar el reporte TikTok a eso.
2. Revisar flat files y mejorar su rendimiento.
3. Revisar conexiones (como Golden Model) y pasar a Power BI API.
4. Pedir que tablas en BD que no están en marts se lleven a marts; repetir.
5. Re-analizar rendimiento del dashboard; luego las 8 conexiones flat-file restantes.

Restricción: en el datapool dev Ivan solo es dueño del esquema `pbireport`.
