# Desert Social — website

The public site for Desert Social, at **desertsocialaz.com**. Static [Astro](https://astro.build) site, plain CSS, a little vanilla JavaScript, no framework. Forms store into Supabase. Hosted on GitHub Pages.

```bash
npm install
npm run dev       # http://localhost:4321
npm run build     # writes dist/
npm run check     # type and template check
```

## Changing content

Most changes are a one-file edit. Layouts don't need touching.

| To change | Edit |
| --- | --- |
| Email, Instagram, location, tagline | `src/data/site.ts` |
| The Founders membership: places, prices, what's included, what's coming | `src/data/membership.ts` |
| Add or edit an experience | `src/content/experiences/*.md`: one file each, ordered by `order` |
| Announce a gathering | `src/data/events.ts`: add an entry and it appears on Home and Experiences |
| Form choices (interests, partner types, contact topics) | `src/data/forms.ts` **and** the matching list in `supabase/setup.sql` |
| Page copy | `src/pages/*.astro` |

Adding a second membership tier means adding another object to `tiers` in `src/data/membership.ts`.

## Forms

All three forms (membership, partners, contact) post to one database function, `submit_form`, in the Supabase project `morrbqpugsjgqrvqijqv`. It checks every field again on the server, ignores obvious bots (a hidden field, plus a minimum time on the page) and limits each visitor to 5 submissions per 10 minutes.

**One-time setup:** in Supabase open **SQL Editor → New query**, paste all of `supabase/setup.sql` and click **Run**. Running it again is safe.

**Reading submissions:** Supabase → **Table Editor** → `membership_applications`, `partner_inquiries` or `contact_messages`. Change an application's `status` as you review it.

The publishable key in `src/data/site.ts` is meant to be public. It can only call `submit_form` and can't read anything back. Never put the **secret** key in this repository.

**Email alerts:** each new submission emails info@desertsocialaz.com through [Resend](https://resend.com). Setup is in `supabase/alerts.sql`: store the Resend API key in Supabase Vault as `resend_api_key`, then run the file. If the key is missing or Resend is down, submissions are still saved; only the email is skipped. Alerts come from `onboarding@resend.dev` until desertsocialaz.com is verified in Resend (that needs DNS records added at GoDaddy).

## Deploying

Every push to `main` deploys through `.github/workflows/deploy.yml`.

- **Live** (default): https://desertsocialaz.com, set as the custom domain under **Settings → Pages**.
- **Preview** instead: set the repository variable `LIVE_DOMAIN` to `preview` and remove the custom domain; the site then builds for https://itsjoeyboots.github.io/desert-social/, hidden from search engines.

GitHub Pages must be set to **Settings → Pages → Source: GitHub Actions**.

### DNS for desertsocialaz.com (GoDaddy)

Change only these. Leave the MX, TXT, `app` and `deluxe` records and the nameservers alone; email depends on them.

| Type | Name | Value |
| --- | --- | --- |
| A | @ | 185.199.108.153 |
| A | @ | 185.199.109.153 |
| A | @ | 185.199.110.153 |
| A | @ | 185.199.111.153 |
| CNAME | www | itsjoeyboots.github.io |

Remove GoDaddy's two parked-page A records on `@` (3.33.130.190 and 15.197.148.33). Then in **Settings → Pages**, enter `desertsocialaz.com` as the custom domain and tick **Enforce HTTPS** once the certificate is issued.
