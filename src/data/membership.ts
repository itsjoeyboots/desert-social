// The membership offer. Every page that mentions membership reads from here.
// To add a tier later, add another object to `tiers`: the layouts loop.

export interface Tier {
  id: string;
  name: string;
  open: boolean;
  cap: number;
  capWords: string;
  initiation: number;
  monthly: number;
  summary: string;
  terms: { initiation: string; monthly: string; cancel: string };
  includedNow: { title: string; detail: string }[];
  beingBuilt: { title: string; detail: string }[];
}

export const tiers: Tier[] = [
  {
    id: 'founders',
    name: 'Founders',
    open: true,
    cap: 25,
    capWords: 'Twenty-five',
    initiation: 250,
    monthly: 50,
    summary:
      'One membership, twenty-five places. Founders are here from the first night and have first claim on everything that follows.',
    terms: {
      initiation: 'Not refundable.',
      monthly: 'Cancel anytime.',
      cancel: 'Yes, anytime. Your monthly membership stops when you cancel. The initiation isn’t refundable.',
    },
    includedNow: [
      {
        title: 'Entry to every gathering',
        detail: 'Your place at every Desert Social gathering is covered by your membership.',
      },
      {
        title: 'The founder rate, locked',
        detail: 'Your monthly rate stays where it is for as long as you stay a member.',
      },
      {
        title: 'First access to what comes next',
        detail: 'Every new experience, perk and space is offered to Founders before anyone else.',
      },
    ],
    beingBuilt: [
      { title: 'Private gatherings', detail: 'Smaller, invitation-only evenings in places not usually open to a crowd.' },
      { title: 'Partner perks', detail: 'Standing arrangements with local businesses and venues we rate.' },
      { title: 'Business introductions', detail: 'A direct line to the people in the community you should know.' },
      { title: 'A home of our own', detail: 'A physical place for members, when the community is ready for one.' },
    ],
  },
];

export const founders = tiers[0];

export const usd = (n: number) => '$' + n.toLocaleString('en-US');
