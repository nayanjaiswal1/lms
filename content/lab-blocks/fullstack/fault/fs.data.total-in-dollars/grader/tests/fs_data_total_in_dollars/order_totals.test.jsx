import { render, screen, within } from '@testing-library/react';
import { SEED_USER, createBrowser, useBackend } from '@mf/fullstack';
import OrdersPage from '@/features/orders/OrdersPage.jsx';

const backend = useBackend();

beforeEach(() => {
  createBrowser(backend);
});

test('the orders table shows each total in dollars and cents', async () => {
  await fetch('/api/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    credentials: 'include',
    body: JSON.stringify({ email: SEED_USER.email, password: SEED_USER.password }),
  });
  render(<OrdersPage />);
  const row = (await screen.findByText('#23')).closest('tr');
  expect(within(row).getByText('$477.00')).toBeInTheDocument();
  const prices = screen.getAllByRole('row').slice(1).map((r) => within(r).getAllByRole('cell')[3].textContent);
  expect(prices.every((text) => /^\$\d{1,3}(,\d{3})*\.\d{2}$/.test(text))).toBe(true);
  expect(prices.some((text) => text.startsWith('$0.'))).toBe(false);
});
