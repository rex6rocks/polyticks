- **Tech Stack:** Flutter, Supabase (Auth/DB), Riverpod (State).
- **Runtime:** `flutter run` (Development), `dart run build_runner build`
  (CodeGen).
- **Core Rules:**
  - Image compression: Always use `flutter_image_compress` for <150KB.
  - Storage Limit: Admin actions on ID verifications MUST trigger deletion of
    associated files.
- **Entry Points:** `lib/main.dart` -> `lib/screens/auth/login_screen.dart`.
- **Logic Hubs:**
  - Auth: `lib/services/auth_service.dart`.
  - Moderation: `lib/services/admin_moderation_service.dart`.
  - Supabase Wrapper: `lib/core/supabase_client.dart`.
