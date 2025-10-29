@echo off
setlocal enabledelayedexpansion

echo Switching to 'main' branch.

echo Stopping stack...
call stop.bat >nul 2>&1

echo Ensuring DB 'odoo_main' exists...
call ensure_db.bat odoo_main || echo WARNING: ensure_db reported an error (it may already exist).

echo Checking out 'main'...
git checkout main || goto :err

echo Starting stack on 'main'...
call start.bat

echo Done. Open http://localhost:8069
exit /b 0

:err
echo ERROR: Could not checkout 'main'.
exit /b 1

