# Proceso: Quitar inventario de `analytics.gm_main_metrics_by_day_v2`

**Dominio:** golden-model · **Tickets:** NEX-3212 (tabla), DAG `gm_main_metrics_by_day_v2_daily`, NEX-3183 (Golden Model) · **Estado:** en ejecución · **Última actualización:** 2026-10-12

## Objetivo
Dejar de extraer y guardar las 10 métricas de inventario (stock FBA/AWD/3PL + pipeline de PO) en la tabla
que alimenta Nexus Bridge desde el Golden Model. El inventario ya no se consume desde aquí.
Columnas listadas por Angel; Bridge dio el visto bueno el 2026-10-12.

## Alcance

### Columnas eliminadas (10)
| # | Columna Postgres | Medida DAX en Golden Model |
|---|---|---|
| 1 | `total_fba_inventory` | `[Total FBA (U)]` |
| 2 | `available_fba` | `[Available FBA]` |
| 3 | `inbound_fba` | `[Inbound FBA]` |
| 4 | `awd_3pl_available_fba` | `[3PL Available AWD (FBA)]` |
| 5 | `raw_material_3pl` | `[3PL Raw Material]` |
| 6 | `finished_good_3pl` | `[3PL Finished Good]` |
| 7 | `po_in_transit_fba_agl` | `[PO in Transit FBA (AGL)]` |
| 8 | `po_in_transit_upstream_raw_material` | `[PO in Transit Upstream Raw Material]` |
| 9 | `po_in_transit_3pl_raw_material` | `[PO in Transit 3PL Raw Material]` |
| 10 | `po_in_production_raw_material` | `[PO in Production Raw Material]` |

### Objetos afectados
- Tabla: `analytics.gm_main_metrics_by_day_v2`
- DAG: `pbi_premium_gm_db_main_metrics_by_day_v2.py` (repo nexus; en inglés)
- Carga local espejo: `golden-model/gm_main_metrics_v2_carga_local.py` (v2.5)
- dbt: `stg_legacy_gm__main_metrics_by_day_v2` (`dwh/models/staging/legacy_gm/`), revisar si selecciona las columnas
- Golden Model (Power BI): medidas de inventario → NEX-3183

### Flujo actual (según el script de carga)
Golden Model (dataset `b8f20090-…`, workspace Analytics) → Power BI REST `executeQueries` (DAX `SUMMARIZECOLUMNS`
por Date_Sid × Product ID × Marketplace × ASIN, chunks de 15 días) → DELETE + INSERT por rango de `date_sid`
→ `analytics.gm_main_metrics_by_day_v2` → dbt `stg_legacy_gm__main_metrics_by_day_v2` → Nexus Bridge.

## Dependencias / aprobaciones
- [x] Bridge confirma que no consume las columnas de inventario (2026-10-12)
- [ ] Release del DAG coordinado con el equipo (no se mergea a prod hasta el release)

## Pasos (en orden)
> Orden importante: si la tabla pierde las columnas y el DAG viejo corre, el INSERT falla
> (sigue enviando las 10 columnas). Por eso el DAG va **pausado** entre el DROP y el deploy.

| # | Paso | Dónde | Hecho |
|---|---|---|---|
| 1 | Pausar `pbi_premium_gm_db_main_metrics_by_day_v2` | Airflow | [ ] |
| 2 | Pre-checks: columnas, vistas dependientes, conteo de referencia (pegar en ticket) | `gm_main_metrics_v2_limpieza_inventario.sql` paso 1 | [ ] |
| 3 | Backup → `analytics.gm_main_metrics_by_day_v2_inv_bkp_20261012` | idem, paso 2 | [ ] |
| 4 | `ALTER TABLE … DROP COLUMN` (10), con `lock_timeout` 10s | idem, paso 3 | [ ] |
| 5 | Post-checks: 0 columnas de inventario, conteo/min/max igual al paso 2 | idem, paso 4 | [ ] |
| 6 | Desplegar DAG sin inventario (quitar 10 entradas de `RENAME_MAP` y del DAX) | nexus / Airflow | [ ] |
| 7 | Reanudar DAG y validar la primera corrida | Airflow + BD | [ ] |
| 8 | Ajustar dbt staging si referencia las columnas | nexus `dwh/models/staging/legacy_gm/` | [ ] |
| 9 | Limpiar medidas de inventario del Golden Model | NEX-3183 | [ ] |
| 10 | Borrar el backup (~2026-11-12) si no hubo incidentes | BD | [ ] |

## Validación
- Post-check 4a = 0 filas; 4b igual al pre-check 1c.
- Primera corrida del DAG nuevo sin error de columnas; warning `columnas esperadas que NO llegaron` vacío.
- **Esperado:** la carga trae **menos filas** que antes. El filtro "todas las métricas en 0/NULL" ahora
  descarta las filas ASIN/día que solo tenían inventario (sin ventas, spend ni forecast). Anotar la diferencia en el ticket.

## Rollback
1. Recrear las 10 columnas (bloque ROLLBACK del `.sql`, usando los `data_type` del pre-check 1a).
2. `UPDATE` desde `analytics.gm_main_metrics_by_day_v2_inv_bkp_20261012` por `date_sid, product_sid, marketplace, asin`.
3. Volver a desplegar la versión v2.4 del DAG.

## Cuidado con
- `DROP COLUMN` no libera espacio en disco; `VACUUM FULL` sí, pero bloquea la tabla → solo fuera de horario.
- Si el pre-check 1b devuelve vistas, el DROP falla: ajustarlas antes.
- El script de carga tenía el `CLIENT_SECRET` del service principal en texto plano. En v2.5 se lee de `.env`
  (`PBI_TENANT_ID`, `PBI_CLIENT_ID`, `PBI_CLIENT_SECRET`); conviene rotar el secret.
- Desde Claude (conexiones de solo lectura `postgres-prod`, `postgres-dev`, `postgres-dev-datacron`) la tabla
  **no aparece** (2026-10-12). Confirmar en qué conexión/BD vive y anotarlo en `knowledge/conexiones.md`.

## Archivos relacionados
- [`golden-model/gm_main_metrics_v2_limpieza_inventario.sql`](../../golden-model/gm_main_metrics_v2_limpieza_inventario.sql)
- [`golden-model/gm_main_metrics_v2_carga_local.py`](../../golden-model/gm_main_metrics_v2_carga_local.py)

## Bitácora
- 2026-10-01: Angel lista las 10 columnas a limpiar. Se valida que el script v2.4 tiene exactamente esas 10 y ninguna otra de inventario.
- 2026-10-12: Bridge da visto bueno. Se preparan script de limpieza (con backup y rollback) y carga v2.5. Se decide limpiar la tabla primero con el DAG pausado.
