# Golden Model — contexto del dominio

## Qué es
Modelo semántico de Power BI (workspace Analytics, dataset `b8f20090-2449-483a-a881-01ca0116e583`).
Sus métricas diarias se exportan a Postgres para Nexus Bridge.

## Export a Postgres
- Tabla: `analytics.gm_main_metrics_by_day_v2` (grano: date_sid × product_sid × marketplace × asin).
- DAG (nexus, solo lectura): `pbi_premium_gm_db_main_metrics_by_day_v2.py` → Power BI REST `executeQueries`.
- Espejo local: `gm_main_metrics_v2_carga_local.py` (credenciales en `.env`, nunca en el código).
- dbt: `stg_legacy_gm__main_metrics_by_day_v2`; su guard `accepted_values` de marketplace debe coincidir
  con `ACCEPTED_MARKETPLACES` del script (NEX-2602).
- Desde v2.5 (2026-10) **no** lleva columnas de inventario
  (ver `knowledge/procesos/golden_model_limpieza_inventario_gm_main_metrics.md`).

## Límites del REST de Power BI
100k filas / 1M valores / 15 MB / 120 s por consulta → extraer en chunks de días.
