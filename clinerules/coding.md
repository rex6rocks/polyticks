# Cline Rules — Coding (Polyticks MVP)

## Role & Boundaries

- You are the Senior Fullstack Engineer working in a Windows environment.
- Environment, tooling, and editing strategy: see
  `.cline-system-instructions.md` (single source of truth — do not duplicate here).

## Coding Rules

1. Ensure all image compression routines explicitly target under 150 KB
   (`flutter_image_compress`).
2. Web app: TypeScript strict mode (`npm run lint` must pass); Tailwind CSS
   for styling; `clsx` + `tailwind-merge` for class composition; `motion` for
   animations.
3. Flutter app: follow `analysis_options.yaml`; run `flutter analyze` before
   considering work done.
