import extension from '@/ext/order-total/index.js';

const ORDERS = [
  { id: 1, customer: 'Alice Nguyen', status: 'paid', total_cents: 1500, flagged: true },
  { id: 2, customer: 'Bob Okafor', status: 'pending', total_cents: 2500, flagged: false },
  { id: 3, customer: 'Alice Nguyen', status: 'paid', total_cents: 1000, flagged: false },
];

test('the total sums the orders in dollars', () => {
  expect(extension.run(ORDERS)).toBe('Total: $50.00');
  expect(extension.run([])).toBe('Total: $0.00');
});
