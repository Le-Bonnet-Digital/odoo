@echo off
setlocal enabledelayedexpansion

if "%~1"=="" (
  echo Usage: ensure_db.bat ^<database_name^>
  exit /b 1
)

set DBNAME=%~1

rem Load creds from .env (fallback to defaults)
set PGUSER=
set PGPASS=
for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
  if /I "%%A"=="POSTGRES_USER" set PGUSER=%%B
  if /I "%%A"=="POSTGRES_PASSWORD" set PGPASS=%%B
)
if "%PGUSER%"=="" set PGUSER=odoo
if "%PGPASS%"=="" set PGPASS=odoo

echo [ensure] Bringing up db service if needed...
docker compose up -d db >nul 2>&1

echo [ensure] Waiting for Postgres to accept connections...
set /a MAX_WAIT=180
for /l %%I in (1,1,%MAX_WAIT%) do (
  docker compose exec -T db pg_isready -U %PGUSER% -h 127.0.0.1 -p 5432 >nul 2>&1
  if !errorlevel! EQU 0 goto :ready
  timeout /t 1 >nul 2>&1
)

echo [ensure] WARNING: Postgres not ready after %MAX_WAIT% seconds. Continuing anyway.

:ready
set EXISTS=
for /f "usebackq tokens=*" %%R in (`docker compose exec -T db psql -U %PGUSER% -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='%DBNAME%';" 2^>nul`) do set EXISTS=%%R
set EXISTS=%EXISTS: =%

if "%EXISTS%"=="1" (
  echo [ensure] Database "%DBNAME%" already exists.
  exit /b 0
)

echo [ensure] Creating database "%DBNAME%"...
docker compose exec -T db psql -U %PGUSER% -d postgres -v ON_ERROR_STOP=1 -c "CREATE DATABASE %DBNAME% OWNER %PGUSER%;" || goto :err

echo [ensure] Initializing Odoo base in "%DBNAME%" (no demo)...
docker compose run --rm --entrypoint odoo odoo ^
  --db_host=db --db_port=5432 --db_user=%PGUSER% --db_password=%PGPASS% ^
  -d %DBNAME% -i base --without-demo=all --stop-after-init --logfile=- || goto :err

echo [ensure] Database "%DBNAME%" ready.
exit /b 0

:err
echo [ensure] ERROR ensuring database "%DBNAME%".
exit /b 1

