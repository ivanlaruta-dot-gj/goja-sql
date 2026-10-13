-- Propósito : NEX-3212 — eliminar las 10 columnas de inventario de analytics.gm_main_metrics_by_day_v2
-- Fuente    : analytics.gm_main_metrics_by_day_v2
-- Consumidor: Nexus Bridge (stg_legacy_gm__main_metrics_by_day_v2)
-- Autor     : Ivan Laruta
-- Creado    : 2026-10-12
-- Notas     : Aprobado por Bridge. Contiene DDL: se ejecuta MANUALMENTE en DBeaver, por pasos,
--             con un usuario con permisos de ALTER. Proceso completo:
--             knowledge/procesos/golden_model_limpieza_inventario_gm_main_metrics.md
--             ANTES de ejecutar: pausar el DAG pbi_premium_gm_db_main_metrics_by_day_v2.


-- =====================================================================
-- PASO 1: PRE-CHECKS (solo lectura)
-- =====================================================================

-- 1a) Columnas actuales: confirmar las 10 y que no haya otras de inventario
SELECT
    ordinal_position,
    column_name,
    data_type
FROM information_schema.columns
WHERE
    table_schema = 'analytics'
    AND table_name = 'gm_main_metrics_by_day_v2'
ORDER BY ordinal_position;

-- 1b) Vistas que usan estas columnas (si devuelve filas, el DROP falla: ajustarlas primero)
SELECT DISTINCT
    dv.relnamespace::REGNAMESPACE AS view_schema,
    dv.relname AS view_name,
    dv.relkind AS kind,
    a.attname AS column_used
FROM pg_depend AS d
INNER JOIN pg_rewrite AS r ON d.objid = r.oid
INNER JOIN pg_class AS dv ON r.ev_class = dv.oid
INNER JOIN pg_attribute AS a
    ON d.refobjid = a.attrelid AND d.refobjsubid = a.attnum
WHERE
    d.refobjid = 'analytics.gm_main_metrics_by_day_v2'::REGCLASS
    AND dv.oid <> d.refobjid
    AND a.attname IN (
        'total_fba_inventory',
        'available_fba',
        'inbound_fba',
        'awd_3pl_available_fba',
        'raw_material_3pl',
        'finished_good_3pl',
        'po_in_transit_fba_agl',
        'po_in_transit_upstream_raw_material',
        'po_in_transit_3pl_raw_material',
        'po_in_production_raw_material'
    )
ORDER BY 1, 2, 4;

-- 1c) Foto de referencia (copiar el resultado al ticket)
SELECT
    COUNT(*) AS total_rows,
    MIN(date_sid) AS min_date_sid,
    MAX(date_sid) AS max_date_sid,
    COUNT(*) FILTER (
        WHERE COALESCE(total_fba_inventory, 0) <> 0
        OR COALESCE(available_fba, 0) <> 0
        OR COALESCE(inbound_fba, 0) <> 0
        OR COALESCE(awd_3pl_available_fba, 0) <> 0
        OR COALESCE(raw_material_3pl, 0) <> 0
        OR COALESCE(finished_good_3pl, 0) <> 0
        OR COALESCE(po_in_transit_fba_agl, 0) <> 0
        OR COALESCE(po_in_transit_upstream_raw_material, 0) <> 0
        OR COALESCE(po_in_transit_3pl_raw_material, 0) <> 0
        OR COALESCE(po_in_production_raw_material, 0) <> 0
    ) AS rows_with_inventory
FROM analytics.gm_main_metrics_by_day_v2;


-- =====================================================================
-- PASO 2: BACKUP de las columnas de inventario (para rollback; borrar en ~30 días)
-- =====================================================================
CREATE TABLE analytics.gm_main_metrics_by_day_v2_inv_bkp_20261012 AS
SELECT
    date_sid,
    product_sid,
    marketplace,
    asin,
    total_fba_inventory,
    available_fba,
    inbound_fba,
    awd_3pl_available_fba,
    raw_material_3pl,
    finished_good_3pl,
    po_in_transit_fba_agl,
    po_in_transit_upstream_raw_material,
    po_in_transit_3pl_raw_material,
    po_in_production_raw_material
FROM analytics.gm_main_metrics_by_day_v2
WHERE
    COALESCE(total_fba_inventory, 0) <> 0
    OR COALESCE(available_fba, 0) <> 0
    OR COALESCE(inbound_fba, 0) <> 0
    OR COALESCE(awd_3pl_available_fba, 0) <> 0
    OR COALESCE(raw_material_3pl, 0) <> 0
    OR COALESCE(finished_good_3pl, 0) <> 0
    OR COALESCE(po_in_transit_fba_agl, 0) <> 0
    OR COALESCE(po_in_transit_upstream_raw_material, 0) <> 0
    OR COALESCE(po_in_transit_3pl_raw_material, 0) <> 0
    OR COALESCE(po_in_production_raw_material, 0) <> 0;

-- Debe coincidir con rows_with_inventory del paso 1c
SELECT COUNT(*) AS bkp_rows
FROM analytics.gm_main_metrics_by_day_v2_inv_bkp_20261012;


-- =====================================================================
-- PASO 3: DROP (transaccional; solo metadata, no reescribe la tabla)
-- =====================================================================
BEGIN;

SET LOCAL lock_timeout = '10s';

ALTER TABLE analytics.gm_main_metrics_by_day_v2
DROP COLUMN IF EXISTS total_fba_inventory,
DROP COLUMN IF EXISTS available_fba,
DROP COLUMN IF EXISTS inbound_fba,
DROP COLUMN IF EXISTS awd_3pl_available_fba,
DROP COLUMN IF EXISTS raw_material_3pl,
DROP COLUMN IF EXISTS finished_good_3pl,
DROP COLUMN IF EXISTS po_in_transit_fba_agl,
DROP COLUMN IF EXISTS po_in_transit_upstream_raw_material,
DROP COLUMN IF EXISTS po_in_transit_3pl_raw_material,
DROP COLUMN IF EXISTS po_in_production_raw_material;

COMMIT;


-- =====================================================================
-- PASO 4: POST-CHECKS
-- =====================================================================

-- 4a) Debe devolver 0 filas
SELECT column_name
FROM information_schema.columns
WHERE
    table_schema = 'analytics'
    AND table_name = 'gm_main_metrics_by_day_v2'
    AND column_name IN (
        'total_fba_inventory',
        'available_fba',
        'inbound_fba',
        'awd_3pl_available_fba',
        'raw_material_3pl',
        'finished_good_3pl',
        'po_in_transit_fba_agl',
        'po_in_transit_upstream_raw_material',
        'po_in_transit_3pl_raw_material',
        'po_in_production_raw_material'
    );

-- 4b) total_rows / min / max iguales al paso 1c
SELECT
    COUNT(*) AS total_rows,
    MIN(date_sid) AS min_date_sid,
    MAX(date_sid) AS max_date_sid
FROM analytics.gm_main_metrics_by_day_v2;

-- 4c) (Opcional, fuera de horario) recuperar espacio. Bloquea la tabla mientras corre.
-- VACUUM FULL ANALYZE analytics.gm_main_metrics_by_day_v2;


-- =====================================================================
-- ROLLBACK (solo si hace falta). Usar los data_type reales del paso 1a.
-- =====================================================================
-- ALTER TABLE analytics.gm_main_metrics_by_day_v2
-- ADD COLUMN total_fba_inventory NUMERIC,
-- ADD COLUMN available_fba NUMERIC,
-- ADD COLUMN inbound_fba NUMERIC,
-- ADD COLUMN awd_3pl_available_fba NUMERIC,
-- ADD COLUMN raw_material_3pl NUMERIC,
-- ADD COLUMN finished_good_3pl NUMERIC,
-- ADD COLUMN po_in_transit_fba_agl NUMERIC,
-- ADD COLUMN po_in_transit_upstream_raw_material NUMERIC,
-- ADD COLUMN po_in_transit_3pl_raw_material NUMERIC,
-- ADD COLUMN po_in_production_raw_material NUMERIC;
--
-- UPDATE analytics.gm_main_metrics_by_day_v2 AS t
-- SET
--     total_fba_inventory = b.total_fba_inventory,
--     available_fba = b.available_fba,
--     inbound_fba = b.inbound_fba,
--     awd_3pl_available_fba = b.awd_3pl_available_fba,
--     raw_material_3pl = b.raw_material_3pl,
--     finished_good_3pl = b.finished_good_3pl,
--     po_in_transit_fba_agl = b.po_in_transit_fba_agl,
--     po_in_transit_upstream_raw_material = b.po_in_transit_upstream_raw_material,
--     po_in_transit_3pl_raw_material = b.po_in_transit_3pl_raw_material,
--     po_in_production_raw_material = b.po_in_production_raw_material
-- FROM analytics.gm_main_metrics_by_day_v2_inv_bkp_20261012 AS b
-- WHERE
--     t.date_sid = b.date_sid
--     AND t.product_sid = b.product_sid
--     AND t.marketplace IS NOT DISTINCT FROM b.marketplace
--     AND t.asin IS NOT DISTINCT FROM b.asin;
