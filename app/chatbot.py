import logging
from typing import AsyncGenerator

from langchain_groq import ChatGroq
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
from langchain_core.runnables import RunnablePassthrough
from langchain_core.output_parsers import StrOutputParser
from langchain_core.messages import HumanMessage, AIMessage

from app.config import get_settings
from app.embeddings import get_retriever

logger = logging.getLogger(__name__)
settings = get_settings()

# ---------------------------------------------------------------------------
# System prompt
# ---------------------------------------------------------------------------
SYSTEM_PROMPT = """You are an expert Amazon product recommender assistant. \
Your job is to help users find the best products based on their needs.

Use ONLY the product context provided below to answer questions. \
If the context does not contain relevant products, say you couldn't find a match \
and suggest the user refine their query.

When recommending products:
- List each product with its name, price, rating, and a short description.
- Highlight why each product suits the user's needs.
- If multiple products qualify, rank them by relevance and rating.
- Be concise, friendly, and helpful.

Context (retrieved Amazon products):
{context}
"""


def _format_docs(docs) -> str:
    """Convert retrieved LangChain documents into a readable string."""
    if not docs:
        return "No products found."
    parts = []
    for i, doc in enumerate(docs, 1):
        meta = doc.metadata
        parts.append(
            f"[Product {i}]\n"
            f"Name: {meta.get('product_name', 'N/A')}\n"
            f"Category: {meta.get('category', 'N/A')}\n"
            f"Price: ${meta.get('discounted_price', meta.get('actual_price', 'N/A'))}\n"
            f"Rating: {meta.get('rating', 'N/A')} ({meta.get('rating_count', '0')} reviews)\n"
            f"Description: {doc.page_content[:300]}"
        )
    return "\n\n".join(parts)


def _build_llm() -> ChatGroq:
    return ChatGroq(
        api_key=settings.groq_api_key,
        model=settings.groq_model,
        temperature=0.3,
        streaming=True,
    )


def _build_prompt() -> ChatPromptTemplate:
    return ChatPromptTemplate.from_messages(
        [
            ("system", SYSTEM_PROMPT),
            MessagesPlaceholder(variable_name="chat_history"),
            ("human", "{question}"),
        ]
    )


# ---------------------------------------------------------------------------
# Public interface
# ---------------------------------------------------------------------------

def build_rag_chain():
    """Assemble the full RAG chain (retriever → prompt → LLM → parser)."""
    retriever = get_retriever()
    llm = _build_llm()
    prompt = _build_prompt()

    chain = (
        RunnablePassthrough.assign(
            context=lambda x: _format_docs(retriever.invoke(x["question"]))
        )
        | prompt
        | llm
        | StrOutputParser()
    )
    return chain


def convert_history(raw_history: list[dict]) -> list:
    """Convert a list of {role, content} dicts into LangChain message objects."""
    messages = []
    for msg in raw_history:
        if msg["role"] == "user":
            messages.append(HumanMessage(content=msg["content"]))
        elif msg["role"] == "assistant":
            messages.append(AIMessage(content=msg["content"]))
    return messages


async def stream_response(
    question: str,
    chat_history: list[dict],
    chain,
) -> AsyncGenerator[str, None]:
    """Stream tokens from the RAG chain."""
    lc_history = convert_history(chat_history)
    async for token in chain.astream(
        {"question": question, "chat_history": lc_history}
    ):
        yield token
