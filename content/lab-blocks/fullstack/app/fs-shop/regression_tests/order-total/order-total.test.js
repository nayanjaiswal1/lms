import extension from '@/ext/order-total/index.js';

const ORDERS = [
  { id: 1, status: 'paid', total_cents: 1500 },
  { id: 2, status: 'pending', total_cents: 2500 },
  { id: 3, status: 'paid', total_cents: 1000 },
];

test('the total sums the orders in dollars', () => {
  expect(extension.run(ORDERS)).toBe('Total: $50.00');
  expect(extension.run([])).toBe('Total: $0.00');
});
