@echo off
setlocal EnableDelayedExpansion
title Push to GitHub
color 0E

echo.
echo  ============================================================
echo   GitHub Push — Amazon Product Recommender
echo  ============================================================
echo.

where git >nul 2>&1
if %errorlevel% neq 0 (
    echo  [ERROR] Git not installed. Download from https://git-scm.com
    pause & exit /b 1
)

cd /d "%~dp0"

:: Initialize repo if needed
if not exist ".git" (
    echo  Initializing git repo...
    git init
    git add .
    git commit -m "feat: Amazon Product Recommender RAG Chatbot"
    echo  [OK] Initial commit created.
) else (
    echo  [OK] Git repo already initialized.
    echo  Adding any new changes...
    git add .
    git diff --cached --quiet || git commit -m "update: Amazon Product Recommender"
)

:: Get repo URL
echo.
echo  Paste your GitHub repo URL below.
echo  (Create the repo first at https://github.com/new — name it amazon-recommender)
echo  Example: https://github.com/aryanrajguru/amazon-recommender.git
echo.
set /p REPO_URL="GitHub URL: "

if "!REPO_URL!"=="" (
    echo  [SKIP] No URL entered. Exiting.
    pause & exit /b 0
)

:: Set remote
git remote remove origin 2>nul
git remote add origin !REPO_URL!
git branch -M main

echo.
echo  Pushing to GitHub...
git push -u origin main

if %errorlevel% equ 0 (
    echo.
    echo  ============================================================
    echo   SUCCESS! Your code is live on GitHub.
    echo  ============================================================
    echo.
    echo  Your repo: !REPO_URL!
    echo.
    echo  TIP: Add a description on GitHub:
    echo  "Context-aware RAG chatbot for 500K+ Amazon products using
    echo  LangChain, Groq LLM, HuggingFace embeddings, Astra DB,
    echo  Docker, Kubernetes (Minikube), Prometheus and Grafana."
) else (
    echo.
    echo  [ERROR] Push failed. Common fixes:
    echo    1. Make sure the GitHub repo exists (https://github.com/new)
    echo    2. Run: git config --global user.email "you@example.com"
    echo    3. Run: git config --global user.name "Your Name"
    echo    4. GitHub may ask you to log in — use your GitHub username + token
)

pause
