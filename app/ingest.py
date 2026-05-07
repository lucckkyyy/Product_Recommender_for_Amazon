"""
ingest.py — Load Amazon product data from HuggingFace datasets into Astra DB.

Uses: McAuley-Lab/Amazon-Reviews-2023 (free, no Kaggle account needed)

Usage:
    python -m app.ingest [--limit 50000]
"""

import argparse
import logging
import time

from datasets import load_dataset
from langchain_core.documents import Document
from tqdm import tqdm

from app.config import get_settings
from app.embeddings import get_vector_store

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
)
logger = logging.getLogger(__name__)
settings = get_settings()

# HuggingFace dataset — Electronics category (~786K items, fully free)
HF_DATASET = "McAuley-Lab/Amazon-Reviews-2023"
HF_SUBSET  = "raw_meta_Electronics"


def load_hf_data(limit: int | None = None):
    logger.info(f"Streaming dataset {HF_DATASET} / {HF_SUBSET} from HuggingFace ...")
    ds = load_dataset(
        HF_DATASET,
        HF_SUBSET,
        split="full",
        streaming=True,          # no need to download entire dataset
        trust_remote_code=True,
    )
    items = []
    for i, row in enumerate(ds):
        if limit and i >= limit:
            break
        items.append(row)
        if (i + 1) % 10_000 == 0:
            logger.info(f"  Loaded {i+1:,} rows ...")
    logger.info(f"Total rows loaded: {len(items):,}")
    return items


def row_to_document(row: dict) -> Document:
    title       = row.get("title") or ""
    description = " ".join(row.get("description") or [])
    features    = " ".join(row.get("features") or [])
    categories  = " | ".join(row.get("categories") or [])
    price       = str(row.get("price") or "")
    rating      = str(row.get("average_rating") or "")
    rating_num  = str(row.get("rating_number") or "")

    page_content = f"{title}. {features} {description}".strip()[:2000]

    metadata = {
        "product_id":   str(row.get("parent_asin") or ""),
        "product_name": title,
        "category":     categories,
        "price":        price,
        "rating":       rating,
        "rating_count": rating_num,
        "store":        str(row.get("store") or ""),
        "img_link":     (row.get("images") or [{}])[0].get("large", "") if isinstance((row.get("images") or [{}]), list) else "",
    }
    return Document(page_content=page_content, metadata=metadata)


def ingest(rows: list[dict], batch_size: int) -> None:
    store = get_vector_store()
    total = len(rows)
    logger.info(f"Ingesting {total:,} documents in batches of {batch_size} ...")

    for start in tqdm(range(0, total, batch_size), unit="batch"):
        batch = rows[start : start + batch_size]
        docs  = [row_to_document(r) for r in batch]
        try:
            store.add_documents(docs)
        except Exception as exc:
            logger.error(f"Batch {start} failed: {exc}")
            time.sleep(2)

    logger.info("✅ Ingestion complete.")


def main():
    parser = argparse.ArgumentParser(description="Ingest Amazon products into Astra DB")
    parser.add_argument("--limit",      type=int, default=50_000,
                        help="Max rows to ingest (default: 50,000 — fast & free)")
    parser.add_argument("--batch-size", type=int, default=settings.ingest_batch_size)
    args = parser.parse_args()

    rows = load_hf_data(args.limit)
    ingest(rows, args.batch_size)


if __name__ == "__main__":
    main()
