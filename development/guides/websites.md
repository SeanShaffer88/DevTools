# Websites

Original workflow and a dependency-free local example. Local page checks do not establish production hosting, authentication or accessibility compliance.

## Intake and architecture

Choose semantic HTML/CSS and a small script when the interaction fits. Add a framework for a concrete routing/state/team need. Decide static publishing, server rendering or authenticated service before selecting deployment tools. A frontend cannot keep a secret or authorize a privileged backend operation.

List user tasks, pages, browser support, content ownership, privacy, offline expectations and hosting constraints. Separate content/data, presentation and server authority. Design loading, empty, error and cancellation states before fetch logic. Progressive enhancement should preserve core content and navigation when scripts fail.

## Build a small working surface

The [three-file example](../templates/websites/index.html) contains no dependencies, network, persistence or telemetry. Copy it to a new destination before adapting it. It uses labels, a status region and text-only dynamic rendering. These demonstrate techniques rather than certify the result. Avoid remote fonts and trackers by default.

For a plain page, local opening can test basic behavior; file origins differ from HTTP for modules and security rules. For a package-managed project, inspect declared scripts, lockfile and runtime versions before invoking existing test/build entrypoints. Unreviewed package scripts are executable code. Offline builds need a complete dependency cache and compatible tools, not an unexplained copied node_modules tree.

## Verification and trust

Check semantic structure, keyboard sequence, zoom/reflow, focus visibility, reduced motion, forced colors, useful errors and actual browser behavior. Use textContent for page/user text. Treat HTML rendering and URL navigation as distinct trust boundaries. Accounts require server-side authentication/authorization, bounded uploads and deliberate session/CSRF handling. Do not put privileged credentials in browser storage.

Measure production payloads, image dimensions, layout shifts and interaction latency. Retry requests within a finite budget and handle cancellation. Service-worker caching needs explicit privacy, update and rollback rules; do not cache private responses indiscriminately. Offline UI and offline business capability are separate requirements.

## Release and evidence

Require reproducible output, link checks, production-host headers, privacy review, fallback behavior and rollback. Verify DNS/TLS/hosting separately. Browser fixture tests do not prove deployment. Record exact build commands, browser versions, accessibility observations, network requests and remaining gaps. Reuse existing [quality resources](../../resources/index.json) without executing their adapters automatically.

Official API context checked 2026-11-21: [MDN status role](https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/status_role). A status region announces updates without needing a focus jump; the sample retains the user's interaction focus. No vendor text is reproduced.
