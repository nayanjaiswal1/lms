import extension from '@/ext/status-breakdown/index.js';

test('orders are counted per status in alphabetical order', () => {
  const orders = [{ status: 'paid' }, { status: 'pending' }, { status: 'paid' }];
  expect(extension.run(orders)).toBe('paid: 2, pending: 1');
});

test('an empty page says so', () => {
  expect(extension.run([])).toBe('No orders');
});
