@echo off
setlocal enabledelayedexpansion

rem Read Postgres credentials from .env (fallback to defaults)
set PGUSER=
set PGPASS=
for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
  if /I "%%A"=="POSTGRES_USER" set PGUSER=%%B
  if /I "%%A"=="POSTGRES_PASSWORD" set PGPASS=%%B
)
if "%PGUSER%"=="" set PGUSER=odoo
if "%PGPASS%"=="" set PGPASS=odoo

echo Ensuring Postgres container is running...
set DBID=
for /f %%I in ('docker ps -q -f "name=^/odoo-db$"') do set DBID=%%I
if "%DBID%"=="" (
  docker compose up -d db || goto :err
)

echo Stopping Odoo container to free DB connections...
docker compose stop odoo >nul 2>&1

echo Cloning database: odoo_main -> odoo_staging ...
docker exec -e PGPASSWORD=%PGPASS% odoo-db psql -U %PGUSER% -d postgres -v ON_ERROR_STOP=1 -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname IN ('odoo_main','odoo_staging') AND pid <> pg_backend_pid();" || goto :err
docker exec -e PGPASSWORD=%PGPASS% odoo-db psql -U %PGUSER% -d postgres -v ON_ERROR_STOP=1 -c "DROP DATABASE IF EXISTS odoo_staging;" || goto :err
docker exec -e PGPASSWORD=%PGPASS% odoo-db psql -U %PGUSER% -d postgres -v ON_ERROR_STOP=1 -c "CREATE DATABASE odoo_staging WITH TEMPLATE odoo_main OWNER %PGUSER%;" || goto :err

echo Copying filestore: odoo_main -> odoo_staging ...
docker compose run --rm --entrypoint bash odoo -c "set -e; SRC=/var/lib/odoo/.local/share/Odoo/filestore/odoo_main; DST=/var/lib/odoo/.local/share/Odoo/filestore/odoo_staging; if [ -d \"$SRC\" ]; then rm -rf \"$DST\"; mkdir -p \"$(dirname $DST)\"; cp -a \"$SRC\" \"$DST\"; fi" || goto :err

echo Done cloning odoo_main -> odoo_staging.
exit /b 0

:err
echo.
echo ERROR: Could not clone 'odoo_main' to 'odoo_staging'.
echo - Ensure the database 'odoo_main' exists in Postgres.
echo - Check that container 'odoo-db' is running (docker ps).
exit /b 1
