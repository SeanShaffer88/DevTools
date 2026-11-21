# Verifying a resource before recommending it

Run these checks at the primary source and report results honestly (Verified / Partially Verified / Unverified):

- **Identity**: is this the official repo/package, or a look-alike? Check the org, links from the official docs, and registry ownership.
- **Maintenance**: latest release date, recent commits/issues activity, and whether deprecation/archival notices exist. Dormant is not automatically bad — say what adopting it would cost.
- **License**: read the actual LICENSE file. Distinguish MIT/Apache/BSD from source-available or non-commercial terms, especially for models (model licenses differ from code licenses).
- **Compatibility**: supported OS, CPU/GPU, runtime and language versions vs. the project's actual targets; for native code, architecture and CRT/linkage.
- **Integration cost**: auth, API keys, rate limits, pricing/quotas for hosted services; data handling (what leaves the machine) for anything cloud-backed.
- **Security**: for MCP servers and agent tools — what can it access or execute, does it need secrets, is the transport local or remote, is there an official alternative?
- **Evidence**: link the exact pages you read. A search snippet or an awesome-list entry is a lead, not evidence.
