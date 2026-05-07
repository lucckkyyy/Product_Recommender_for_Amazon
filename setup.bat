@echo off
setlocal EnableDelayedExpansion
title Amazon Product Recommender — Auto Setup
color 0A

echo.
echo  ============================================================
echo   Amazon Product Recommender Chatbot — Auto Setup
echo   By: Aryan Rajguru
echo  ============================================================
echo.

:: ── Step 0: Check for admin / prerequisites ──────────────────────────────────
echo [1/7] Checking prerequisites...

where python >nul 2>&1
if %errorlevel% neq 0 (
    echo  [ERROR] Python not found.
    echo  Please install Python 3.12 from https://python.org/downloads
    echo  Make sure to check "Add Python to PATH" during install!
    pause & exit /b 1
)
echo  [OK] Python found: && python --version

where docker >nul 2>&1
if %errorlevel% neq 0 (
    echo  [ERROR] Docker not found.
    echo  Please install Docker Desktop from https://docker.com/products/docker-desktop
    pause & exit /b 1
)
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo  [ERROR] Docker Desktop is installed but NOT running.
    echo  Please start Docker Desktop (whale icon in system tray) and re-run this script.
    pause & exit /b 1
)
echo  [OK] Docker is running.

where git >nul 2>&1
if %errorlevel% neq 0 (
    echo  [WARNING] Git not found. GitHub push will be skipped.
    echo  Install from https://git-scm.com if you want to push to GitHub.
    set GIT_AVAILABLE=false
) else (
    echo  [OK] Git found.
    set GIT_AVAILABLE=true
)

:: ── Step 1: Navigate to project folder ───────────────────────────────────────
echo.
echo [2/7] Setting up project directory...
cd /d "%~dp0"
echo  [OK] Working directory: %CD%

:: ── Step 2: Create .env if not present ───────────────────────────────────────
if not exist ".env" (
    echo.
    echo  [INFO] .env file not found. Creating from .env.example...
    copy .env.example .env >nul
    echo  [ACTION NEEDED] Open .env and fill in your credentials, then re-run this script.
    notepad .env
    pause & exit /b 0
)
echo  [OK] .env file found.

:: ── Step 3: Build Docker images ──────────────────────────────────────────────
echo.
echo [3/7] Building Docker image (this takes 5-10 min first time)...
docker compose build
if %errorlevel% neq 0 (
    echo  [ERROR] Docker build failed. Check error above.
    pause & exit /b 1
)
echo  [OK] Docker image built successfully.

:: ── Step 4: Start services ────────────────────────────────────────────────────
echo.
echo [4/7] Starting API + Prometheus + Grafana...
docker compose up -d
if %errorlevel% neq 0 (
    echo  [ERROR] docker compose up failed.
    pause & exit /b 1
)
echo  [OK] All services started.

:: Wait for API to be healthy
echo  Waiting for API to be ready...
set /a TRIES=0
:wait_loop
timeout /t 5 /nobreak >nul
curl -sf http://localhost:8000/health >nul 2>&1
if %errorlevel% equ 0 goto api_ready
set /a TRIES+=1
if !TRIES! geq 12 (
    echo  [ERROR] API did not start in 60 seconds. Run: docker compose logs api
    pause & exit /b 1
)
echo  Still waiting... (!TRIES!/12)
goto wait_loop
:api_ready
echo  [OK] API is healthy at http://localhost:8000

:: ── Step 5: Ingest data ───────────────────────────────────────────────────────
echo.
echo [5/7] Ingesting 50,000 Amazon products into Astra DB...
echo  (This takes 10-20 minutes. Do NOT close this window.)
echo.
docker compose exec -T api python -m app.ingest --limit 50000
if %errorlevel% neq 0 (
    echo  [WARNING] Ingestion exited with errors. Some data may have been loaded.
    echo  You can re-run ingestion with: docker compose exec api python -m app.ingest
) else (
    echo  [OK] Data ingested successfully!
)

:: ── Step 6: Smoke test ────────────────────────────────────────────────────────
echo.
echo [6/7] Running smoke test...
echo  Sending test question to the chatbot...
echo.
curl -s -X POST http://localhost:8000/chat ^
  -H "Content-Type: application/json" ^
  -d "{\"question\": \"Recommend a good Bluetooth speaker under $30\", \"chat_history\": []}"
echo.
echo  [OK] Smoke test complete.

:: ── Step 7: GitHub push (optional) ───────────────────────────────────────────
echo.
echo [7/7] GitHub Setup...
if "%GIT_AVAILABLE%"=="false" (
    echo  [SKIP] Git not installed. Skipping GitHub push.
    goto open_browser
)

if exist ".git" (
    echo  [INFO] Git repo already initialized.
) else (
    git init
    git add .
    git commit -m "feat: Amazon Product Recommender RAG Chatbot"
    echo.
    echo  Enter your GitHub repo URL (e.g. https://github.com/aryanraj/amazon-recommender.git)
    echo  Or press Enter to skip GitHub push:
    set /p REPO_URL="> "
    if "!REPO_URL!"=="" (
        echo  [SKIP] GitHub push skipped.
    ) else (
        git remote add origin !REPO_URL!
        git branch -M main
        git push -u origin main
        if %errorlevel% equ 0 (
            echo  [OK] Code pushed to GitHub!
        ) else (
            echo  [WARNING] Push failed. Make sure the repo exists and you are logged in.
        )
    )
)

:: ── Done — open everything in browser ────────────────────────────────────────
:open_browser
echo.
echo  ============================================================
echo   SETUP COMPLETE!
echo  ============================================================
echo.
echo   API Docs:    http://localhost:8000/docs
echo   API Health:  http://localhost:8000/health
echo   Prometheus:  http://localhost:9090
echo   Grafana:     http://localhost:3000  (admin / admin)
echo.
echo  Opening browser...
timeout /t 2 /nobreak >nul
start http://localhost:8000/docs
timeout /t 1 /nobreak >nul
start http://localhost:3000
echo.
pause
