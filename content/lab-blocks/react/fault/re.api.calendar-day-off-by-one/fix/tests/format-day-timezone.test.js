import { formatDay } from '@/lib/format.js';

// Run the check as a viewer west of UTC, where the bug shows up.
process.env.TZ = 'America/Los_Angeles';

test('a calendar day is shown as the same day for a viewer west of UTC', () => {
  expect(formatDay('2025-03-05')).toBe('Mar 5, 2025');
});
