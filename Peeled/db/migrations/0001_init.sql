-- PEELED — initial schema
-- Postgres 15+ (Supabase). Assumes `auth.users` from Supabase Auth exists.

-- ============================================================
-- Extensions
-- ============================================================
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";
create extension if not exists "pg_trgm";
create extension if not exists "postgis";   -- for geo matching
create extension if not exists "citext";

-- ============================================================
-- Enums
-- ============================================================
do $$ begin
  create type rarity as enum ('common','uncommon','rare','epic','legendary','mythic');
exception when duplicate_object then null; end $$;

do $$ begin
  create type package_status as enum ('in_flight','completed','abandoned','expired_to_void');
exception when duplicate_object then null; end $$;

do $$ begin
  create type layer_type as enum ('hint','mini_reward','powerup','trap','final');
exception when duplicate_object then null; end $$;

do $$ begin
  create type package_event_type as enum (
    'created','sent','received','peeled','passed','expired_hop','completed','abandoned','rarity_downgraded'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type powerup_kind as enum ('peek','slowdown','double_dip','streak_freeze');
exception when duplicate_object then null; end $$;

do $$ begin
  create type notification_category as enum (
    'package_arriving','legendary_chase','friend_activity','streak_reminder','seasonal_launch'
  );
exception when duplicate_object then null; end $$;

-- ============================================================
-- users (app-side profile; auth.users holds identity)
-- ============================================================
create table if not exists users (
  id uuid primary key references auth.users(id) on delete cascade,
  username citext unique not null,
  display_name text,
  avatar_id text,                   -- key into avatar sprite library
  frame_id text,                    -- equipped frame
  country_code char(2),             -- ISO-3166
  city_hint text,                   -- coarse, obfuscated ~0.1° round
  city_lat double precision,
  city_lng double precision,
  xp bigint not null default 0,
  level int not null generated always as (greatest(1, floor(sqrt(xp / 100.0))::int + 1)) stored,
  coins bigint not null default 100,
  tokens bigint not null default 0,
  streak_days int not null default 0,
  streak_last_date date,
  reputation_score int not null default 50 check (reputation_score between 0 and 100),
  notification_prefs jsonb not null default jsonb_build_object(
    'package_arriving', true,
    'legendary_chase', true,
    'friend_activity', true,
    'streak_reminder', true,
    'seasonal_launch', true,
    'quiet_hours_start', 0,
    'quiet_hours_end', 7
  ),
  privacy_prefs jsonb not null default jsonb_build_object(
    'share_default', 'public',
    'show_on_globe', true,
    'discoverable_by_username', true
  ),
  is_banned boolean not null default false,
  is_shadow_banned boolean not null default false,
  onboarded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists users_country_idx on users(country_code);
create index if not exists users_reputation_idx on users(reputation_score);
create index if not exists users_shadow_idx on users(is_shadow_banned) where is_shadow_banned;

-- ============================================================
-- inventory — unified bag for coins/tokens are in users, this is for stacked items
-- ============================================================
create table if not exists inventory_items (
  user_id uuid not null references users(id) on delete cascade,
  item_kind text not null,           -- 'sticker:bronze_01', 'frame:cosmic_halo', 'powerup:peek'
  count int not null default 0 check (count >= 0),
  acquired_at timestamptz not null default now(),
  primary key (user_id, item_kind)
);

-- ============================================================
-- seasons
-- ============================================================
create table if not exists seasons (
  id int primary key,
  slug text unique not null,
  name text not null,
  theme text not null,               -- 'cosmic_cardboard', 'paper_lanterns', ...
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  config jsonb not null default '{}'::jsonb
);

-- ============================================================
-- packages (current state — event-sourced from package_events)
-- ============================================================
create table if not exists packages (
  id uuid primary key default uuid_generate_v4(),
  rarity rarity not null,
  theme text not null default 'launch',
  season_id int references seasons(id),
  total_layers int not null check (total_layers between 3 and 12),
  peels_done int not null default 0 check (peels_done >= 0),
  prize_id uuid,                                   -- filled when completed
  status package_status not null default 'in_flight',
  origin_user_id uuid references users(id),
  current_holder_id uuid references users(id),
  current_holder_deadline timestamptz,
  current_holder_since timestamptz,
  hops_count int not null default 0,
  is_sponsored boolean not null default false,
  sponsor_id text,
  is_legendary_chase boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  check (peels_done <= total_layers)
);

create index if not exists packages_holder_idx on packages(current_holder_id) where status = 'in_flight';
create index if not exists packages_deadline_idx on packages(current_holder_deadline) where status = 'in_flight';
create index if not exists packages_rarity_idx on packages(rarity);
create index if not exists packages_legendary_idx on packages(is_legendary_chase) where is_legendary_chase;
create index if not exists packages_origin_idx on packages(origin_user_id);

-- Trigger to update updated_at
create or replace function touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists packages_touch on packages;
create trigger packages_touch before update on packages
  for each row execute function touch_updated_at();

drop trigger if exists users_touch on users;
create trigger users_touch before update on users
  for each row execute function touch_updated_at();

-- ============================================================
-- package_events (append-only source of truth)
-- ============================================================
create table if not exists package_events (
  id bigserial primary key,
  package_id uuid not null references packages(id) on delete cascade,
  event_type package_event_type not null,
  actor_user_id uuid references users(id),
  related_user_id uuid references users(id),
  from_lat double precision,
  from_lng double precision,
  to_lat double precision,
  to_lng double precision,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists pkg_events_pkg_idx on package_events(package_id, created_at);
create index if not exists pkg_events_type_idx on package_events(event_type, created_at);

-- ============================================================
-- package_layers (pre-generated; RLS blocks client reads)
-- ============================================================
create table if not exists package_layers (
  package_id uuid not null references packages(id) on delete cascade,
  layer_index int not null check (layer_index >= 0),
  layer_type layer_type not null,
  content jsonb not null,
  reveal_copy text,
  primary key (package_id, layer_index)
);

-- ============================================================
-- peels (one row per peel action)
-- ============================================================
create table if not exists peels (
  id bigserial primary key,
  package_id uuid not null references packages(id) on delete cascade,
  user_id uuid not null references users(id),
  layer_index int not null,
  layer_type layer_type not null,
  reward_payload jsonb not null default '{}'::jsonb,
  was_final boolean not null default false,
  time_to_peel_ms int,                   -- how quickly user peeled after receive
  action_nonce text not null,
  created_at timestamptz not null default now(),
  unique (action_nonce)
);

create index if not exists peels_user_idx on peels(user_id, created_at desc);
create index if not exists peels_pkg_idx on peels(package_id, layer_index);

-- ============================================================
-- friendships (directed follow edges)
-- ============================================================
create table if not exists friendships (
  follower_id uuid not null references users(id) on delete cascade,
  followee_id uuid not null references users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followee_id),
  check (follower_id <> followee_id)
);

create index if not exists friendships_followee_idx on friendships(followee_id);

-- ============================================================
-- blocks
-- ============================================================
create table if not exists blocks (
  blocker_id uuid not null references users(id) on delete cascade,
  blocked_id uuid not null references users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

-- ============================================================
-- device tokens (FCM)
-- ============================================================
create table if not exists device_tokens (
  user_id uuid not null references users(id) on delete cascade,
  fcm_token text not null,
  platform text not null check (platform in ('ios','android','web')),
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  primary key (fcm_token)
);

create index if not exists device_tokens_user_idx on device_tokens(user_id);

-- ============================================================
-- notifications_sent (dedup + cap)
-- ============================================================
create table if not exists notifications_sent (
  id bigserial primary key,
  user_id uuid not null references users(id) on delete cascade,
  category notification_category not null,
  package_id uuid references packages(id) on delete set null,
  sent_at timestamptz not null default now(),
  dedupe_key text
);

create index if not exists notif_user_idx on notifications_sent(user_id, sent_at desc);
create unique index if not exists notif_dedupe_idx on notifications_sent(user_id, dedupe_key)
  where dedupe_key is not null;

-- ============================================================
-- leaderboard_snapshots
-- ============================================================
create table if not exists leaderboard_snapshots (
  id bigserial primary key,
  kind text not null,                 -- 'global_weekly' etc
  period_start timestamptz not null,
  snapshot jsonb not null,            -- array of {user_id, score, rank}
  created_at timestamptz not null default now()
);

create index if not exists lb_kind_period_idx on leaderboard_snapshots(kind, period_start desc);

-- ============================================================
-- reports
-- ============================================================
create table if not exists reports (
  id bigserial primary key,
  reporter_id uuid not null references users(id),
  target_user_id uuid references users(id),
  target_package_id uuid references packages(id),
  reason text not null,
  notes text,
  status text not null default 'open' check (status in ('open','reviewed','actioned','dismissed')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

-- ============================================================
-- audit_anti_cheat
-- ============================================================
create table if not exists audit_anti_cheat (
  id bigserial primary key,
  user_id uuid references users(id),
  reason text not null,
  severity int not null check (severity between 1 and 5),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists audit_user_idx on audit_anti_cheat(user_id, created_at desc);

-- ============================================================
-- iap_receipts (idempotent IAP ledger)
-- ============================================================
create table if not exists iap_receipts (
  id bigserial primary key,
  user_id uuid not null references users(id),
  platform text not null check (platform in ('apple','google','stripe')),
  product_id text not null,
  platform_receipt_id text not null,
  amount_usd numeric(12,4),
  granted_items jsonb not null default '[]'::jsonb,
  status text not null default 'pending' check (status in ('pending','verified','failed','refunded')),
  created_at timestamptz not null default now(),
  unique (platform, platform_receipt_id)
);

-- ============================================================
-- Public materialised views
-- ============================================================

-- Live packages suitable for the public map (stripped of user identity)
create or replace view live_packages_public as
  select
    id,
    rarity,
    theme,
    hops_count,
    peels_done,
    total_layers,
    is_legendary_chase,
    updated_at
  from packages
  where status = 'in_flight';

-- Public user card (safe subset)
create or replace view users_public as
  select
    id,
    username,
    display_name,
    avatar_id,
    frame_id,
    country_code,
    level,
    streak_days
  from users
  where not is_banned and not is_shadow_banned;
