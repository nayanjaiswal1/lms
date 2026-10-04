import { formatDateTime, formatDay, formatMoney, parseDay } from '@/lib/format.js';

test('money is formatted from integer cents', () => {
  expect(formatMoney(0)).toBe('$0.00');
  expect(formatMoney(4250)).toBe('$42.50');
  expect(formatMoney(123456)).toBe('$1,234.56');
});

test('money follows the currency', () => {
  expect(formatMoney(4250, 'EUR')).toContain('42.50');
  expect(formatMoney(4250, 'EUR')).toContain('€');
});

test('parseDay returns a Date', () => {
  expect(parseDay('2025-03-05')).toBeInstanceOf(Date);
});

test('formatDay renders a calendar day', () => {
  expect(formatDay('2025-03-05')).toBe('Mar 5, 2025');
  expect(formatDay('2024-12-31')).toBe('Dec 31, 2024');
});

test('formatDateTime renders an instant with its time', () => {
  const text = formatDateTime('2025-03-05T14:30:00Z');
  expect(text).toContain('2025');
  expect(text).toMatch(/\d{2}:\d{2}/);
});
