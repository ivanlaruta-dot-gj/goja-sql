-- Propósito : ¿Qué vistas dependen de esta tabla? (lineaje hacia adelante, 1 nivel)
-- Uso       : reemplaza 'esquema.mi_tabla'
-- Autor     : Ivan Laruta
SELECT DISTINCT
    vn.nspname  AS esquema,
    v.relname   AS vista,
    v.relkind   AS tipo
FROM pg_depend d
JOIN pg_rewrite r     ON r.oid = d.objid
JOIN pg_class v       ON v.oid = r.ev_class
JOIN pg_namespace vn  ON vn.oid = v.relnamespace
WHERE d.refobjid = 'esquema.mi_tabla'::regclass
  AND v.oid <> d.refobjid
ORDER BY 1, 2;
