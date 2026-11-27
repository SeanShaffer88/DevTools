# RAG, embeddings, vector databases, and search

Retrieval is usually where LLM apps succeed or fail. Verify chunking, embedding model dimensions, and index types in each system's own docs.

**15 resources.**

- **[Pinecone documentation](https://docs.pinecone.io/)** — _Official docs._ Managed vector database; indexes, namespaces, metadata filtering.
- **[Weaviate documentation](https://docs.weaviate.io/)** — _Official docs._ Open-source vector database with hybrid search and built-in vectorizers.
- **[Qdrant documentation](https://qdrant.tech/documentation/)** — _Official docs._ Open-source vector search engine (Rust), payload filtering, quantization.
- **[Milvus documentation](https://milvus.io/docs)** — _Official docs._ Large-scale open-source vector database from Zilliz.
- **[Chroma documentation](https://docs.trychroma.com/)** — _Official docs._ Lightweight embedding database popular for local RAG prototypes.
- **[pgvector](https://github.com/pgvector/pgvector)** — _Repo._ Vector similarity search inside PostgreSQL — often the simplest production choice if you already run Postgres.
- **[FAISS](https://github.com/facebookresearch/faiss)** — _Repo._ Meta's library for efficient similarity search and clustering of dense vectors.
- **[LanceDB](https://lancedb.github.io/lancedb/)** — _Official docs._ Embedded vector database on the Lance columnar format.
- **[sqlite-vec](https://github.com/asg017/sqlite-vec)** — _Repo._ Vector search extension for SQLite — good for local/offline apps.
- **[Elasticsearch documentation](https://www.elastic.co/docs/reference/elasticsearch)** — _Official docs._ Full-text + vector (kNN) search; BM25 still matters for hybrid retrieval.
- **[OpenAI embeddings guide](https://developers.openai.com/api/docs/guides/embeddings)** — _Official docs._ How embeddings work and which model dimensions to expect.
- **[Sentence Transformers documentation](https://www.sbert.net/)** — _Official docs._ Open embedding models, training, and semantic search recipes.
- **[Unstructured](https://docs.unstructured.io/)** — _Official docs._ Parsing PDFs/Office/HTML into clean elements for ingestion pipelines.
- **[MarkItDown (Microsoft)](https://github.com/microsoft/markitdown)** — _Repo._ Convert Office/PDF/etc. to Markdown for LLM ingestion.
- **[Docling (IBM)](https://github.com/docling-project/docling)** — _Repo._ Document parsing to Markdown/JSON with layout and OCR support.

_Part of [AI Knowledge Vault](../README.md). Verify every resource at its primary source before relying on it._
