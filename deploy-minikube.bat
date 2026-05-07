@echo off
setlocal EnableDelayedExpansion
title Amazon Recommender — Minikube Deploy
color 0B

echo.
echo  ============================================================
echo   Minikube + Kubernetes + Prometheus/Grafana Deploy
echo  ============================================================
echo.

:: ── Check tools ──────────────────────────────────────────────────────────────
where minikube >nul 2>&1
if %errorlevel% neq 0 (
    echo  [ERROR] Minikube not found.
    echo  Download from: https://minikube.sigs.k8s.io/docs/start/
    echo  Windows quick install (PowerShell as Admin):
    echo    winget install minikube
    pause & exit /b 1
)

where kubectl >nul 2>&1
if %errorlevel% neq 0 (
    echo  [ERROR] kubectl not found.
    echo  Install: winget install Kubernetes.kubectl
    pause & exit /b 1
)

where helm >nul 2>&1
if %errorlevel% neq 0 (
    echo  [ERROR] Helm not found.
    echo  Install: winget install Helm.Helm
    pause & exit /b 1
)

echo  [OK] minikube, kubectl, and helm found.

:: ── Step 1: Start Minikube ────────────────────────────────────────────────────
echo.
echo [1/6] Starting Minikube (4GB RAM, 2 CPUs)...
minikube start --memory=4096 --cpus=2 --driver=docker
if %errorlevel% neq 0 (
    echo  [ERROR] Minikube failed to start.
    pause & exit /b 1
)
echo  [OK] Minikube is running.

:: ── Step 2: Build image inside Minikube ──────────────────────────────────────
echo.
echo [2/6] Building Docker image inside Minikube...
echo  (Configuring Docker to use Minikube's daemon...)
FOR /F "tokens=*" %%i IN ('minikube docker-env --shell cmd') DO %%i
docker build -t amazon-recommender:latest .
if %errorlevel% neq 0 (
    echo  [ERROR] Docker build failed.
    pause & exit /b 1
)
echo  [OK] Image built inside Minikube.

:: ── Step 3: Create namespace + secrets ───────────────────────────────────────
echo.
echo [3/6] Creating namespace and secrets...
kubectl create namespace production --dry-run=client -o yaml | kubectl apply -f -

:: Read credentials from .env file
for /f "usebackq tokens=1,* delims==" %%a in (".env") do (
    if "%%a"=="GROQ_API_KEY"               set GROQ_API_KEY=%%b
    if "%%a"=="ASTRA_DB_APPLICATION_TOKEN" set ASTRA_DB_APPLICATION_TOKEN=%%b
    if "%%a"=="ASTRA_DB_API_ENDPOINT"      set ASTRA_DB_API_ENDPOINT=%%b
)

kubectl create secret generic amazon-recommender-secrets ^
  --from-literal=GROQ_API_KEY=!GROQ_API_KEY! ^
  --from-literal=ASTRA_DB_APPLICATION_TOKEN=!ASTRA_DB_APPLICATION_TOKEN! ^
  --from-literal=ASTRA_DB_API_ENDPOINT=!ASTRA_DB_API_ENDPOINT! ^
  --namespace production ^
  --dry-run=client -o yaml | kubectl apply -f -

echo  [OK] Secrets created.

:: ── Step 4: Apply Kubernetes manifests ───────────────────────────────────────
echo.
echo [4/6] Deploying to Kubernetes...
kubectl apply -f kubernetes/ -n production
if %errorlevel% neq 0 (
    echo  [ERROR] kubectl apply failed.
    pause & exit /b 1
)
echo  [OK] Manifests applied.

echo  Waiting for pod to be ready...
kubectl wait --for=condition=ready pod -l app=amazon-recommender -n production --timeout=120s
if %errorlevel% neq 0 (
    echo  [WARNING] Pod not ready in 120s. Check: kubectl get pods -n production
) else (
    echo  [OK] Pod is running!
)

:: ── Step 5: Install kube-prometheus-stack via Helm ────────────────────────────
echo.
echo [5/6] Installing Prometheus + Grafana via Helm...
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install kube-prometheus prometheus-community/kube-prometheus-stack ^
  --namespace monitoring --create-namespace ^
  --set grafana.adminPassword=admin ^
  --wait --timeout 5m
echo  [OK] Prometheus + Grafana installed.

:: ── Step 6: Port-forward and open ────────────────────────────────────────────
echo.
echo [6/6] Setting up port forwarding...

echo  Starting port-forward for the API (port 8000)...
start "API Port Forward" kubectl port-forward svc/amazon-recommender 8000:80 -n production

echo  Starting port-forward for Grafana (port 3000)...
start "Grafana Port Forward" kubectl port-forward svc/kube-prometheus-grafana 3000:80 -n monitoring

echo  Starting port-forward for Prometheus (port 9090)...
start "Prometheus Port Forward" kubectl port-forward svc/kube-prometheus-kube-prome-prometheus 9090:9090 -n monitoring

timeout /t 3 /nobreak >nul

:: ── Done ──────────────────────────────────────────────────────────────────────
echo.
echo  ============================================================
echo   KUBERNETES DEPLOY COMPLETE!
echo  ============================================================
echo.
echo   API:         http://localhost:8000/docs
echo   Grafana:     http://localhost:3000  (admin / admin)
echo   Prometheus:  http://localhost:9090
echo.
echo   Useful commands:
echo     kubectl get pods -n production
echo     kubectl logs -f deploy/amazon-recommender -n production
echo     kubectl get hpa -n production
echo.
start http://localhost:8000/docs
start http://localhost:3000
pause
