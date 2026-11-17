# Tools

This system is document-driven; the toolbox is deliberately small.
The heavy tools live in their own projects (SeanPak for packaging,
each project's own gate commands in its rule sheet).

| File | What it does |
|---|---|
| [`build-ai-bundle.py`](build-ai-bundle.py) | Regenerates the repo-root `manifest.json` (machine-readable file map + reading order) and `ai-bundle.md` (the whole knowledge base as one file) so AI tools that download the repo — ChatGPT included — can ingest it locally. Run after any content change. Python 3, standard library only. |
