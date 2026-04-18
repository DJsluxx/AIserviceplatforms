-- ============================================================
-- Local-dev Supabase Auth shim.
--
-- In production, PEELED runs on Supabase Postgres, where the `auth`
-- schema (with auth.users and auth.uid()) is provisioned by Supabase.
-- For local docker-compose development, there is no Supabase Auth
-- layer, so we create a minimal stub so the rest of the schema and
-- RLS policies can apply without error.
--
-- This file is alphabetically first in /docker-entrypoint-initdb.d/,
-- so it runs before 0001_init.sql.
-- ============================================================

create schema if not exists auth;

-- Minimal shape of auth.users so FK references resolve locally.
create table if not exists auth.users (
  id uuid primary key default gen_random_uuid(),
  email text,
  created_at timestamptz not null default now()
);

-- Supabase-provided helper: returns the auth uid of the current request.
-- In local dev there is no Supabase session, so we return null, which
-- effectively denies RLS-protected rows unless the connection uses a
-- service-role role that bypasses RLS.
create or replace function auth.uid()
returns uuid
language sql
stable
as $$ select null::uuid $$;

create or replace function auth.role()
returns text
language sql
stable
as $$ select 'authenticated'::text $$;

create or replace function auth.jwt()
returns jsonb
language sql
stable
as $$ select '{}'::jsonb $$;
