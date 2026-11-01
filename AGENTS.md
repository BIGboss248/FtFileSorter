# AGENTS.md

Operating contract for AI agents working in this repository.

## Engineering standards

All non-trivial work follows the algorithm-first, functional-programming
baseline in [`.agents/rules/engineering-standards.md`](.agents/rules/engineering-standards.md),
which is also loaded through `instructions` in `opencode.json`. Read it before
planning a feature or a fix. The non-negotiables:

- State the algorithm and its edge cases before writing the code.
- Put business logic in pure, deterministic functions; keep I/O, network,
  filesystem access, and state mutation in a thin imperative shell.
- Keep functions small, explicitly typed, and free of hidden dependencies,
  shared mutable state, and mutation of arguments.
- A bug fix ships with a regression test; run the documented test gate and
  report the real command output — never claim a pass without executing it.
- Make the smallest change that satisfies the task: no unrelated refactoring
  and no speculative abstractions.
- Close with the completion report defined in §9 of the standard.

## Code review (`reviewer` subagent)

Before reporting a change as complete, run the read-only `reviewer` subagent on
the diff (`/review`, or "use the reviewer subagent on the current diff"). Review
base branch: `main`, compared as `origin/main` when the working branch is
`main`.

- The reviewer never edits files, runs tests, or writes the report; it returns
  the report in chat.
- Resolve every Blocker, Critical, and High finding before calling the change
  complete. A Medium finding may ship only with its accepted risk recorded in §9
  of the saved report; Low and Nit findings may ship as noted. Re-run the review
  after the fix.
- The reviewer cannot certify the test gate — run it yourself.
- Save the report to `docs/reviews/YYYY-MM-DD-<slug>.md` when the change is
  accepted; add `-2`, `-3` for further reviews on the same day. Format:
  `.agents/rules/code-review-report.md`.
