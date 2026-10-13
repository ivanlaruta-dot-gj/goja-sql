-- Propósito : Validar una carga de analytics.gm_main_metrics_by_day_v2 (v2.5, sin inventario)
--             Sirve para recargas locales (gm_main_metrics_v2_carga_local.py) y para corridas del DAG.
-- Fuente    : analytics.gm_main_metrics_by_day_v2, analytics.gm_main_metrics_by_day_v2_inv_bkp_20261012
-- Consumidor: validación (NEX-3212 / NEX-3398)
-- Autor     : Ivan Laruta
-- Creado    : 2026-10-12
-- Notas     : 1) Ajusta el rango abajo y ejecuta las dos líneas @set (selecciónalas → Alt+X).
--                - Recarga local: el rango que recargaste (ej. 20261001 / 20261031).
--                - Corrida del DAG: día 1 de (mes actual - 4) → 31-dic del año actual
--                  (oct-2026 → 20260601 / 20261231).
--             2) Luego cada check con Ctrl+Enter. Checks 1–4 deben dar 0 filas / 0.
--             3) Check 3 asume que la carga fue HOY; si no, cambia CURRENT_DATE por la fecha.

@set desde = 20260601
@set hasta = 20261231


-- =====================================================================
-- CHECK 0: Cargas en el rango (la más reciente debe cubrir todo el rango)
-- =====================================================================
SELECT
    DATE_TRUNC('minute', last_update_date) AS carga,
    COUNT(*) AS filas,
    MIN(date_sid) AS desde,
    MAX(date_sid) AS hasta
FROM analytics.gm_main_metrics_by_day_v2
WHERE date_sid BETWEEN ${desde} AND ${hasta}
GROUP BY 1
ORDER BY 1 DESC
LIMIT 10;
-- Si la carga más reciente no cubre el rango completo, esa carga no se escribió (transacción revertida)
-- o el rango @set no coincide con lo que se cargó.


-- =====================================================================
-- CHECK 1: Duplicados en el grano (0 filas)
-- =====================================================================
SELECT
    date_sid,
    product_sid,
    marketplace,
    asin,
    COUNT(*) AS veces
FROM analytics.gm_main_metrics_by_day_v2
WHERE date_sid BETWEEN ${desde} AND ${hasta}
GROUP BY
    date_sid,
    product_sid,
    marketplace,
    asin
HAVING COUNT(*) > 1
ORDER BY veces DESC
LIMIT 50;


-- =====================================================================
-- CHECK 2: Calidad de llaves (product_sid_invalido = 0 y marketplace_tiktok = 0)
-- =====================================================================
SELECT
    COUNT(*) FILTER (WHERE product_sid IS NULL OR product_sid = 0) AS product_sid_invalido,
    COUNT(*) FILTER (WHERE LOWER(TRIM(marketplace)) = 'tiktok') AS marketplace_tiktok,
    COUNT(*) FILTER (
        WHERE COALESCE(TRIM(marketplace), '') <> ''
        AND marketplace NOT IN (
            'Amazon CA', 'Amazon DE', 'Amazon ES', 'Amazon FR', 'Amazon IT',
            'Amazon MX', 'Amazon SE', 'Amazon UK', 'Amazon US',
            'Shopify', 'Wholesale'
        )
    ) AS marketplace_fuera_guard_dbt
FROM analytics.gm_main_metrics_by_day_v2
WHERE date_sid BETWEEN ${desde} AND ${hasta};
-- marketplace_fuera_guard_dbt: el script local los filtra todos; el DAG solo filtra TikTok.
-- Si sale > 0 tras una corrida del DAG, ver detalle en 2b (rompería el accepted_values de dbt).

-- CHECK 2b: detalle de marketplaces fuera del guard
SELECT
    marketplace,
    COUNT(*) AS filas
FROM analytics.gm_main_metrics_by_day_v2
WHERE
    date_sid BETWEEN ${desde} AND ${hasta}
    AND COALESCE(TRIM(marketplace), '') <> ''
    AND marketplace NOT IN (
        'Amazon CA', 'Amazon DE', 'Amazon ES', 'Amazon FR', 'Amazon IT',
        'Amazon MX', 'Amazon SE', 'Amazon UK', 'Amazon US',
        'Shopify', 'Wholesale'
    )
GROUP BY marketplace
ORDER BY filas DESC;


-- =====================================================================
-- CHECK 3: Días sin filas o no recargados (0 filas)
-- =====================================================================
WITH dias_del_rango AS (
    SELECT TO_CHAR(d, 'YYYYMMDD')::INT AS date_sid
    FROM GENERATE_SERIES(
        TO_DATE('${desde}', 'YYYYMMDD'),
        TO_DATE('${hasta}', 'YYYYMMDD'),
        INTERVAL '1 day'
    ) AS d
),

carga_por_dia AS (
    SELECT
        date_sid,
        COUNT(*) AS filas,
        MIN(last_update_date) AS primera_carga
    FROM analytics.gm_main_metrics_by_day_v2
    WHERE date_sid BETWEEN ${desde} AND ${hasta}
    GROUP BY date_sid
),

final AS (
    SELECT
        d.date_sid,
        COALESCE(c.filas, 0) AS filas,
        c.primera_carga,
        CASE
            WHEN c.date_sid IS NULL THEN 'DIA SIN FILAS'
            WHEN c.primera_carga::DATE < CURRENT_DATE THEN 'FILAS DE UNA CARGA ANTERIOR'
        END AS problema
    FROM dias_del_rango AS d
    LEFT JOIN carga_por_dia AS c ON d.date_sid = c.date_sid
)

SELECT *
FROM final
WHERE problema IS NOT NULL
ORDER BY date_sid;


-- =====================================================================
-- CHECK 4: Columnas de inventario en la tabla (0 filas)
-- =====================================================================
SELECT column_name
FROM information_schema.columns
WHERE
    table_schema = 'analytics'
    AND table_name = 'gm_main_metrics_by_day_v2'
    AND column_name IN (
        'total_fba_inventory', 'available_fba', 'inbound_fba', 'awd_3pl_available_fba',
        'raw_material_3pl', 'finished_good_3pl', 'po_in_transit_fba_agl',
        'po_in_transit_upstream_raw_material', 'po_in_transit_3pl_raw_material',
        'po_in_production_raw_material'
    );


-- =====================================================================
-- CHECK 5: Perfil mensual (revisar a ojo)
-- =====================================================================
SELECT
    date_sid / 100 AS mes,
    COUNT(*) AS filas,
    COUNT(DISTINCT date_sid) AS dias,
    COUNT(DISTINCT asin) AS asins,
    ROUND(SUM(actual_sales)::NUMERIC, 2) AS actual_sales,
    SUM(actual_quantity) AS actual_quantity,
    ROUND(SUM(actual_cm)::NUMERIC, 2) AS actual_cm,
    ROUND(SUM(ppc_spend)::NUMERIC, 2) AS ppc_spend,
    ROUND(SUM(total_marketing_spend)::NUMERIC, 2) AS total_marketing_spend,
    ROUND(SUM(sales_forecast)::NUMERIC, 2) AS sales_forecast
FROM analytics.gm_main_metrics_by_day_v2
WHERE date_sid BETWEEN ${desde} AND ${hasta}
GROUP BY 1
ORDER BY 1;
-- Esperado: meses pasados con ventas reales, meses futuros solo forecast, "dias" completos.
-- "filas" puede ser menor que antes de NEX-3212 (ya no hay filas solo-inventario).


-- =====================================================================
-- CHECK 6: Filas que se fueron por ser solo-inventario (informativo, para el ticket)
-- =====================================================================
SELECT
    b.date_sid / 100 AS mes,
    COUNT(*) AS llaves_con_inventario,
    COUNT(*) FILTER (WHERE t.date_sid IS NULL) AS ya_no_existen
FROM analytics.gm_main_metrics_by_day_v2_inv_bkp_20261012 AS b
LEFT JOIN analytics.gm_main_metrics_by_day_v2 AS t
    ON
        b.date_sid = t.date_sid
        AND b.product_sid = t.product_sid
        AND b.marketplace IS NOT DISTINCT FROM t.marketplace
        AND b.asin IS NOT DISTINCT FROM t.asin
WHERE b.date_sid BETWEEN ${desde} AND ${hasta}
GROUP BY 1
ORDER BY 1;


-- =====================================================================
-- CHECK 7: Cuadre contra Golden Model (DAX Studio / vista de consultas DAX en Power BI)
-- =====================================================================
-- Compara por mes con el CHECK 5. Diferencias chicas = filas que la carga descarta
-- (product_sid 0/NULL, TikTok, marketplaces fuera del guard).
-- Cambia las fechas de la DAX al mismo rango del @set.
--
-- EVALUATE
-- SUMMARIZECOLUMNS(
--     Dim_Date[Year],
--     Dim_Date[Month],
--     FILTER(
--         ALL(Dim_Date[Date]),
--         Dim_Date[Date] >= DATE(2026,6,1) && Dim_Date[Date] <= DATE(2026,12,31)
--     ),
--     "Actual Sales",          [Actual Sales],
--     "Actual Quantity",       [Actual Quantity],
--     "Actual CM",             [Actual CM],
--     "PPC Spend",             [PPC Spend],
--     "Total Marketing Spend", [Total Marketing Spend],
--     "Sales Forecast",        [Sales Forecast]
-- )
-- (Si Dim_Date no tiene Year/Month con esos nombres, usa las columnas equivalentes del modelo.)
