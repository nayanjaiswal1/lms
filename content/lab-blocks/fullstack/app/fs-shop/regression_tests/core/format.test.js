import { formatDate, formatMoney } from '@/lib/format.js';

test('money is formatted from integer cents', () => {
  expect(formatMoney(0)).toBe('$0.00');
  expect(formatMoney(1250)).toBe('$12.50');
  expect(formatMoney(123456)).toBe('$1,234.56');
});

test('a timestamp is shown as the viewer local calendar day', () => {
  const localNoon = new Date(2025, 2, 5, 12, 0, 0);
  expect(formatDate(localNoon.toISOString())).toBe('Mar 5, 2025');
});
