import extension from '@/ext/flagged-count/index.js';

const ORDERS = [
  { id: 1, customer: 'Alice Nguyen', status: 'paid', total_cents: 1500, flagged: true },
  { id: 2, customer: 'Bob Okafor', status: 'pending', total_cents: 2500, flagged: false },
  { id: 3, customer: 'Alice Nguyen', status: 'paid', total_cents: 1000, flagged: false },
];

test('counts the flagged orders', () => {
  expect(extension.run(ORDERS)).toBe('1 of 3 flagged');
  expect(extension.run([])).toBe('0 of 0 flagged');
});
