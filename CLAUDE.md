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
- **Base de datos** (PostgreSQL, solo lectura): `postgres-dev`, `postgres-prod`, `postgres-dev-datacron`,
  `postgres-operations`, `postgres-cube-local`. Solo `SELECT`, nunca DDL/DML.
  - Los nombres son **históricos/referenciales** (así se conocen en IT): "dev" y "prod" **no** significan
    desarrollo y producción. No asumas qué contiene cada una por su nombre.
  - Si no sabes en cuál vive un objeto, búscalo en las conexiones (ver `catalog/buscar_tabla.sql`)
    o revisa `knowledge/conexiones.md`.
  - Indica siempre qué conexión usaste.

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
- El formato lo valida SQLFluff (`.sqlfluff`).
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

## Idioma
- Este es un repo **personal**: archivos, comentarios y documentación en **español**.
- Todo lo destinado a repos **oficiales** de GOJA (nexus, dbt, DAGs, PRs, tickets, docs del equipo)
  se escribe en **inglés**.
- Nombres de objetos (tablas, columnas, modelos) siempre tal cual existen.

## Forma de trabajar
- Una sesión = una tarea. Si cambia el tema, sugiere `/clear`.
- Nueva query → en la carpeta del dominio correcto (crea la carpeta si no existe).
