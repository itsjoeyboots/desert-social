-- Desert Social: form storage.
--
-- Run once in Supabase → SQL Editor → New query → paste this file → Run.
-- Safe to run again: it only creates what is missing and replaces the function.
--
-- What it sets up
--   • Three private tables, one per form, and a rate-limit log.
--   • Row-level security on every table with no public policies: the public
--     (publishable) key can't read, change or delete anything.
--   • One function, submit_form(), which is the only thing the website may
--     call. It validates every field again on the server, drops obvious bots
--     and limits each visitor to 5 submissions per 10 minutes.
--
-- Read submissions in Table Editor. Change an application's status there
-- (new → reviewing → accepted / declined).

create extension if not exists pgcrypto with schema extensions;

-- ── Tables ──────────────────────────────────────────────────────────────

create table if not exists public.membership_applications (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  status      text not null default 'new'
              check (status in ('new', 'reviewing', 'accepted', 'declined')),
  full_name   text not null,
  email       text not null,
  phone       text not null,
  profession  text not null,
  instagram   text,
  interests   text[] not null,
  reason      text not null,
  page        text,
  ip_hash     text
);

create table if not exists public.partner_inquiries (
  id            uuid primary key default gen_random_uuid(),
  created_at    timestamptz not null default now(),
  status        text not null default 'new'
                check (status in ('new', 'replied', 'closed')),
  full_name     text not null,
  business      text not null,
  email         text not null,
  phone         text,
  partner_type  text not null,
  link          text,
  message       text not null,
  page          text,
  ip_hash       text
);

create table if not exists public.contact_messages (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  status      text not null default 'new'
              check (status in ('new', 'replied', 'closed')),
  full_name   text not null,
  email       text not null,
  topic       text not null,
  message     text not null,
  page        text,
  ip_hash     text
);

create table if not exists public.form_rate_limits (
  id          bigint generated always as identity primary key,
  created_at  timestamptz not null default now(),
  ip_hash     text not null,
  form_name   text not null
);
create index if not exists form_rate_limits_ip_time on public.form_rate_limits (ip_hash, created_at);

-- ── Lock the tables down ───────────────────────────────────────────────

alter table public.membership_applications enable row level security;
alter table public.partner_inquiries       enable row level security;
alter table public.contact_messages        enable row level security;
alter table public.form_rate_limits        enable row level security;

revoke all on public.membership_applications, public.partner_inquiries,
              public.contact_messages, public.form_rate_limits
  from anon, authenticated;

-- ── The one door in ────────────────────────────────────────────────────

create or replace function public.submit_form(
  form_name  text,
  payload    jsonb,
  nickname   text default '',
  elapsed_ms integer default 0,
  page       text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  errors      jsonb := '{}'::jsonb;
  headers     jsonb := coalesce(nullif(current_setting('request.headers', true), '')::jsonb, '{}'::jsonb);
  ip          text;
  v_ip_hash   text;
  recent      integer;
  v_name      text := btrim(coalesce(payload->>'full_name', ''));
  v_email     text := lower(btrim(coalesce(payload->>'email', '')));
  v_phone     text := btrim(coalesce(payload->>'phone', ''));
  v_message   text;
  v_interests text[];
  allowed_interests text[] := array['Automotive gatherings', 'Social events', 'Business networking',
                                    'Private gatherings', 'Collaborations'];
  allowed_types     text[] := array['Venue', 'Automotive business', 'Local business', 'Brand',
                                    'Sponsor', 'Individual', 'Something else'];
  allowed_topics    text[] := array['General question', 'Membership', 'Press', 'Something else'];
begin
  if form_name not in ('membership', 'partner', 'contact') or jsonb_typeof(payload) is distinct from 'object' then
    return jsonb_build_object('ok', false, 'error', 'bad_request');
  end if;

  -- Bots fill the hidden field or submit faster than a person can type.
  -- Tell them it worked and store nothing.
  if coalesce(nickname, '') <> '' or coalesce(elapsed_ms, 0) < 3000 then
    return jsonb_build_object('ok', true);
  end if;

  -- Rate limit by a one-way hash of the visitor's address.
  ip := split_part(coalesce(headers->>'cf-connecting-ip', headers->>'x-forwarded-for', headers->>'x-real-ip', 'unknown'), ',', 1);
  v_ip_hash := encode(digest(btrim(ip) || ':desert-social', 'sha256'), 'hex');

  delete from public.form_rate_limits where created_at < now() - interval '1 day';
  select count(*) into recent
    from public.form_rate_limits
   where form_rate_limits.ip_hash = v_ip_hash
     and created_at > now() - interval '10 minutes';
  if recent >= 5 then
    return jsonb_build_object('ok', false, 'error', 'rate_limited');
  end if;
  insert into public.form_rate_limits (ip_hash, form_name) values (v_ip_hash, submit_form.form_name);

  -- Fields every form has.
  if v_name = '' then
    errors := errors || jsonb_build_object('full_name', 'This one is required.');
  elsif length(v_name) > 120 then
    errors := errors || jsonb_build_object('full_name', 'Keep this under 120 characters.');
  end if;

  if v_email = '' then
    errors := errors || jsonb_build_object('email', 'This one is required.');
  elsif length(v_email) > 200 or v_email !~ '^[^\s@]+@[^\s@]+\.[^\s@]{2,}$' then
    errors := errors || jsonb_build_object('email', 'That email address doesn’t look right.');
  end if;

  if form_name = 'membership' then
    if v_phone = '' then
      errors := errors || jsonb_build_object('phone', 'This one is required.');
    elsif length(v_phone) > 30 or length(regexp_replace(v_phone, '\D', '', 'g')) < 7 then
      errors := errors || jsonb_build_object('phone', 'Add a full phone number.');
    end if;

    if btrim(coalesce(payload->>'profession', '')) = '' then
      errors := errors || jsonb_build_object('profession', 'This one is required.');
    elsif length(payload->>'profession') > 160 then
      errors := errors || jsonb_build_object('profession', 'Keep this under 160 characters.');
    end if;

    if length(coalesce(payload->>'instagram', '')) > 120 then
      errors := errors || jsonb_build_object('instagram', 'Keep this under 120 characters.');
    end if;

    if jsonb_typeof(payload->'interests') = 'array' then
      select array_agg(value) into v_interests from jsonb_array_elements_text(payload->'interests');
    end if;
    if v_interests is null or cardinality(v_interests) = 0 or not (v_interests <@ allowed_interests) then
      errors := errors || jsonb_build_object('interests', 'Pick at least one.');
    end if;

    v_message := btrim(coalesce(payload->>'reason', ''));
    if length(v_message) < 20 then
      errors := errors || jsonb_build_object('reason', 'Tell us a little more: a sentence or two is plenty.');
    elsif length(v_message) > 2000 then
      errors := errors || jsonb_build_object('reason', 'Keep this under 2,000 characters.');
    end if;

    if errors <> '{}'::jsonb then
      return jsonb_build_object('ok', false, 'error', 'invalid', 'fields', errors);
    end if;

    insert into public.membership_applications
      (full_name, email, phone, profession, instagram, interests, reason, page, ip_hash)
    values
      (v_name, v_email, v_phone, btrim(payload->>'profession'),
       nullif(btrim(coalesce(payload->>'instagram', '')), ''), v_interests, v_message,
       left(submit_form.page, 200), v_ip_hash);

  elsif form_name = 'partner' then
    if btrim(coalesce(payload->>'business', '')) = '' then
      errors := errors || jsonb_build_object('business', 'This one is required.');
    elsif length(payload->>'business') > 160 then
      errors := errors || jsonb_build_object('business', 'Keep this under 160 characters.');
    end if;

    if v_phone <> '' and (length(v_phone) > 30 or length(regexp_replace(v_phone, '\D', '', 'g')) < 7) then
      errors := errors || jsonb_build_object('phone', 'Add a full phone number.');
    end if;

    if not (coalesce(payload->>'partner_type', '') = any (allowed_types)) then
      errors := errors || jsonb_build_object('partner_type', 'Choose an option.');
    end if;

    if length(coalesce(payload->>'link', '')) > 200 then
      errors := errors || jsonb_build_object('link', 'Keep this under 200 characters.');
    end if;

    v_message := btrim(coalesce(payload->>'message', ''));
    if length(v_message) < 10 then
      errors := errors || jsonb_build_object('message', 'Add a few more words so we can help.');
    elsif length(v_message) > 2000 then
      errors := errors || jsonb_build_object('message', 'Keep this under 2,000 characters.');
    end if;

    if errors <> '{}'::jsonb then
      return jsonb_build_object('ok', false, 'error', 'invalid', 'fields', errors);
    end if;

    insert into public.partner_inquiries
      (full_name, business, email, phone, partner_type, link, message, page, ip_hash)
    values
      (v_name, btrim(payload->>'business'), v_email, nullif(v_phone, ''), payload->>'partner_type',
       nullif(btrim(coalesce(payload->>'link', '')), ''), v_message,
       left(submit_form.page, 200), v_ip_hash);

  else -- contact
    if not (coalesce(payload->>'topic', '') = any (allowed_topics)) then
      errors := errors || jsonb_build_object('topic', 'Choose an option.');
    end if;

    v_message := btrim(coalesce(payload->>'message', ''));
    if length(v_message) < 10 then
      errors := errors || jsonb_build_object('message', 'Add a few more words so we can help.');
    elsif length(v_message) > 2000 then
      errors := errors || jsonb_build_object('message', 'Keep this under 2,000 characters.');
    end if;

    if errors <> '{}'::jsonb then
      return jsonb_build_object('ok', false, 'error', 'invalid', 'fields', errors);
    end if;

    insert into public.contact_messages (full_name, email, topic, message, page, ip_hash)
    values (v_name, v_email, payload->>'topic', v_message, left(submit_form.page, 200), v_ip_hash);
  end if;

  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.submit_form(text, jsonb, text, integer, text) from public;
grant execute on function public.submit_form(text, jsonb, text, integer, text) to anon, authenticated;

-- Make the new function visible to the API straight away.
notify pgrst, 'reload schema';
