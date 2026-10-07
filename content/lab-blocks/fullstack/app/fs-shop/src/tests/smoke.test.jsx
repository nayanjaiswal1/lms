import { render, screen } from '@testing-library/react';
import App from '@/App.jsx';
import { formatMoney } from '@/lib/format.js';

test('the console shows its navigation', () => {
  render(<App />);
  expect(screen.getByRole('heading', { name: 'Shop Console' })).toBeInTheDocument();
  expect(screen.getByRole('navigation', { name: 'Main' })).toBeInTheDocument();
});

test('money is formatted from cents', () => {
  expect(formatMoney(123456)).toBe('$1,234.56');
});
