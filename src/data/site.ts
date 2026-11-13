// One place for the facts every page repeats. Change them here only.

export const site = {
  name: 'Desert Social',
  domain: 'desertsocialaz.com',
  url: 'https://desertsocialaz.com',
  tagline: 'Good company is built in person.',
  description:
    'Desert Social is a community in Greater Phoenix for people who build things and would rather meet in person. Gatherings, drives, dinners and good introductions.',
  location: 'Greater Phoenix, Arizona',
  email: 'info@desertsocialaz.com',
  // Remove an entry and it disappears from the site.
  social: [
    { label: 'Instagram', handle: '@desertsocialaz', url: 'https://www.instagram.com/desertsocialaz/' },
  ],
  // All three forms post to one database function (supabase/setup.sql).
  // The publishable key is meant to be public: it can only call that function.
  forms: {
    endpoint: 'https://morrbqpugsjgqrvqijqv.supabase.co/rest/v1/rpc/submit_form',
    publishableKey: 'sb_publishable_WjbF0K2uVAzRYjdI1XXlbQ_LFofk7e8',
  },
};

export const nav = [
  { label: 'About', path: '/about/' },
  { label: 'Experiences', path: '/experiences/' },
  { label: 'Membership', path: '/membership/' },
  { label: 'Partners', path: '/partners/' },
  { label: 'Contact', path: '/contact/' },
];

// Prefix an internal path with the deploy base (a preview build lives under
// /desert-social/, production lives at /).
export function href(path: string): string {
  const base = import.meta.env.BASE_URL.replace(/\/$/, '');
  return base + (path.startsWith('/') ? path : '/' + path);
}
