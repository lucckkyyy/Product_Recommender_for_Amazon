#!/usr/bin/env bash
# Amazon Product Recommender — Auto Setup (Mac / Linux)
# Usage: chmod +x setup.sh && ./setup.sh

set -euo pipefail
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  [OK]${NC} $1"; }
warn() { echo -e "${YELLOW}  [WARN]${NC} $1"; }
fail() { echo -e "${RED}  [ERROR]${NC} $1"; exit 1; }
info() { echo -e "  [INFO] $1"; }

echo ""
echo "  ============================================================"
echo "   Amazon Product Recommender Chatbot — Auto Setup"
echo "   By: Aryan Rajguru"
echo "  ============================================================"
echo ""

# ── Step 1: Prerequisites ─────────────────────────────────────────────────────
echo "[1/7] Checking prerequisites..."

command -v python3 >/dev/null 2>&1 || fail "Python 3 not found. Install from python.org"
ok "Python: $(python3 --version)"

command -v docker >/dev/null 2>&1 || fail "Docker not found. Install Docker Desktop."
docker info >/dev/null 2>&1 || fail "Docker is not running. Start Docker Desktop first."
ok "Docker is running."

command -v git >/dev/null 2>&1 && GIT_OK=true || { warn "Git not found — GitHub push will be skipped."; GIT_OK=false; }

# ── Step 2: Project directory ─────────────────────────────────────────────────
echo ""
echo "[2/7] Setting up project directory..."
cd "$(dirname "$0")"
ok "Working directory: $(pwd)"

# ── Step 3: .env check ────────────────────────────────────────────────────────
if [[ ! -f ".env" ]]; then
    info ".env not found — copying from .env.example"
    cp .env.example .env
    echo ""
    warn "Please open .env and fill in your credentials, then re-run this script."
    if command -v nano >/dev/null 2>&1; then nano .env
    elif command -v open >/dev/null 2>&1; then open .env
    fi
    exit 0
fi
ok ".env file found."

# ── Step 4: Docker build ──────────────────────────────────────────────────────
echo ""
echo "[3/7] Building Docker image (5–10 min first time)..."
docker compose build
ok "Docker image built."

# ── Step 5: Start services ────────────────────────────────────────────────────
echo ""
echo "[4/7] Starting API + Prometheus + Grafana..."
docker compose up -d
ok "All services started."

# Wait for API health
echo "  Waiting for API to be ready..."
for i in $(seq 1 12); do
    sleep 5
    if curl -sf http://localhost:8000/health >/dev/null 2>&1; then
        ok "API is healthy at http://localhost:8000"
        break
    fi
    info "Still waiting... ($i/12)"
    if [[ $i -eq 12 ]]; then
        fail "API did not start. Run: docker compose logs api"
    fi
done

# ── Step 6: Ingest data ───────────────────────────────────────────────────────
echo ""
echo "[5/7] Ingesting 50,000 Amazon products into Astra DB..."
echo "  (10–20 minutes. Do NOT close this window.)"
docker compose exec -T api python -m app.ingest --limit 50000 \
    && ok "Data ingested!" \
    || warn "Ingestion had warnings. Some data may have loaded. Re-run: docker compose exec api python -m app.ingest"

# ── Step 7: Smoke test ────────────────────────────────────────────────────────
echo ""
echo "[6/7] Smoke test..."
curl -s -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"question": "Recommend a Bluetooth speaker under $30", "chat_history": []}'
echo ""
ok "Smoke test passed."

# ── Step 8: GitHub ────────────────────────────────────────────────────────────
echo ""
echo "[7/7] GitHub setup..."
if [[ "$GIT_OK" == "true" ]]; then
    if [[ ! -d ".git" ]]; then
        git init
        git add .
        git commit -m "feat: Amazon Product Recommender RAG Chatbot"
    fi
    echo ""
    read -rp "  Enter GitHub repo URL (or press Enter to skip): " REPO_URL
    if [[ -n "$REPO_URL" ]]; then
        git remote add origin "$REPO_URL" 2>/dev/null || git remote set-url origin "$REPO_URL"
        git branch -M main
        git push -u origin main && ok "Pushed to GitHub!" || warn "Push failed — check credentials."
    else
        info "GitHub push skipped."
    fi
else
    info "Skipping GitHub (Git not installed)."
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "  ============================================================"
echo "   SETUP COMPLETE!"
echo "  ============================================================"
echo ""
echo "   API Docs:    http://localhost:8000/docs"
echo "   Prometheus:  http://localhost:9090"
echo "   Grafana:     http://localhost:3000  (admin / admin)"
echo ""

# Open browser
if command -v open >/dev/null 2>&1; then          # macOS
    open http://localhost:8000/docs
    open http://localhost:3000
elif command -v xdg-open >/dev/null 2>&1; then    # Linux
    xdg-open http://localhost:8000/docs
    xdg-open http://localhost:3000
fi
