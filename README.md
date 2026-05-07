# 🛒 Amazon Product Recommender Chatbot

A **context-aware RAG chatbot** that searches 500K+ Amazon products using plain natural language.  
Built with **LangChain**, **Groq LLM**, **HuggingFace embeddings**, and **Astra DB** as the vector store.  
Containerised with **Docker**, orchestrated on **GCP via Kubernetes**, and monitored with **Prometheus + Grafana**.

---

## Architecture

```
User Query
    │
    ▼
FastAPI (/chat)
    │
    ├─► HuggingFace Embeddings  ──► Astra DB (Vector Search)
    │          (all-MiniLM-L6-v2)        (top-K products)
    │
    ├─► LangChain RAG Chain
    │       └─► Groq LLM (llama3-70b)
    │
    └─► Streaming Response (SSE)
         │
         ▼
    Prometheus ──► Grafana Dashboard
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| API | FastAPI + Uvicorn |
| LLM | Groq — `llama3-70b-8192` |
| RAG Framework | LangChain |
| Embeddings | HuggingFace `all-MiniLM-L6-v2` |
| Vector Store | Astra DB (DataStax) |
| Containerisation | Docker (multi-stage build) |
| Orchestration | Kubernetes on GCP (GKE) |
| Autoscaling | HPA (CPU + Memory) |
| Observability | Prometheus + Grafana |
| Dataset | [Amazon Sales Dataset](https://www.kaggle.com/datasets/karkavelrajaj/amazon-sales-dataset) — 500K+ products |

---

## Quick Start (Local)

### 1. Clone & configure

```bash
git clone https://github.com/YOUR_USERNAME/amazon-recommender.git
cd amazon-recommender
cp .env.example .env
# Edit .env with your Groq and Astra DB credentials
```

### 2. Download the dataset

Download the [Amazon Sales Dataset](https://www.kaggle.com/datasets/karkavelrajaj/amazon-sales-dataset) CSV and place it at:

```
data/amazon_products.csv
```

### 3. Run with Docker Compose

```bash
# Build and start all services
docker compose up --build

# In a separate terminal, ingest data into Astra DB (one-time)
docker compose exec api python -m app.ingest --path data/amazon_products.csv

# API: http://localhost:8000
# Prometheus: http://localhost:9090
# Grafana: http://localhost:3000  (admin / admin)
```

### 4. Chat with the API

```bash
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"question": "Recommend a good Bluetooth speaker under $30", "chat_history": []}' \
  --no-buffer
```

---

## Running Locally (without Docker)

```bash
python -m venv venv
source venv/bin/activate          # Windows: venv\Scripts\activate
pip install -r requirements.txt

# Ingest data (once)
python -m app.ingest

# Start the API
uvicorn app.main:app --reload --port 8000
```

---

## Data Ingestion

```bash
# Ingest all rows
python -m app.ingest --path data/amazon_products.csv

# Ingest first 10,000 rows for testing
python -m app.ingest --path data/amazon_products.csv --limit 10000

# Custom batch size
python -m app.ingest --batch-size 200
```

---

## API Reference

| Method | Path | Description |
|---|---|---|
| `POST` | `/chat` | Stream a RAG chat response |
| `GET` | `/health` | Liveness probe |
| `GET` | `/ready` | Readiness probe (checks Astra DB) |
| `GET` | `/metrics` | Prometheus metrics |
| `GET` | `/docs` | Interactive API docs (Swagger UI) |

### POST `/chat` payload

```json
{
  "question": "Best laptop for video editing under $1000?",
  "chat_history": [
    {"role": "user",      "content": "I need something powerful"},
    {"role": "assistant", "content": "Sure! What's your budget?"}
  ],
  "session_id": "optional-uuid"
}
```

---

## Kubernetes Deployment (GCP / GKE)

### 1. Build and push the image

```bash
export PROJECT_ID=your-gcp-project-id
docker build -t gcr.io/$PROJECT_ID/amazon-recommender:latest .
docker push gcr.io/$PROJECT_ID/amazon-recommender:latest
```

### 2. Create the namespace

```bash
kubectl create namespace production
```

### 3. Create secrets

```bash
kubectl create secret generic amazon-recommender-secrets \
  --from-literal=GROQ_API_KEY=gsk_... \
  --from-literal=ASTRA_DB_APPLICATION_TOKEN=AstraCS:... \
  --from-literal=ASTRA_DB_API_ENDPOINT=https://...astra.datastax.com \
  --namespace production
```

### 4. Apply manifests

```bash
# Update the image name in kubernetes/deployment.yaml first
kubectl apply -f kubernetes/ -n production
```

### 5. Verify

```bash
kubectl get pods -n production
kubectl logs -f deploy/amazon-recommender -n production
kubectl get hpa -n production
```

---

## Observability

### Prometheus metrics exposed

| Metric | Type | Description |
|---|---|---|
| `http_requests_total` | Counter | Total HTTP requests by method/path/status |
| `http_request_duration_seconds` | Histogram | Full request latency |
| `llm_latency_seconds` | Histogram | Time to first token (TTFT) |
| `retrieval_latency_seconds` | Histogram | Astra DB retrieval time |
| `chat_requests_total` | Counter | Chat requests by status (success/error) |

### Grafana dashboard

The dashboard is provisioned automatically at `http://localhost:3000`.  
It shows request rate, error rate, p50/p95/p99 latency, TTFT, and retrieval latency.

---

## Tests

```bash
pytest tests/ -v
```

---

## Project Structure

```
amazon-recommender/
├── app/
│   ├── __init__.py
│   ├── config.py          # Pydantic settings
│   ├── embeddings.py      # HuggingFace + Astra DB vector store
│   ├── chatbot.py         # LangChain RAG chain + Groq LLM
│   ├── ingest.py          # Data ingestion script
│   └── main.py            # FastAPI application
├── kubernetes/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── configmap-and-secret.yaml
│   ├── hpa.yaml
│   └── rbac.yaml
├── monitoring/
│   ├── prometheus.yml
│   └── grafana/
│       ├── provisioning/
│       └── dashboards/
├── tests/
│   └── test_api.py
├── Dockerfile
├── docker-compose.yml
├── requirements.txt
├── pytest.ini
├── .env.example
└── .gitignore
```

---

## License

MIT
