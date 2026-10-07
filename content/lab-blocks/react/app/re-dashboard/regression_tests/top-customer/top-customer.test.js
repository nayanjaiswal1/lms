import extension from '@/ext/top-customer/index.js';

const ORDERS = [
  { id: 1, customer: 'Alice Nguyen', status: 'paid', total_cents: 1500, flagged: true },
  { id: 2, customer: 'Bob Okafor', status: 'pending', total_cents: 2500, flagged: false },
  { id: 3, customer: 'Alice Nguyen', status: 'paid', total_cents: 1000, flagged: false },
];

test('names the customer with the most orders', () => {
  expect(extension.run(ORDERS)).toBe('Alice Nguyen (2 orders)');
  expect(extension.run([ORDERS[1]])).toBe('Bob Okafor (1 order)');
  expect(extension.run([])).toBe('No orders');
});
