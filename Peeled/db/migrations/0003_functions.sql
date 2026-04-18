-- PEELED — Postgres functions for atomic game operations
-- All invoked by service role only.

-- ============================================================
-- claim_package_slot
-- Atomically attempts to assign a package to a user, enforcing the
-- "max 3 concurrent packages per user" invariant.
-- Returns true if slot claimed, false otherwise.
-- ============================================================
create or replace function claim_package_slot(
  p_package_id uuid,
  p_user_id uuid,
  p_deadline timestamptz,
  p_max_concurrent int default 3
) returns boolean
language plpgsql
as $$
declare
  v_count int;
begin
  perform pg_advisory_xact_lock(hashtext(p_user_id::text));

  select count(*) into v_count
    from packages
    where current_holder_id = p_user_id
      and status = 'in_flight';

  if v_count >= p_max_concurrent then
    return false;
  end if;

  update packages
     set current_holder_id = p_user_id,
         current_holder_deadline = p_deadline,
         current_holder_since = now(),
         hops_count = hops_count + 1
   where id = p_package_id
     and status = 'in_flight';

  return found;
end $$;

-- ============================================================
-- release_expired_holder
-- Clears expired holder so the ticker can reroute.
-- ============================================================
create or replace function release_expired_holder(p_package_id uuid)
returns boolean
language plpgsql
as $$
begin
  update packages
     set current_holder_id = null,
         current_holder_deadline = null
   where id = p_package_id
     and status = 'in_flight'
     and current_holder_deadline <= now();

  return found;
end $$;

-- ============================================================
-- apply_peel
-- Atomically records a peel, advances layer counter, and checks completion.
-- Returns the record of what was peeled + whether it was the final layer.
-- ============================================================
create or replace function apply_peel(
  p_package_id uuid,
  p_user_id uuid,
  p_action_nonce text,
  p_time_to_peel_ms int
) returns table (
  layer_index int,
  layer_type layer_type,
  content jsonb,
  reveal_copy text,
  was_final boolean
)
language plpgsql
as $$
declare
  v_layer_index int;
  v_layer_type layer_type;
  v_layer_content jsonb;
  v_layer_copy text;
  v_total int;
  v_peels_done int;
  v_was_final boolean;
begin
  perform pg_advisory_xact_lock(hashtext(p_package_id::text));

  -- Ensure package is held by user
  if not exists (
    select 1 from packages
     where id = p_package_id
       and current_holder_id = p_user_id
       and status = 'in_flight'
       and current_holder_deadline > now()
  ) then
    raise exception 'package not held by user or expired' using errcode = 'P0001';
  end if;

  select peels_done, total_layers
    into v_peels_done, v_total
    from packages where id = p_package_id;

  v_layer_index := v_peels_done;
  v_was_final := (v_layer_index + 1) = v_total;

  select pl.layer_type, pl.content, pl.reveal_copy
    into v_layer_type, v_layer_content, v_layer_copy
    from package_layers pl
   where pl.package_id = p_package_id
     and pl.layer_index = v_layer_index;

  if not found then
    raise exception 'layer % not found for package %', v_layer_index, p_package_id;
  end if;

  insert into peels (package_id, user_id, layer_index, layer_type, reward_payload, was_final, time_to_peel_ms, action_nonce)
    values (p_package_id, p_user_id, v_layer_index, v_layer_type, v_layer_content, v_was_final, p_time_to_peel_ms, p_action_nonce);

  update packages
     set peels_done = peels_done + 1,
         status = case when v_was_final then 'completed'::package_status else status end,
         completed_at = case when v_was_final then now() else completed_at end
   where id = p_package_id;

  insert into package_events (package_id, event_type, actor_user_id, payload)
    values (p_package_id, 'peeled'::package_event_type, p_user_id,
            jsonb_build_object('layer_index', v_layer_index, 'was_final', v_was_final));

  return query
    select v_layer_index, v_layer_type, v_layer_content, v_layer_copy, v_was_final;
end $$;

-- ============================================================
-- update_streak
-- Called once per day per user on first activity.
-- ============================================================
create or replace function update_streak(p_user_id uuid) returns int
language plpgsql
as $$
declare
  v_last date;
  v_today date := (now() at time zone 'utc')::date;
  v_new int;
begin
  select streak_last_date into v_last from users where id = p_user_id for update;

  if v_last is null or v_today - v_last > 1 then
    v_new := 1;
  elsif v_today - v_last = 1 then
    v_new := (select streak_days from users where id = p_user_id) + 1;
  else
    return (select streak_days from users where id = p_user_id);
  end if;

  update users
     set streak_days = v_new,
         streak_last_date = v_today
   where id = p_user_id;

  return v_new;
end $$;
