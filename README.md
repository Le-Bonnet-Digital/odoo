# Odoo Local Environment

This repository contains a local Odoo 18 development environment driven by Docker Compose. It is tuned for a two-branch workflow (`main` and `staging`) with isolated PostgreSQL databases and optional cloning between them.

## Prerequisites

- Docker Desktop (with the Compose V2 plugin available as `docker compose`).
- Git for Windows and PowerShell.

## Environment Files

- `.env` &ndash; main runtime configuration loaded by Docker Compose and helper scripts. `ODOO_ADMIN_PASSWORD` can be plain text or a PBKDF2 hash. When using a hash, escape dollar signs as `$$...` (Compose requirement); `start.bat` automatically converts them back before updating `config/odoo.conf`.
- `.env.example` &ndash; template reference.

## Core Compose Stack

| Service | Purpose | Notes |
|---------|---------|-------|
| `db`    | PostgreSQL 15 | Data is persisted in the `odoo-db-data` volume. |
| `odoo`  | Custom image based on `odoo:18` | Mounts `config/odoo.conf`, `addons/`, and `oca/`. Logs go to stdout. |

Start/stop the stack manually if needed with:

```powershell
docker compose up -d
docker compose down
```

Normally you should use the helper scripts described below instead of calling Compose directly.

## Helper Scripts

The workflow is intentionally explicit: you decide when staging should mirror main. Two wrapper scripts orchestrate branch checkout, container lifecycle, and database preparation.

### `goto_main.bat`

```
.\\goto_main.bat
```

- Stops the stack.
- Ensures the `odoo_main` database exists (creating/initialising it if missing via `ensure_db.bat`).
- Checks out the `main` Git branch.
- Restarts the stack targeting `odoo_main`.

Use this whenever you switch back to the main line.

### `goto_staging.bat`

```
.\\goto_staging.bat
```

Prompts: `Sync database 'odoo_main' -> 'odoo_staging'? (Y/n)`

- Y: clones the PostgreSQL database (`odoo_main` → `odoo_staging`) **and** copies the Odoo filestore so web assets remain available.
- N: reuses the current `odoo_staging` database as-is.
- In both cases: stops the stack, ensures `odoo_staging` exists, checks out the `staging` branch, and restarts Odoo pointing to `odoo_staging`.

## Supporting Scripts

- `start.bat` / `stop.bat` &ndash; raw lifecycle helpers (used internally by the goto scripts). They derive the database name from the current branch but you should prefer the goto scripts which also manage Git checks and DB readiness.
- `sync_staging_from_main.bat` &ndash; invoked by `goto_staging.bat` when you opt-in to sync. Only call it directly if you know what you are doing.
- `ensure_db.bat` &ndash; creates/initialises a given PostgreSQL database when called by the goto scripts.

## Daily Workflow

1. **Work on `main`**
   ```powershell
   .\goto_main.bat
   ```
2. **Review on `staging`**
   ```powershell
   .\goto_staging.bat   # answer Y to clone or N to reuse
   ```
3. **Return to main** when ready to merge or continue.

Repeat as needed; each branch always points at its own database (`odoo_main`, `odoo_staging`).

## Troubleshooting

- **Login page without CSS after cloning**: rerun `goto_staging.bat` and answer `Y`. The script copies both the database and filestore; if the filestore copy fails, check `docker compose logs` for permission issues.
- **“Create Database” wizard appears**: ensure you started via one of the goto scripts so `ensure_db.bat` can initialize the target DB, and confirm `config/odoo.conf` is mounted (Compose handles this by default).
- **Need access to Database Manager**: open `http://localhost:8069/web/database/manager` and use the master password defined in `.env` / `config/odoo.conf` (`admin_passwd`).

## Branch Hygiene

- Code promotion still happens via Git PRs (e.g., `staging` → `main`).
- Databases are intentionally isolated; cloning staging from main is manual to avoid overwriting data unintentionally.
- No Git hooks remain in this repository; the helper scripts are the single source of orchestration.

## Directory Layout (excerpt)

```
addons/              # custom addons loaded by Odoo
config/odoo.conf     # Odoo configuration (mounted into the container)
oca/                 # OCA addons (mounted)
.env                 # runtime variables (see above)
docker-compose.yml   # Compose stack definition
goto_main.bat        # switch helper
goto_staging.bat     # switch helper with optional sync
ensure_db.bat        # database bootstrapper used by goto scripts
sync_staging_from_main.bat
start.bat / stop.bat
```

Feel free to extend this README with project-specific instructions (e.g., module install lists or testing commands) as your workflow evolves.
