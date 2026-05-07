import logging
from functools import lru_cache

from langchain_huggingface import HuggingFaceEmbeddings
from langchain_astradb import AstraDBVectorStore

from app.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()


@lru_cache()
def get_embeddings() -> HuggingFaceEmbeddings:
    """
    Load HuggingFace sentence-transformer embeddings.
    Cached so the model is loaded only once per process.
    """
    logger.info(f"Loading embedding model: {settings.hf_embedding_model}")
    return HuggingFaceEmbeddings(
        model_name=settings.hf_embedding_model,
        model_kwargs={"device": "cpu"},
        encode_kwargs={"normalize_embeddings": True},
    )


@lru_cache()
def get_vector_store() -> AstraDBVectorStore:
    """
    Connect to Astra DB and return a LangChain-compatible vector store.
    Cached so the connection is reused across requests.
    """
    logger.info("Connecting to Astra DB vector store...")
    embeddings = get_embeddings()

    store = AstraDBVectorStore(
        embedding=embeddings,
        collection_name=settings.astra_db_collection,
        token=settings.astra_db_application_token,
        api_endpoint=settings.astra_db_api_endpoint,
        namespace=settings.astra_db_keyspace,
    )
    logger.info("Astra DB vector store connected.")
    return store


def get_retriever():
    """Return a LangChain retriever from the vector store."""
    store = get_vector_store()
    return store.as_retriever(
        search_type="similarity",
        search_kwargs={"k": settings.top_k_results},
    )
