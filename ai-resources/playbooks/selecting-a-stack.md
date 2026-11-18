# Selecting a stack for a new AI project

A short decision order that prevents most bad picks:

1. **Where will inference run?** Hosted API (fastest to ship; per-token cost; data leaves the machine), local runner (Ollama/llama.cpp/vLLM — privacy, offline, hardware-bound), or hybrid. Decide this before frameworks.
2. **What shape is the app?** Single prompt call → use the provider SDK directly, no framework. Retrieval over documents → RAG stack (ingestion + vector store + framework). Multi-step tool use with state → agent framework (LangGraph, Agents SDK, ADK…). Long-running/durable → check the framework's persistence story explicitly.
3. **Which language is the team/project already in?** Python has the deepest ecosystem; TypeScript (Vercel AI SDK, Mastra) and .NET (Semantic Kernel) are first-class for their stacks. Don't introduce a new runtime for a library.
4. **Tools and data access** → prefer MCP for new integrations so tools are reusable across clients; check the client you will actually use supports the MCP features you need.
5. **Evaluation from day one**: pick one tracing tool and one eval tool (e.g. Langfuse + promptfoo) before the first "it feels better" prompt change.
6. Write down the decision, the alternatives rejected, and the unverified assumptions in the project itself — not just in chat.
