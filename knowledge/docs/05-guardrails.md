# 05 — Guardrails (the 19-point contract, as adopted)

The owner's AI Coding Guardrails & Operating Contract, adopted
exactly as written, with three overrides the owner chose explicitly.
The points, in operative form:

1. **No unvetted dependencies** — and per override (3) below, every
   new external dependency needs the owner's explicit approval
   before introduction.
2. **Follow existing patterns** in the codebase before inventing new
   ones.
3. **Zero secrets** in code, logs, docs, or commits.
4. **Default-deny** for auth and data access.
5. **Test-driven, checkable verification** — claims carry evidence.
6. **No `unwrap`/`expect`** (or their equivalents) in production
   paths.
7. **Three-strike failure stop** — after three failed attempts at
   the same approach, stop, reassess, and change route instead of
   persisting. (A proven route beats a fifth retry of a failing
   one.)
8. **Human gate for destructive actions** — deletes, overwrites,
   and system changes are confirmed first; permanent deletes always
   ask, and any "stop asking" preference is its own separate,
   described decision.
9. **Fresh context for distinct tasks** — don't let one task's
   assumptions leak into another.
10. **Living documentation** — docs change in the same change as the
    thing they describe.
11. **No unrequested refactoring.**
12. **Surgical diffs** — the smallest change that does the job.
13. **Complete files for new code** — no placeholder stubs shipped
    as finished.
14. **Readiness verification** before initializing or resuming a
    project: check scope, current code, live remote state, and
    pending approvals first.
15. **Documentation synchronization per release** — README, About,
    topics, and docs re-checked at every release (docs/09).
16. **Competitive feature integration without bloat** — adopt what
    leaders prove valuable; refuse feature creep.
17. **Concise reporting** — what was done and why, in as few words
    as possible.
18. **Progress on every task** — per override (2) below.
19. **Execution velocity** — keep moving; use waiting time on the
    next slice's preparation instead of idling.

## The owner's three overrides

1. **Git autonomy, with a gate.** Commit, pull, branch, and publish
   mechanics proceed without asking. **Merging, tagging, and
   cutting a release each need the owner's explicit say-so for that
   instance** (2026-11-13, superseding the earlier full-autonomy
   grant for those three steps).
2. **Progress % and an estimate on every active task**, even when
   the estimate is rough — plus a progress update every 5 minutes
   during any long-running job.
3. **Dependency approval.** Every new external dependency needs the
   owner's explicit approval before it is introduced, on top of
   the Elite Prompt's justify/register/exit-sketch duties.
