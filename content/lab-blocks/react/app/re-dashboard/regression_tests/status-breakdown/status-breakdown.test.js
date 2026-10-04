import extension from '@/ext/status-breakdown/index.js';

const ORDERS = [
  { id: 1, customer: 'Alice Nguyen', status: 'paid', total_cents: 1500, flagged: true },
  { id: 2, customer: 'Bob Okafor', status: 'pending', total_cents: 2500, flagged: false },
  { id: 3, customer: 'Alice Nguyen', status: 'paid', total_cents: 1000, flagged: false },
];

test('counts orders per status in alphabetical order', () => {
  expect(extension.run(ORDERS)).toBe('paid: 2, pending: 1');
  expect(extension.run([])).toBe('No orders');
});
