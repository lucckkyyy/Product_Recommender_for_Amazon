"""
tests/test_api.py — Integration tests for the FastAPI application.

Run with:
    pytest tests/ -v
"""

import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from httpx import AsyncClient, ASGITransport

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(autouse=True)
def mock_vector_store():
    """Prevent any real Astra DB connection during tests."""
    with patch("app.embeddings.get_vector_store") as mock:
        store = MagicMock()
        store.similarity_search.return_value = []
        store.as_retriever.return_value = MagicMock(
            invoke=MagicMock(return_value=[])
        )
        mock.return_value = store
        yield store


@pytest.fixture(autouse=True)
def mock_embeddings():
    """Prevent loading the HuggingFace model during tests."""
    with patch("app.embeddings.get_embeddings") as mock:
        mock.return_value = MagicMock()
        yield mock


@pytest.fixture(autouse=True)
def mock_groq():
    """Prevent real Groq API calls during tests."""
    async def fake_astream(*args, **kwargs):
        for token in ["Here ", "are ", "some ", "products ", "for ", "you."]:
            yield token

    with patch("app.chatbot.ChatGroq") as mock_cls:
        llm = MagicMock()
        llm.astream = fake_astream
        mock_cls.return_value = llm
        yield llm


@pytest.fixture()
async def client():
    from app.main import app
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_health(client):
    resp = await client.get("/health")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}


@pytest.mark.asyncio
async def test_ready(client, mock_vector_store):
    resp = await client.get("/ready")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ready"


@pytest.mark.asyncio
async def test_chat_streams_response(client):
    payload = {
        "question": "Recommend a good wireless headphone under $50",
        "chat_history": [],
    }
    resp = await client.post("/chat", json=payload)
    assert resp.status_code == 200
    assert len(resp.text) > 0


@pytest.mark.asyncio
async def test_chat_with_history(client):
    payload = {
        "question": "What about something with noise cancellation?",
        "chat_history": [
            {"role": "user", "content": "Show me wireless headphones"},
            {"role": "assistant", "content": "Here are some options..."},
        ],
    }
    resp = await client.post("/chat", json=payload)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_chat_empty_question_rejected(client):
    payload = {"question": "", "chat_history": []}
    resp = await client.post("/chat", json=payload)
    assert resp.status_code == 422        # Pydantic min_length validation


@pytest.mark.asyncio
async def test_metrics_endpoint(client):
    resp = await client.get("/metrics")
    assert resp.status_code == 200
    assert "http_requests_total" in resp.text
