"""
main.py — FastAPI application entry point.

Endpoints:
  POST /chat          — Streaming RAG chat
  GET  /health        — Liveness probe
  GET  /ready         — Readiness probe (checks vector store)
  GET  /metrics       — Prometheus metrics (via prometheus-fastapi-instrumentator)
"""

import logging
import time
import uuid
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse, JSONResponse
from pydantic import BaseModel, Field
from prometheus_fastapi_instrumentator import Instrumentator
from prometheus_client import Counter, Histogram

from app.config import get_settings
from app.chatbot import build_rag_chain, stream_response
from app.embeddings import get_vector_store

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
)
logger = logging.getLogger(__name__)
settings = get_settings()

# ---------------------------------------------------------------------------
# Custom Prometheus metrics
# ---------------------------------------------------------------------------
CHAT_REQUESTS = Counter(
    "chat_requests_total",
    "Total number of chat requests",
    ["status"],
)
RETRIEVAL_LATENCY = Histogram(
    "retrieval_latency_seconds",
    "Time spent retrieving documents from Astra DB",
    buckets=[0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0],
)
LLM_LATENCY = Histogram(
    "llm_latency_seconds",
    "Time for the LLM to produce the first token (TTFT)",
    buckets=[0.1, 0.25, 0.5, 1.0, 2.0, 5.0, 10.0],
)

# ---------------------------------------------------------------------------
# App lifecycle
# ---------------------------------------------------------------------------
_rag_chain = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global _rag_chain
    logger.info("Starting up — building RAG chain ...")
    _rag_chain = build_rag_chain()
    logger.info("RAG chain ready ✅")
    yield
    logger.info("Shutting down.")


# ---------------------------------------------------------------------------
# FastAPI app
# ---------------------------------------------------------------------------
app = FastAPI(
    title="Amazon Product Recommender API",
    description=(
        "Context-aware RAG chatbot that searches 500 K+ Amazon products "
        "using natural language. Powered by LangChain, Groq LLM, HuggingFace "
        "embeddings, and Astra DB."
    ),
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Attach Prometheus instrumentation (exposes /metrics automatically)
Instrumentator().instrument(app).expose(app)


# ---------------------------------------------------------------------------
# Request / Response models
# ---------------------------------------------------------------------------
class ChatMessage(BaseModel):
    role: str = Field(..., pattern="^(user|assistant)$")
    content: str


class ChatRequest(BaseModel):
    question: str = Field(..., min_length=1, max_length=1000)
    chat_history: list[ChatMessage] = Field(default_factory=list)
    session_id: str = Field(default_factory=lambda: str(uuid.uuid4()))


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.get("/health", tags=["observability"])
async def health():
    """Liveness probe — always returns 200 if the process is up."""
    return {"status": "ok"}


@app.get("/ready", tags=["observability"])
async def ready():
    """
    Readiness probe — verifies the vector store connection before
    Kubernetes routes traffic to this pod.
    """
    try:
        store = get_vector_store()
        # Lightweight similarity search to confirm the connection
        store.similarity_search("test", k=1)
        return {"status": "ready"}
    except Exception as exc:
        logger.error(f"Readiness check failed: {exc}")
        raise HTTPException(status_code=503, detail="Vector store unavailable")


@app.post("/chat", tags=["chat"])
async def chat(request: ChatRequest, req: Request):
    """
    Stream a RAG-powered response for the user's question.

    The response is an SSE / chunked text stream so the frontend can
    display tokens as they arrive.
    """
    if _rag_chain is None:
        raise HTTPException(status_code=503, detail="RAG chain not initialised yet")

    logger.info(
        f"[{request.session_id}] Q: {request.question[:80]!r} "
        f"(history={len(request.chat_history)})"
    )
    CHAT_REQUESTS.labels(status="received").inc()

    history_dicts = [m.model_dump() for m in request.chat_history]

    async def token_generator():
        start = time.perf_counter()
        first_token = True
        try:
            async for token in stream_response(
                request.question, history_dicts, _rag_chain
            ):
                if first_token:
                    LLM_LATENCY.observe(time.perf_counter() - start)
                    first_token = False
                yield token
            CHAT_REQUESTS.labels(status="success").inc()
        except Exception as exc:
            CHAT_REQUESTS.labels(status="error").inc()
            logger.error(f"[{request.session_id}] Stream error: {exc}")
            yield f"\n\n[Error: {exc}]"

    return StreamingResponse(token_generator(), media_type="text/plain")


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(status_code=500, content={"detail": "Internal server error"})
