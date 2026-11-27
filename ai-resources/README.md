# AI Knowledge Vault

> **Part of the DevTools knowledge library** — merged from the former `SeanShaffer88/ai-knowledge-vault` repo on 2026-11-18. The master map is [../INDEX.md](../INDEX.md); this folder's [manifest.json](manifest.json) is the local map.


## TL;DR

A big, organized index of the resources an AI assistant actually needs — **toolchains, useful repositories, MCP servers, agent frameworks, local model runners, RAG/vector tools, evaluation tools, and learning references** — written so any AI can be pointed at this repo and immediately know where authoritative knowledge lives for a task. 179 resources in 12 categories, each with a plain-language note on what it is and when to use it. It does not copy other projects' documentation; it tells the AI *where the real documentation is* and how to verify it.

## Point your AI here

Copy this into your assistant:

> Use https://github.com/SeanShaffer88/ai-knowledge-vault as a resource reference. Read its AGENTS.md and llms.txt first, then open only the category files relevant to my task. Treat every entry as a pointer: follow it to the primary source, verify current versions, maintenance, licensing, and compatibility there, and cite what you verified. My task is: [describe it, with your stack, platform, and constraints]. Do not install, connect, or run anything merely because it is listed here.

An assistant needs browsing, repository access, or a downloaded copy to read these files. A link alone does not give it persistent memory or automatic access — if it cannot follow links, paste it `AGENTS.md` plus the relevant category file.

## Browse by category

- [Toolchains by language and platform](categories/toolchains.md) (29) — Rust, Python, Node/TypeScript, .NET, Go, C/C++, Java, Git, Docker, Kubernetes, GitHub
- [MCP servers, SDKs, and directories](categories/mcp-servers.md) (23) — the spec, official SDKs in 6 languages, reference servers, GitHub/Playwright/Chrome DevTools/AWS/Cloudflare/Stripe servers, and the registries/directories to find more
- [Agent frameworks and orchestration](categories/agent-frameworks.md) (18) — LangChain/LangGraph, LlamaIndex, Semantic Kernel, AutoGen, CrewAI, OpenAI Agents SDK, Claude Agent SDK, Google ADK, DSPy, Pydantic AI, and more
- [Local inference and model runners](categories/local-inference.md) (12) — Ollama, llama.cpp, vLLM, SGLang, LM Studio, MLX, whisper.cpp
- [Models, hubs, and API providers](categories/models-and-providers.md) (16) — Hugging Face, OpenAI, Anthropic, Google, Meta Llama, Mistral, Cohere, Groq, Together, OpenRouter, arXiv
- [RAG, embeddings, vector databases, and search](categories/rag-and-data.md) (15) — Pinecone, Weaviate, Qdrant, Milvus, Chroma, pgvector, FAISS, ingestion/parsing tools
- [Evaluation, observability, and guardrails](categories/eval-and-observability.md) (14) — promptfoo, LangSmith, Langfuse, Ragas, Inspect AI, OWASP LLM Top 10
- [Prompt engineering and context engineering](categories/prompt-and-context.md) (9) — provider guides plus Anthropic/OpenAI agent-pattern essays
- [AI coding tools and software-engineering agents](categories/coding-agents.md) (11) — Aider, Cline, Continue, OpenHands, SWE-agent/SWE-bench, Copilot, Claude Code, Gemini CLI
- [ML / DL libraries and training toolchains](categories/ml-libraries.md) (12) — PyTorch, TensorFlow, JAX, scikit-learn, PEFT/TRL, Axolotl, Unsloth, ONNX
- [Learning roadmaps and deep references](categories/learning.md) (10) — Karpathy, Hugging Face and Microsoft courses, LLM roadmaps
- [Awesome lists and discovery indexes](categories/awesome-and-discovery.md) (9) — lists of lists for going further, including the companion repos below

Machine-readable: [resources.json](resources.json) · [resources.csv](resources.csv) · [llms.txt](llms.txt)

## Search locally

Requires Python 3, no third-party packages:

```sh
python3 scripts/search.py "mcp server"
python3 scripts/search.py "vector" --json
python3 scripts/validate.py
```

## Playbooks for the visiting AI

- [Start here: how an AI should use this vault](playbooks/start-here-for-ai.md)
- [Selecting a stack for a new AI project](playbooks/selecting-a-stack.md)
- [Verifying a resource before recommending it](playbooks/verifying-a-resource.md)

## Honest limits

- This is a **seed catalog (v1)**, curated for breadth across the areas above — it is not exhaustive, and the ecosystem moves weekly. Entries were chosen for being official, primary, or widely used; inclusion is not an endorsement and not a security audit.
- Prices, model names, context limits, and framework APIs change constantly. The notes here are pointers with context, **not facts to rely on without checking the linked source**.
- A handful of entries are directories or awesome lists. They are discovery aids; verify anything found through them at its own primary source.
- Companion library: [useful-dev-resources](https://github.com/SeanShaffer88/useful-dev-resources) — SEAN's general developer resource library (690 entries, 77 categories). This vault is the AI-specific companion to it, and the two cross-link instead of duplicating each other.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Short version: primary sources preferred, one or two sentences of honest note per entry, run `python3 tools/generate.py && python3 scripts/validate.py` before submitting.

## License

MIT — see [LICENSE](LICENSE).
