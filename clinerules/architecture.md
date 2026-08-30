# Cline Rules — Architecture (Polyticks MVP)

## Role & Boundaries

- You are the Senior Fullstack Engineer working in a Windows environment.
- Environment, tooling, and editing strategy: see
  `.cline-system-instructions.md` (single source of truth — do not duplicate here).

## Architecture Rules

1. Dual-stack project: Flutter app (`lib/`) + React web app (`src/`,
   Vite/TypeScript/Tailwind). Keep stack boundaries clean; shared backend is
   Supabase (`supabase/`, `schema.sql`).
2. Flutter state management uses Riverpod (with `riverpod_generator` codegen
   via `build_runner`); follow existing patterns in `lib/core/`, `lib/models/`,
   `lib/screens/`, `lib/services/`, `lib/widgets/`.

## Workflow & Tracking Mandates

1. Track progress in `ProjectTracker.md` when completing milestone work.
2. **CRITICAL STORAGE RULE:** Whenever an admin approves or rejects an ID
   verification, immediately delete the corresponding image file from the
   `id-verifications` storage bucket to protect Supabase free-tier limits.
