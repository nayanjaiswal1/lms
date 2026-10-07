import { fireEvent, render, screen } from '@testing-library/react';
import { installFetch, json } from '@mf/harness';
import OrdersPage from '@/features/orders/OrdersPage.jsx';

const ORDERS = [
  { id: 7, status: 'paid', total_cents: 4250, placed_at: '2025-03-05T14:30:00Z', item_count: 2 },
  { id: 8, status: 'pending', total_cents: 1999, placed_at: '2025-03-06T09:00:00Z', item_count: 1 },
];

test('orders are listed with formatted totals', async () => {
  const net = installFetch();
  net.on('GET', '/api/orders', () => ({ items: ORDERS, page: 1, pages: 1, total: 2 }));
  render(<OrdersPage />);
  expect(await screen.findByText('#7')).toBeInTheDocument();
  expect(screen.getByText('$42.50')).toBeInTheDocument();
  expect(screen.getByText('$19.99')).toBeInTheDocument();
  expect(screen.getByText('pending')).toBeInTheDocument();
});

test('the next page is requested from the pagination', async () => {
  const net = installFetch();
  net.on('GET', '/api/orders', () => ({ items: ORDERS, page: 1, pages: 3, total: 25 }));
  render(<OrdersPage />);
  await screen.findByText('#7');
  expect(screen.getByRole('button', { name: 'Previous' })).toBeDisabled();
  fireEvent.click(screen.getByRole('button', { name: 'Next' }));
  expect(await screen.findByText('Page 2 of 3')).toBeInTheDocument();
  expect(net.calls.map((call) => call.url)).toContain('/api/orders?page=2');
});

test('a failed load shows an alert', async () => {
  const net = installFetch();
  net.on('GET', '/api/orders', () => json(500, { error: { code: 'boom', message: 'Server error.' } }));
  render(<OrdersPage />);
  expect(await screen.findByRole('alert')).toHaveTextContent('Could not load orders.');
});
