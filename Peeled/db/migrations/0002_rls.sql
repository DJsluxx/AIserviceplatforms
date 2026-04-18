-- PEELED — Row-level security policies
-- Assumes 0001_init.sql has been applied. All gameplay writes go through service role.

-- ============================================================
-- Helpers
-- ============================================================
create or replace function current_user_id() returns uuid
language sql stable
as $$
  select auth.uid();
$$;

-- ============================================================
-- users
-- ============================================================
alter table users enable row level security;

drop policy if exists users_self_read on users;
create policy users_self_read on users
  for select using (id = current_user_id());

drop policy if exists users_self_update on users;
create policy users_self_update on users
  for update using (id = current_user_id())
  with check (id = current_user_id());

-- public profile read via users_public view only

-- ============================================================
-- inventory_items — strictly self-read
-- ============================================================
alter table inventory_items enable row level security;

drop policy if exists inv_self on inventory_items;
create policy inv_self on inventory_items
  for select using (user_id = current_user_id());

-- ============================================================
-- packages — read only packages you hold, or public fields via live_packages_public
-- ============================================================
alter table packages enable row level security;

drop policy if exists pkg_self_holder on packages;
create policy pkg_self_holder on packages
  for select using (current_holder_id = current_user_id());

drop policy if exists pkg_origin_read on packages;
create policy pkg_origin_read on packages
  for select using (origin_user_id = current_user_id());

-- ============================================================
-- package_events — users can see events for packages they have touched
-- ============================================================
alter table package_events enable row level security;

drop policy if exists pkg_events_involved on package_events;
create policy pkg_events_involved on package_events
  for select using (
    actor_user_id = current_user_id()
    or related_user_id = current_user_id()
    or package_id in (
      select id from packages where current_holder_id = current_user_id()
                                 or origin_user_id    = current_user_id()
    )
  );

-- ============================================================
-- package_layers — NEVER client-readable (only service role)
-- ============================================================
alter table package_layers enable row level security;
-- no select policy -> no client access

-- ============================================================
-- peels — self read
-- ============================================================
alter table peels enable row level security;

drop policy if exists peels_self on peels;
create policy peels_self on peels
  for select using (user_id = current_user_id());

-- ============================================================
-- friendships
-- ============================================================
alter table friendships enable row level security;

drop policy if exists fr_read on friendships;
create policy fr_read on friendships
  for select using (follower_id = current_user_id() or followee_id = current_user_id());

drop policy if exists fr_write on friendships;
create policy fr_write on friendships
  for insert with check (follower_id = current_user_id());

drop policy if exists fr_delete on friendships;
create policy fr_delete on friendships
  for delete using (follower_id = current_user_id());

-- ============================================================
-- blocks
-- ============================================================
alter table blocks enable row level security;

drop policy if exists blk_self on blocks;
create policy blk_self on blocks
  for all using (blocker_id = current_user_id())
             with check (blocker_id = current_user_id());

-- ============================================================
-- device_tokens — self-only
-- ============================================================
alter table device_tokens enable row level security;

drop policy if exists dt_self on device_tokens;
create policy dt_self on device_tokens
  for all using (user_id = current_user_id())
             with check (user_id = current_user_id());

-- ============================================================
-- notifications_sent — self-read only
-- ============================================================
alter table notifications_sent enable row level security;

drop policy if exists notif_self on notifications_sent;
create policy notif_self on notifications_sent
  for select using (user_id = current_user_id());

-- ============================================================
-- leaderboard_snapshots — public read
-- ============================================================
alter table leaderboard_snapshots enable row level security;

drop policy if exists lb_read_all on leaderboard_snapshots;
create policy lb_read_all on leaderboard_snapshots
  for select using (true);

-- ============================================================
-- reports — self read/create only
-- ============================================================
alter table reports enable row level security;

drop policy if exists reports_self on reports;
create policy reports_self on reports
  for select using (reporter_id = current_user_id());

drop policy if exists reports_self_create on reports;
create policy reports_self_create on reports
  for insert with check (reporter_id = current_user_id());

-- ============================================================
-- audit_anti_cheat — no client reads at all
-- ============================================================
alter table audit_anti_cheat enable row level security;
-- deliberately no policies -> locked from clients

-- ============================================================
-- iap_receipts — self read only, server writes
-- ============================================================
alter table iap_receipts enable row level security;

drop policy if exists iap_self_read on iap_receipts;
create policy iap_self_read on iap_receipts
  for select using (user_id = current_user_id());

-- ============================================================
-- seasons — public read
-- ============================================================
alter table seasons enable row level security;

drop policy if exists seasons_read on seasons;
create policy seasons_read on seasons
  for select using (true);
