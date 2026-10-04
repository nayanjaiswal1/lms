import { render, screen, fireEvent } from '@testing-library/react';
import App from '@/App.jsx';
import { formatMoney } from '@/lib/format.js';

test('the console shows its navigation and starts on the overview', () => {
  render(<App />);
  expect(screen.getByRole('heading', { name: 'Ops Console' })).toBeInTheDocument();
  expect(screen.getByRole('navigation', { name: 'Main' })).toBeInTheDocument();
  expect(screen.getByRole('heading', { name: 'Overview' })).toBeInTheDocument();
});

test('the quick filter keeps what was typed', () => {
  render(<App />);
  const filter = screen.getByRole('searchbox', { name: 'Quick filter' });
  fireEvent.change(filter, { target: { value: 'alice' } });
  expect(filter).toHaveValue('alice');
});

test('money is formatted from cents', () => {
  expect(formatMoney(123456)).toBe('$1,234.56');
});
