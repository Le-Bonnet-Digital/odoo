@echo off
setlocal enabledelayedexpansion

rem Get current git branch
for /f "tokens=*" %%g in ('git rev-parse --abbrev-ref HEAD') do (set GIT_BRANCH=%%g)

rem Sanitize branch to a Postgres-safe DB name (replace / \ - . and spaces)
set BRANCH=!GIT_BRANCH:/=_!
set BRANCH=!BRANCH:\=_!
set BRANCH=!BRANCH:-=_!
set BRANCH=!BRANCH:.=_!
set BRANCH=!BRANCH: =_!

set POSTGRES_DB=odoo_!BRANCH!
set ODOO_DB_NAME=odoo_!BRANCH!

echo Starting Odoo with database "!ODOO_DB_NAME!" for branch "!GIT_BRANCH!"
echo To follow logs: docker compose logs -f odoo

rem Sync master password from .env into config/odoo.conf (keeps secret outside repo history)
for /f "usebackq tokens=1,* delims==" %%a in (".env") do (
  if /I "%%a"=="ODOO_ADMIN_PASSWORD" set ODOO_ADMIN_PASSWORD=%%b
)
if defined ODOO_ADMIN_PASSWORD (
  set "ODOO_ADMIN_PASSWORD=!ODOO_ADMIN_PASSWORD:$$=$!"
  powershell -NoLogo -NoProfile -Command "$p='config/odoo.conf'; $ap=$env:ODOO_ADMIN_PASSWORD; if([string]::IsNullOrEmpty($ap)) { exit } $raw=Get-Content $p -Raw; if($raw -match '(?m)^[\s;#]*admin_passwd\s*='){ $new=[regex]::Replace($raw,'(?m)^[\s;#]*admin_passwd\s*=.*','admin_passwd = ' + $ap) } else { $nl=[Environment]::NewLine; $new=$raw.TrimEnd() + $nl + 'admin_passwd = ' + $ap + $nl }; Set-Content $p -Value $new -NoNewline"
)

docker compose up -d --remove-orphans

endlocal
