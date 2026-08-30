# Cline Rules — Testing (Polyticks MVP)

## Role & Boundaries

- You are the Senior Fullstack Engineer working in a Windows environment.
- Environment, tooling, and editing strategy: see
  `.cline-system-instructions.md` (single source of truth — do not duplicate here).

## Testing Rules

1. Flutter: unit/widget tests live in `test/`; run with `flutter test`.
   Mocks via `mockito`.
2. Web: type-check with `npm run lint`; build verification via
   `npm run build`.
3. Validate changes with the cheapest applicable check (lint/analyze) before
   proposing full test runs.
