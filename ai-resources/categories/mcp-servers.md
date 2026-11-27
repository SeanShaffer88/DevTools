# MCP servers, SDKs, and directories

Model Context Protocol: the standard way to give an AI tools and data. Start at the spec, use official SDKs, and treat every server as code that runs with real permissions — verify source, scope, and maintainer before connecting one.

**23 resources.**

- **[Model Context Protocol — modelcontextprotocol.io](https://modelcontextprotocol.io/)** — _Spec / official docs._ Protocol spec, concepts (tools/resources/prompts), transports, and security guidance. Read this first.
- **[MCP specification (GitHub)](https://github.com/modelcontextprotocol/modelcontextprotocol)** — _Repo._ Spec source, schemas, and proposals.
- **[Official MCP servers](https://github.com/modelcontextprotocol/servers)** — _Repo._ Reference servers: filesystem, fetch, git, memory, sequential-thinking, time, everything (test server), plus archived servers list.
- **[MCP Registry](https://registry.modelcontextprotocol.io/)** — _Registry._ Official community registry for discovering public MCP servers.
- **[MCP Registry (GitHub)](https://github.com/modelcontextprotocol/registry)** — _Repo._ Registry API and publishing process.
- **[MCP Python SDK](https://github.com/modelcontextprotocol/python-sdk)** — _Repo / SDK._ Official Python SDK (FastMCP-style server/client) for building MCP servers.
- **[MCP TypeScript SDK](https://github.com/modelcontextprotocol/typescript-sdk)** — _Repo / SDK._ Official TypeScript SDK for servers and clients.
- **[MCP C# SDK](https://github.com/modelcontextprotocol/csharp-sdk)** — _Repo / SDK._ Official .NET SDK, maintained with Microsoft.
- **[MCP Rust SDK](https://github.com/modelcontextprotocol/rust-sdk)** — _Repo / SDK._ Official Rust SDK (rmcp).
- **[MCP Go SDK](https://github.com/modelcontextprotocol/go-sdk)** — _Repo / SDK._ Official Go SDK, maintained with Google.
- **[MCP Java SDK](https://github.com/modelcontextprotocol/java-sdk)** — _Repo / SDK._ Official Java SDK, built on Spring AI infrastructure.
- **[GitHub MCP Server](https://github.com/github/github-mcp-server)** — _Repo / server._ GitHub's official MCP server: repos, issues, PRs, Actions. Prefer this over scraping GitHub.
- **[Playwright MCP](https://github.com/microsoft/playwright-mcp)** — _Repo / server._ Microsoft's MCP server for browser automation via Playwright accessibility snapshots.
- **[Chrome DevTools MCP](https://github.com/ChromeDevTools/chrome-devtools-mcp)** — _Repo / server._ Official Chrome DevTools MCP server for debugging, traces, and network inspection.
- **[AWS MCP servers (awslabs)](https://github.com/awslabs/mcp)** — _Repo / server collection._ AWS's suite of MCP servers for AWS services, docs, and architecture guidance.
- **[Cloudflare MCP servers](https://github.com/cloudflare/mcp-server-cloudflare)** — _Repo / server._ Cloudflare's remote MCP servers for Workers, DNS, observability, and more.
- **[Stripe Agent Toolkit](https://github.com/stripe/ai)** — _Repo._ Stripe's official tools for agents, including MCP integration for payments APIs.
- **[Awesome MCP Servers](https://github.com/punkpeye/awesome-mcp-servers)** — _Curated list._ Large community list of MCP servers by category; a discovery aid — verify each server before use.
- **[MCP.so](https://mcp.so/)** — _Directory._ Community directory of MCP servers and clients with categories.
- **[Glama MCP directory](https://glama.ai/mcp/servers)** — _Directory._ Searchable MCP server directory with listings and metadata.
- **[Smithery](https://smithery.ai/)** — _Directory / registry._ Hosted MCP server discovery and connection service.
- **[PulseMCP](https://www.pulsemcp.com/)** — _Directory._ MCP server directory and weekly newsletter tracking the ecosystem.
- **[MCP clients list](https://modelcontextprotocol.io/clients)** — _Official docs._ Which clients support which MCP features — check before assuming a client supports resources/prompts/sampling.

_Part of [AI Knowledge Vault](../README.md). Verify every resource at its primary source before relying on it._
