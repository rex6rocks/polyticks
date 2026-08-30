# Brain.md

## Flow

- UI (Widgets) -> Riverpod Providers -> Services -> Supabase.

## Data Schema

- Profiles (`public.profiles`): Stores roles, verification status.
- Posts (`public.posts`): Channel-based content.
- Reactions: Auto-syncs counts via DB triggers.

## Known Debt/Fragile

- `schema.sql`: Complex triggers for reactions and profile creation are central
  but hard to debug; keep DB-side and App-side logic in sync.
- Verification Uploads: Fragile process, ensure `id-verifications` bucket is
  managed by `id_verification_service.dart`.
