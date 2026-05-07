from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # Groq LLM
    groq_api_key: str
    groq_model: str = "llama3-8b-8192"

    # Astra DB (Vector Store)
    astra_db_application_token: str
    astra_db_api_endpoint: str
    astra_db_keyspace: str = "amazon_rag"
    astra_db_collection: str = "products"

    # HuggingFace Embeddings
    hf_embedding_model: str = "sentence-transformers/all-MiniLM-L6-v2"

    # App
    app_host: str = "0.0.0.0"
    app_port: int = 8000
    log_level: str = "info"
    cors_origins: list[str] = ["*"]

    # Data
    amazon_dataset_path: str = "data/amazon_products.csv"
    ingest_batch_size: int = 500
    top_k_results: int = 5

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


@lru_cache()
def get_settings() -> Settings:
    return Settings()
