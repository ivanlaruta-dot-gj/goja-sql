# goja-sql — Workspace SQL de Ivan (Analytics, GOJA)

## Qué es
Repositorio personal de queries PostgreSQL, exploración de lineaje y base de conocimiento.
Las queries se **ejecutan en DBeaver / DataGrip**; aquí se escriben, versionan y documentan.

## Fuentes que puedes leer
- **Repo del equipo `nexus`** (SOLO LECTURA — nunca editar ni hacer git en él):
  `C:/Users/IvanLaruta/Downloads/GOJA Bitbucket/nexus`
  - `airflow/dags/` → DAGs (`nexus_dags/event_nexus-*` = ingestas por fuente)
  - `dwh/models/` → dbt: `staging/` → `intermediate/` → `marts/`
  - `dwh/migrations/` → DDL versionado
  - `.claude/rules/sql-conventions.md` → convenciones SQL del equipo
- **Base de datos**: PostgreSQL. Solo `SELECT`. Preferir dev. Nunca DDL/DML.

## Base de conocimiento — REGLA PRINCIPAL
1. Antes de investigar una tabla, métrica o lineaje, lee `knowledge/INDEX.md`.
2. Si ya está documentado, úsalo como punto de partida y di la fecha de "Última verificación".
   Si tiene más de 30 días o hay señales de cambio, propone re-verificar antes de confiar.
3. Al cerrar una investigación con resultados, sugiere `/documentar`.
4. Nunca inventes tablas ni columnas: verifícalas en la BD o en los modelos dbt.

## Estructura
- `<dominio>/` → queries por tema de negocio (`tiktok/`, luego `amazon/`, `nexus/`, `golden-model/`...).
  Cada dominio puede tener su `CLAUDE.md` con contexto específico.
- `adhoc/` → exploración y borradores. Nombre: `YYYY-MM-DD_tema.sql`.
- `catalog/` → queries para explorar la BD (dependencias, funciones, columnas).
- `knowledge/` → `lineage/`, `hallazgos/`, `lineamientos/` + `INDEX.md` + `_plantillas/`.

## Convenciones SQL (alineadas con nexus/.claude/rules/sql-conventions.md)
- Palabras clave en MAYÚSCULAS. snake_case. Una columna por línea.
- CTEs con nombre descriptivo (lo que *contienen*), nunca subqueries; última CTE `final`.
- Nunca `SELECT *` en queries que alimentan reportes.
- Referencia objetos siempre como `esquema.tabla`.
- Archivos: `dominio_tema_detalle.sql` (ej. `tiktok_ventas_por_creador.sql`).
- Encabezado obligatorio:
  ```sql
  -- Propósito : ...
  -- Fuente    : esquema.tabla, ...
  -- Consumidor: (reporte PBI / validación / adhoc)
  -- Autor     : Ivan Laruta
  -- Creado    : YYYY-MM-DD
  -- Notas     : ...
  ```

## Forma de trabajar
- Responde en español; nombres de objetos tal cual existen.
- Una sesión = una tarea. Si cambia el tema, sugiere `/clear`.
- Nueva query → en la carpeta del dominio correcto (crea la carpeta si no existe).
