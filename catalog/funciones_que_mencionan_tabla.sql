-- Propósito : Funciones/procedimientos que mencionan una tabla (posibles pobladoras)
-- Uso       : reemplaza 'mi_tabla'
-- Autor     : Ivan Laruta
SELECT
    n.nspname                 AS esquema,
    p.proname                 AS funcion,
    pg_get_functiondef(p.oid) AS definicion
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.prosrc ILIKE '%mi_tabla%'
  AND p.prokind IN ('f', 'p')
  AND n.nspname NOT IN ('pg_catalog', 'information_schema');
