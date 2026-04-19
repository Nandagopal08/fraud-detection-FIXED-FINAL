@echo off
setlocal enabledelayedexpansion
REM ================================================================
REM  deploy-local.bat  —  Windows one-command deployment
REM  Double-click OR run from CMD in the project root folder.
REM ================================================================

REM ── Stay in the folder where this .bat file lives ───────────────
cd /d "%~dp0"

echo.
echo  ============================================================
echo   FRAUD DETECTION - LOCAL DEPLOYMENT  (Paper Replica)
echo   Docker + Prometheus + Grafana + Portainer + Jenkins
echo  ============================================================
echo.
echo   Running from: %CD%
echo.

REM ── Check creditcard.csv ────────────────────────────────────────
if not exist "creditcard.csv" (
    echo [ERROR] creditcard.csv not found in %CD%
    echo.
    echo   Download from:
    echo   https://www.kaggle.com/datasets/mlg-ulb/creditcardfraud
    echo   Then place creditcard.csv in this folder and re-run.
    pause
    exit /b 1
)
echo [OK] creditcard.csv found

REM ── Check Dockerfile is here ────────────────────────────────────
if not exist "Dockerfile" (
    echo [ERROR] Dockerfile not found. Make sure you run from the project root.
    pause
    exit /b 1
)
echo [OK] Dockerfile found

REM ── Check Docker is running ─────────────────────────────────────
docker info >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker is not running. Please start Docker Desktop first.
    pause
    exit /b 1
)
echo [OK] Docker is running
echo.

REM ── PRE-FLIGHT: Remove any leftover containers from prior runs ──
echo [0/5] Cleaning up any leftover containers from previous runs...
docker rm -f fraud-api    2>nul
docker rm -f prometheus   2>nul
docker rm -f grafana      2>nul
docker rm -f portainer    2>nul
docker rm -f cadvisor     2>nul
docker rm -f jenkins      2>nul
echo [OK] Cleanup done
echo.

REM ── Step 1: Build Docker image ──────────────────────────────────
echo [1/5] Building Docker image (trains ML model inside, ~2-3 min)...
docker build -t ameyab16/fraud-api:latest .
if errorlevel 1 (
    echo [ERROR] Docker build failed. Check output above.
    pause
    exit /b 1
)
echo [OK] Image built: ameyab16/fraud-api:latest
echo.

REM ── Step 2: Create network ──────────────────────────────────────
echo [2/5] Ensuring Docker network exists...
docker network create monitoring 2>nul
echo [OK] Network ready
echo.

REM ── Step 3: Deploy main stack ───────────────────────────────────
echo [3/5] Starting: Fraud API + Prometheus + Grafana + Portainer + cAdvisor...
docker compose up -d
if errorlevel 1 (
    echo [ERROR] Stack failed to start. See errors above.
    pause
    exit /b 1
)
echo [OK] Main stack started
echo.

REM ── Step 4: Jenkins ─────────────────────────────────────────────
echo [4/5] Starting Jenkins CI/CD container...
docker compose -f jenkins\docker-compose.jenkins.yml up -d
if errorlevel 1 (
    echo [WARN] Jenkins failed to start - continuing anyway.
)
echo [OK] Jenkins started
echo.

REM ── Step 5: Wait for Fraud API health ───────────────────────────
echo [5/5] Waiting for Fraud API to become healthy (up to 3 min)...
echo       (Model is pre-trained in image so startup is fast)
echo.

set HEALTHY=0
for /L %%i in (1,1,18) do (
    if !HEALTHY! == 0 (
        timeout /t 10 /nobreak >nul
        curl -sf http://localhost:5000/health >nul 2>&1
        if not errorlevel 1 (
            echo [OK] Fraud API is healthy!
            set HEALTHY=1
        ) else (
            echo      Attempt %%i/18 - still starting...
        )
    )
)

if !HEALTHY! == 0 (
    echo [WARN] API not responding yet. Run: docker logs fraud-api
)

REM ── Jenkins password ─────────────────────────────────────────────
echo.
echo   Jenkins initial admin password:
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>nul
echo.

REM ── Done ─────────────────────────────────────────────────────────
echo  ============================================================
echo   ALL SERVICES ARE LIVE
echo  ============================================================
echo.
echo   Fraud Detection Dashboard  :  http://localhost:5000
echo   Health Check               :  http://localhost:5000/health
echo   Prometheus Metrics         :  http://localhost:9090
echo   Grafana  (admin / admin)   :  http://localhost:3000
echo   Portainer Docker UI        :  http://localhost:9000
echo   Jenkins CI/CD              :  http://localhost:8080
echo   cAdvisor Container Stats   :  http://localhost:8088
echo.
echo  ============================================================
echo.
pause
