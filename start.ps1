# Root delegate - canonical launcher is webapp/start.ps1 (fleet START_SCRIPT_STANDARD)
param([switch]$Headless, [switch]$BackendOnly, [switch]$NoBrowser)

& (Join-Path $PSScriptRoot "webapp\start.ps1") @PSBoundParameters
exit $LASTEXITCODE
