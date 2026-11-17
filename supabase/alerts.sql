-- Desert Social: email alerts for new form submissions.
--
-- Every new membership application, partner inquiry or contact message sends
-- one plain email to info@desertsocialaz.com through Resend (resend.com).
--
-- Before running this file:
--   1. Sign up at resend.com with info@desertsocialaz.com (alerts can only go
--      to the address the Resend account was created with until a domain is
--      verified there).
--   2. Resend → API Keys → Create API key (permission: Sending access).
--   3. In Supabase → SQL Editor, run this once, with your key pasted in:
--        select vault.create_secret('re_YOUR_KEY', 'resend_api_key');
--      The key is stored encrypted in Supabase Vault, never in this repository.
--
-- Then run this file (Supabase → SQL Editor → New query → paste → Run).
-- Safe to run again.
--
-- An email problem never blocks a submission: if the key is missing or the
-- request fails, the row is still saved and no email is sent.

create extension if not exists pg_net with schema extensions;

create or replace function public.notify_new_submission()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  alert_to  constant text := 'info@desertsocialaz.com';
  v_key     text;
  r         jsonb := to_jsonb(new);
  v_subject text;
  v_lines   text[];
begin
  select decrypted_secret into v_key
    from vault.decrypted_secrets
   where name = 'resend_api_key'
   limit 1;
  if v_key is null or v_key = '' then
    return new;
  end if;

  if tg_table_name = 'membership_applications' then
    v_subject := 'New Founders application: ' || (r->>'full_name');
    v_lines := array[
      'Name: '       || (r->>'full_name'),
      'Email: '      || (r->>'email'),
      'Phone: '      || (r->>'phone'),
      'Work: '       || (r->>'profession'),
      'Instagram: '  || coalesce(r->>'instagram', '—'),
      'Interests: '  || array_to_string(array(select jsonb_array_elements_text(r->'interests')), ', '),
      '',
      'Why Desert Social:',
      r->>'reason'
    ];
  elsif tg_table_name = 'partner_inquiries' then
    v_subject := 'New partner inquiry: ' || (r->>'business');
    v_lines := array[
      'Name: '     || (r->>'full_name'),
      'Business: ' || (r->>'business'),
      'Type: '     || (r->>'partner_type'),
      'Email: '    || (r->>'email'),
      'Phone: '    || coalesce(r->>'phone', '—'),
      'Link: '     || coalesce(r->>'link', '—'),
      '',
      r->>'message'
    ];
  else
    v_subject := 'New message (' || (r->>'topic') || '): ' || (r->>'full_name');
    v_lines := array[
      'Name: '  || (r->>'full_name'),
      'Email: ' || (r->>'email'),
      'Topic: ' || (r->>'topic'),
      '',
      r->>'message'
    ];
  end if;

  v_lines := v_lines || array[
    '',
    '—',
    'Reply to this email to answer them directly.',
    'All submissions: Supabase → Table Editor → ' || tg_table_name
  ];

  perform net.http_post(
    url     := 'https://api.resend.com/emails',
    headers := jsonb_build_object('Authorization', 'Bearer ' || v_key,
                                  'Content-Type', 'application/json'),
    body    := jsonb_build_object(
                 'from',     'Desert Social <onboarding@resend.dev>',
                 'to',       jsonb_build_array(alert_to),
                 'reply_to', r->>'email',
                 'subject',  left(v_subject, 150),
                 'text',     array_to_string(v_lines, E'\n'))
  );
  return new;
exception when others then
  return new;
end;
$$;

revoke all on function public.notify_new_submission() from public, anon, authenticated;

drop trigger if exists notify_new_submission on public.membership_applications;
drop trigger if exists notify_new_submission on public.partner_inquiries;
drop trigger if exists notify_new_submission on public.contact_messages;

create trigger notify_new_submission after insert on public.membership_applications
  for each row execute function public.notify_new_submission();
create trigger notify_new_submission after insert on public.partner_inquiries
  for each row execute function public.notify_new_submission();
create trigger notify_new_submission after insert on public.contact_messages
  for each row execute function public.notify_new_submission();
