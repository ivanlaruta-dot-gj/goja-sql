-- Propósito : ¿De qué tablas/vistas depende una vista? (lineaje hacia atrás, 1 nivel)
-- Uso       : reemplaza 'esquema.mi_vista'. relkind: r=tabla, v=vista, m=vista materializada
-- Autor     : Ivan Laruta
SELECT DISTINCT
    dn.nspname  AS esquema,
    dc.relname  AS objeto,
    dc.relkind  AS tipo
FROM pg_depend d
JOIN pg_rewrite r     ON r.oid = d.objid
JOIN pg_class v       ON v.oid = r.ev_class
JOIN pg_class dc      ON dc.oid = d.refobjid
JOIN pg_namespace dn  ON dn.oid = dc.relnamespace
WHERE v.oid = 'esquema.mi_vista'::regclass
  AND dc.oid <> v.oid
ORDER BY 1, 2;
