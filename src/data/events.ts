// Upcoming gatherings. Empty on purpose until real dates exist: the site shows
// an honest "nothing public yet" state. Add an object and it appears on the
// home page and the Experiences page.
//
// { title: 'Night 001', date: '2027-01-16', time: '5:00 pm',
//   place: 'Venue name, City', kind: 'The Table', note: 'Founders only' }

export interface EventItem {
  title: string;
  date: string; // ISO date, YYYY-MM-DD
  time?: string;
  place?: string;
  kind?: string;
  note?: string;
}

export const events: EventItem[] = [];

export function upcoming(now = new Date()): EventItem[] {
  const today = now.toISOString().slice(0, 10);
  return events.filter((e) => e.date >= today).sort((a, b) => a.date.localeCompare(b.date));
}
