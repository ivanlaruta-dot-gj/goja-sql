-- Propósito : Buscar tablas/vistas por nombre
-- Uso       : reemplaza '%tiktok%'
SELECT
    table_schema,
    table_name,
    table_type
FROM information_schema.tables
WHERE table_name ILIKE '%tiktok%'
ORDER BY 1, 2;
