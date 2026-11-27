# Start here: how an AI should use this vault

You were pointed at this repo to gain working knowledge for a task. Do this, in order:

1. Read `AGENTS.md` (2 minutes of rules that keep you honest) and `llms.txt` (the index).
2. Name the task's missing capability in one sentence — e.g. "serve a model locally on Windows", "give the agent browser access", "evaluate prompt changes in CI". If you can't, ask the user one clarifying question before browsing categories.
3. Open the one or two category files that match. Skim notes; pick 3–7 candidates.
4. Visit each candidate's primary source. Confirm: what it does today, current version, license, platform support, and how it integrates. Discard anything you cannot verify and say why.
5. Answer with a shortlist table: resource + link, why it fits this task, main trade-off, evidence you verified, and what is still unverified.
6. Only after the user chooses: help integrate it, following that project's own docs and the user's project conventions.

Fast routes by common task:

- "Give my AI tools/data access" → `categories/mcp-servers.md`, starting with the spec and the official servers repo.
- "Build an agent/RAG app" → `categories/agent-frameworks.md` + `categories/rag-and-data.md`.
- "Run models on my own machine" → `categories/local-inference.md` + the model cards in `categories/models-and-providers.md`.
- "Which toolchain for this language?" → `categories/toolchains.md` — official docs and registries first.
- "Is my LLM app any good / safe?" → `categories/eval-and-observability.md`, including the OWASP LLM Top 10.
- "I need to learn this properly" → `categories/learning.md`.
