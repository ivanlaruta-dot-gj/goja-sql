-- Propósito : ¿En qué tablas/vistas existe una columna?
-- Uso       : reemplaza '%order_id%'
SELECT
    table_schema,
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE column_name ILIKE '%order_id%'
  AND table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY 1, 2, 3;
