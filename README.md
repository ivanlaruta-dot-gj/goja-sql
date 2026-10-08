# goja-sql

Workspace SQL de Ivan Laruta (Analytics, GOJA): queries, exploración de lineaje y base de conocimiento.

## Cómo encaja todo
| Herramienta | Rol |
|---|---|
| VS Code / Antigravity + Claude Code | Escribir queries, investigar, documentar |
| DBeaver / DataGrip | Ejecutar queries (enlazan ESTA carpeta) |
| Git | Historial y respaldo |
| `nexus` (GOJA Bitbucket, solo lectura) | DAGs + dbt para rastrear lineaje |

## Setup (una sola vez)

### 1. Git + GitHub (en PowerShell)
Remoto: https://github.com/ivanlaruta-dot-gj/ivan_datateam (privado)
```powershell
cd "$env:USERPROFILE\Downloads\GOJA\DataTeam\goja-sql"
git init
git add .
git status          # revisar que no haya credenciales ni CSVs
git commit -m "Estructura inicial del workspace SQL"
git branch -M main
git remote add origin https://github.com/ivanlaruta-dot-gj/ivan_datateam.git
git push -u origin main
```
Día a día: `git add .` → `git commit -m "..."` → `git push`.

### 2. DBeaver
Vista **Projects** → clic derecho en **Scripts** → **Create → Link Folder** → elegir `goja-sql`.
Al abrir un `.sql`, asignar la conexión (Ctrl+9).

### 2b. DataGrip (alternativa)
Ventana **Files** → **Attach Directory to Project** → `goja-sql`.

### 3. Mantener nexus actualizado
```powershell
cd "$env:USERPROFILE\Downloads\GOJA Bitbucket\nexus"
git pull
```

## Uso diario con Claude Code
```powershell
cd "$env:USERPROFILE\Downloads\GOJA\DataTeam\goja-sql"
claude
```
| Comando | Para qué |
|---|---|
| `claude` | Sesión nueva |
| `claude --continue` | Retomar la última sesión |
| `claude --resume` | Elegir una sesión anterior |
| `/clear` | Limpiar contexto al cambiar de tarea |
| `/lineage <tabla>` | Rastrear lineaje end-to-end |
| `/documentar <tema>` | Guardar hallazgos en `knowledge/` |
| `/mcp` | Ver si Claude Code tiene conexión a Postgres |

Flujo: pedir/escribir query → ejecutar en DBeaver → `/documentar` si hubo hallazgo → `git commit`.

## Estructura
```
goja-sql/
├── CLAUDE.md              reglas generales (Claude lo lee siempre)
├── .claude/
│   ├── settings.json      acceso de lectura al repo nexus
│   └── commands/          /lineage, /documentar
├── tiktok/                queries + CLAUDE.md del dominio
├── adhoc/                 exploración (YYYY-MM-DD_tema.sql)
├── catalog/               queries para explorar la BD
└── knowledge/
    ├── INDEX.md           revisar antes de investigar
    ├── lineage/           de dónde viene cada tabla
    ├── hallazgos/         problemas encontrados y cómo se resolvieron
    ├── lineamientos/      reglas acordadas
    └── _plantillas/
```
Nuevos dominios (`amazon/`, `nexus/`, `golden-model/`...) se crean cuando haga falta.
