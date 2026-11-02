# Ultimate Player Database

A historical database and analytics platform for competitive ultimate frisbee.

## Stack

- Next.js App Router, React, TypeScript
- Tailwind CSS
- Supabase / PostgreSQL
- Vercel

## Local development

1. Install Node.js 20.9+.
2. Install dependencies: `npm install`.
3. Copy `.env.example` to `.env.local` and add the Supabase project URL and publishable key.
4. Start the development server: `npm run dev`.

## Project conventions

- Keep route files in `app/`; shared application code in `app/lib`, `app/components`, and domain modules.
- Keep database migrations in `supabase/migrations` and commit every schema change.
- Use internal UUIDs for canonical entities. External provider identifiers belong in source identity mapping tables.
- Preserve historical relationships with effective dates; do not overwrite prior team memberships or event participation.
- Store data provenance and verification status for imported and manually maintained records.
- Keep analytics outputs versioned and reproducible. Do not mix rating algorithm versions.
- Use server components by default. Add client components only for browser interactivity.
- Never commit secrets. The service-role key must remain server-side.

## Roadmap

See `docs/architecture/ROADMAP.md` and `docs/architecture/DATA_MODEL.md`.
