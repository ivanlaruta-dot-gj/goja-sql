# Conexiones a bases de datos

Los nombres son históricos (así se conocen en IT). "dev" y "prod" **no** reflejan el ambiente real.
Completar a medida que se descubra qué contiene cada una.

| Conexión | Qué contiene realmente | Esquemas clave | Notas |
|---|---|---|---|
| postgres-prod | BD `datapool` _(contenido por documentar)_ | `analytics` existe | Solo lectura. `analytics.gm_main_metrics_by_day_v2` NO está aquí (2026-10-12) |
| postgres-dev | BD `datapool` _(contenido por documentar)_ | | En el datapool dev, Ivan es dueño solo de `pbireport`. `analytics.gm_main_metrics_by_day_v2` NO está aquí (2026-10-12) |
| postgres-dev-datacron | BD `datacron` _(contenido por documentar)_ | | `analytics.gm_main_metrics_by_day_v2` NO está aquí (2026-10-12) |
| postgres-operations | _(por documentar)_ | | |
| postgres-cube-local | _(por documentar)_ | | |

**Última verificación:** 2026-10-12 (solo nombre de BD por conexión)
