# 🛒 Amazon Product Recommender Chatbot
## 📘 Building a Production-Grade RAG System

I created this project to strengthen my understanding of Retrieval-Augmented Generation (RAG), vector databases, and production ML deployment. This chatbot enables natural language search over 50,000+ Amazon electronics products, returning intelligent recommendations powered by a real LLM.

## 🎯 Development Journey

### **Timeline & Approach**
- **Duration**: 2 days of focused engineering
- **Process**: Building end-to-end from raw data ingestion to live API with monitoring
- **Focus**: RAG pipeline design, containerization, and production observability

## 🧠 Skills I Developed Through This Project

### **RAG Pipeline Design**
- Streaming 50,000+ product records from HuggingFace datasets
- Generating dense vector embeddings using HuggingFace sentence-transformers
- Storing and querying embeddings in Astra DB vector store
- Retrieving top-K semantically similar products per user query

### **LLM Integration**
- Connecting LangChain to Groq LLM (llama-3.1-8b-instant)
- Designing a structured system prompt for product recommendation
- Implementing streaming token-by-token responses via FastAPI
- Managing multi-turn conversation history with LangChain message objects

### **API Development**
- Building a production FastAPI application with streaming endpoints
- Implementing liveness and readiness health probes
- Adding Pydantic request/response validation
- Designing async streaming responses with Server-Sent Events

### **Containerization & Orchestration**
- Writing a multi-stage Dockerfile for a lean production image
- Orchestrating API, Prometheus, and Grafana with Docker Compose
- Authoring Kubernetes manifests including Deployment, Service, HPA, and RBAC
- Configuring HorizontalPodAutoscaler for CPU and memory-based scaling

### **Observability & Monitoring**
- Exposing custom Prometheus metrics (request rate, LLM latency, retrieval latency)
- Auto-provisioning a Grafana dashboard with p50/p95/p99 latency panels
- Implementing real-time container health monitoring

## ⚡ Technical Stack

### **What I Built With**
- **LLM**: Groq — llama-3.1-8b-instant
- **RAG Framework**: LangChain
- **Embeddings**: HuggingFace all-MiniLM-L6-v2 (local, no API cost)
- **Vector Store**: DataStax Astra DB (free 5GB tier)
- **API**: FastAPI + Uvicorn
- **Containers**: Docker + Docker Compose
- **Orchestration**: Kubernetes (Minikube locally)
- **Monitoring**: Prometheus + Grafana
- **Dataset**: Amazon Reviews 2023 via HuggingFace Datasets

### **Skills I Leveled Up**
- Vector search and embedding pipelines
- LangChain RAG chain construction
- Docker multi-stage builds
- Kubernetes manifest authoring
- Production API design with streaming
- Real-time observability with Prometheus and Grafana

## 🚀 The Learning Outcome

This project strengthened my ability to architect and deploy a full production ML system from raw data ingestion and vector embedding, to LLM inference and live monitoring. It reflects my growing confidence in MLOps, API engineering, and building AI-powered applications that go beyond notebooks into real deployable systems.

---
*Author: Aryan Rajguru*
