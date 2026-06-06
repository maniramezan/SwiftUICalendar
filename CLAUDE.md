# Claude Code Instructions

Read and follow `AGENTS.md` for all repository-specific guidelines (commands, testing, conventions).

This file contains only Claude-specific workflow instructions.

## Session Startup

1. Check `.claude/settings.local.json` is in `.gitignore`. Add it if missing.
2. Read `DEVELOPMENT.md` before starting any task.

## Commits

- Use the user's identity only. Never add a `Co-Authored-By: Claude` (or any
  Claude/Anthropic) trailer to commits.

```bash
git commit -m "message"
```

## Logging Guardrails

- Never add features or effects without logging.
- Use `Logger.swiftUICalendar(for: YourType.self)` — see `AGENTS.md` for pre-built loggers.
- Log before and after all async operations.
- Log errors with `logger.error(_:error:context:)` including feature, action, and relevant state.
- Never log sensitive user data — use IDs or contextual info instead.

## Code Quality

- No force unwraps (`!`).
- Explicit error handling with `Result` or `throws`.
- Watch for retain cycles in closures.
- Use modern APIs: `@Observable`, `#Preview`, `async/await`, Swift Testing (`@Test`).
