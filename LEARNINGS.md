# Learnings

> Append-only guardrails the agent discovers while working on this repo.
> Read this before each turn; add new gotchas you hit (one bullet per line).
> A planner turn prunes stale entries periodically. The loop never depends on
> this file — it is advisory memory, not state.

- _(example)_ `npm test` must run from the repo root; a nested cwd makes it red.
- RuboCop `Lint/Syntax` FATALITIES mask all downstream style cops: a file with a parse error reports only syntax offenses, hiding autocorrectable ones (e.g. `Layout/TrailingEmptyLines`) until the syntax is fixed. When fixing a syntax error, expect NEW style offenses to appear post-fix — those belong to the autocorrect sweep (T1.1), not the syntax-fix task.
