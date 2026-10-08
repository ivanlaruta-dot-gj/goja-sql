---
description: Rastrea el lineaje end-to-end de una tabla/objeto
argument-hint: <tabla o tabla de Power BI>
---
Rastrea el lineaje end-to-end de: $ARGUMENTS

1. Primero revisa `knowledge/INDEX.md`. Si ya está documentado, muéstramelo con su fecha de
   verificación y pregunta si re-verificamos antes de seguir.
2. Power BI (si aplica): identifica qué tabla/vista o archivo consume (Power Query / .pbip / MCP de Power BI).
3. Base de datos: si es vista, obtén su definición y dependencias (ver `catalog/`), y baja hasta las tablas base.
4. Quién puebla las tablas base: busca el nombre en el repo nexus
   (`airflow/dags/`, `dwh/models/`, `dwh/migrations/`) y funciones en la BD.
5. Identifica schedule del DAG, la fuente original (API, S3, SharePoint...) y transformaciones clave.
6. Muéstrame el resultado como diagrama mermaid + tabla de capas.
7. Pregúntame si lo guardo con `/documentar`.

Solo lectura: no ejecutes DDL/DML ni edites el repo nexus.
