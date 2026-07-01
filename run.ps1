# Acme Market Intelligence Platform - startup script
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

$Python = $null
foreach ($candidate in @(
    ".\.venv\Scripts\python.exe",
    ".\.venv\bin\python.exe",
    "py",
    "python",
    "python3"
)) {
    if (Get-Command $candidate -ErrorAction SilentlyContinue) {
        $Python = $candidate
        break
    }
}

if (-not $Python) {
    Write-Host "Python not found. Install Python 3.11+ from https://www.python.org/downloads/" -ForegroundColor Red
    Write-Host "Or use Docker: docker compose up --build" -ForegroundColor Yellow
    exit 1
}

Write-Host "Using Python: $Python" -ForegroundColor Cyan

if (-not (Test-Path ".\.venv")) {
    & $Python -m venv .venv
}

$VenvPython = if (Test-Path ".\.venv\Scripts\python.exe") { ".\.venv\Scripts\python.exe" } else { ".\.venv\bin\python.exe" }
& $VenvPython -m pip install -r requirements.txt

# Check Java for Apache Spark (UC3)
$JavaCmd = Get-Command java -ErrorAction SilentlyContinue
if (-not $JavaCmd) {
    Write-Host "`nWARNING: Java not found — Spark analytics will use Python fallback." -ForegroundColor Yellow
    Write-Host "For Apache Spark, install JDK 17:" -ForegroundColor Yellow
    Write-Host "  winget install EclipseAdoptium.Temurin.17.JDK" -ForegroundColor Cyan
    Write-Host "Then add JAVA_HOME to .env (see .env.example)" -ForegroundColor Yellow
    Write-Host "Or use Docker (includes Java): docker compose up --build`n" -ForegroundColor Yellow
} else {
    Write-Host "Java found: $($JavaCmd.Source)" -ForegroundColor Green
    if (-not $env:JAVA_HOME) {
        $JavaHome = Split-Path (Split-Path $JavaCmd.Source -Parent) -Parent
        $env:JAVA_HOME = $JavaHome
        Write-Host "JAVA_HOME set to: $JavaHome" -ForegroundColor Cyan
    }
}

Write-Host "`nSeeding database (requires MongoDB on localhost:27017)..." -ForegroundColor Cyan
& $VenvPython scripts\seed.py

Write-Host "`nStarting API on http://localhost:8000 ..." -ForegroundColor Green
& $VenvPython -m uvicorn app.main:app --reload --port 8000
