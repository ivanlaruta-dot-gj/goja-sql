-- Propósito : Ver el SQL de una vista
-- Uso       : reemplaza 'esquema.mi_vista'
SELECT pg_get_viewdef('esquema.mi_vista'::regclass, true) AS definicion;
