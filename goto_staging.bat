@echo off
setlocal enabledelayedexpansion

echo Switching to 'staging' branch with optional DB sync from 'main'.

set CHOICE=
set /p CHOICE="Sync database 'odoo_main' -> 'odoo_staging'? (Y/n): "
if /I "%CHOICE%"=="" set CHOICE=Y

echo Stopping stack...
call stop.bat >nul 2>&1

if /I "%CHOICE%"=="Y" (
  echo Running sync from main to staging...
  call sync_staging_from_main.bat || echo WARNING: sync failed, continuing.
) else (
  echo Skipping DB sync.
)

echo Ensuring DB 'odoo_staging' exists...
call ensure_db.bat odoo_staging || echo WARNING: ensure_db reported an error (it may already exist).

echo Checking out 'staging'...
git checkout staging || goto :err

echo Starting stack on 'staging'...
call start.bat

echo Done. Open http://localhost:8069
exit /b 0

:err
echo ERROR: Could not checkout 'staging'.
exit /b 1

