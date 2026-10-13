# Lineamiento: Flujo de ramas y deploy en el repo nexus

**Dominio:** nexus · **Verificado con:** `git log origin/master --merges` + Bitbucket Pipelines · **Fecha:** 2026-10-12

> No hay documentación vigente en el repo (`RELEASE_NOTES.md` y `README.md` desactualizados) ni en Confluence.
> Esto sale del historial real de git y de `bitbucket-pipelines.yml`.

## Regla
1. Rama desde `master` actualizado: `feature/NEX-XXXX`, `issue/NEX-XXXX` o `fix/NEX-XXXX`.
2. **PR directo a `master`.** Es el flujo normal del equipo: en octubre de 2026 todos (Angel, Cristian, Laura,
   Adriana, Giuliana, Gonzalo, Selwa) mergean `feature/`, `issue/` y `fix/` directo a `master`.
   - Ojo: Bitbucket propone `dev` como destino por defecto. **Cambiarlo a `master`** y verificar que el PR
     muestre solo tus commits.
3. **Release a producción:** lo hace Armando Orellana. Toma lo mergeado en `master`, crea el commit
   `v1.5.xxx Release` + tag y despliega fuera de Bitbucket (no hay paso para `master` en Pipelines y
   Bitbucket Deployments no está habilitado).
4. **`dev` (opcional, para probar en Airflow dev):** hacer una rama `<rama>-dev` desde `origin/dev` y un PR a `dev`.
   Al mergear a `dev`, Pipelines dispara Jenkins:
   - Si cambió `airflow/**`, `dwh/**` o `dbt/**` → "Airflow Sync Dev".
   - Si cambió `nexus/**` → "Nexus Dev".
   Armando sincroniza `master` → `dev` después de cada release ("Merge Master v1.5.xxx into dev").

## Sync a Airflow prod (manual)
- 2026-10-12: el equipo informó que el **Jenkins automático está desactivado** por conflictos.
  Después del merge hay que **avisar al equipo el caso puntual** (PR, archivo del DAG) para que hagan el sync a Airflow prod.
- Mientras no se sincronice, el DAG en prod sigue con el código viejo: mantenerlo **pausado** si el cambio es incompatible con la tabla.

## Cómo saber si mi cambio ya está en producción
- Buscar un commit `v1.5.xxx Release` posterior a mi merge en `master`.
- Confirmar en Airflow prod → DAG → pestaña **Code**.

## Comandos útiles
```powershell
git log origin/master --merges --first-parent -30 --format="%h %ad %an  %s" --date=short   # últimos merges
git log origin/master --format="%h %ad %an  %s" --date=short -- <archivo>                   # historia de un archivo
git log origin/master --grep="Release" -5 --format="%h %ad %an  %s" --date=short           # últimos releases
```
(Si la salida termina en `:`, Git está paginando → `q` para salir.)

## Si el PR muestra cientos de archivos
El destino es una rama atrasada (normalmente `dev`). Cambiar el destino a `master`.

## Historial
- 2026-10-12: NEX-3398 mergeado directo a `master` (PR #1592), como los cambios anteriores del DAG
  (NEX-2534, NEX-2597, NEX-2598).
