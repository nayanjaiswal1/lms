import { fireEvent, render, screen } from '@testing-library/react';
import { installFetch, json } from '@mf/harness';
import OrdersPage from '@/features/orders/OrdersPage.jsx';
import { SettingsProvider } from '@/context/settings.jsx';

const ORDERS = [
  { id: 7, customer: 'Alice Nguyen', status: 'paid', total_cents: 4250, placed_at: '2025-03-05T14:30:00Z', flagged: false },
  { id: 8, customer: 'Bob Okafor', status: 'pending', total_cents: 1999, placed_at: '2025-03-06T09:00:00Z', flagged: true },
];

function renderPage(props) {
  localStorage.clear();
  return render(
    <SettingsProvider>
      <OrdersPage {...props} />
    </SettingsProvider>,
  );
}

test('orders are listed with formatted totals', async () => {
  const net = installFetch();
  net.on('GET', '/api/orders', () => ({ items: ORDERS, page: 1, pages: 1, total: 2 }));
  renderPage();
  expect(await screen.findByText('Alice Nguyen')).toBeInTheDocument();
  expect(screen.getByText('$42.50')).toBeInTheDocument();
  expect(screen.getByText('$19.99')).toBeInTheDocument();
});

test('the next page is requested from the pagination', async () => {
  const net = installFetch();
  net.on('GET', '/api/orders', () => ({ items: ORDERS, page: 1, pages: 3, total: 25 }));
  renderPage();
  await screen.findByText('Alice Nguyen');
  fireEvent.click(screen.getByText('Next'));
  expect(await screen.findByText('Page 2 of 3')).toBeInTheDocument();
  expect(net.calls.map((call) => call.url)).toContain('/api/orders?status=all&page=2');
});

test('the quick filter narrows the visible orders', async () => {
  const net = installFetch();
  net.on('GET', '/api/orders', () => ({ items: ORDERS, page: 1, pages: 1, total: 2 }));
  renderPage({ filter: 'bob' });
  expect(await screen.findByText('Bob Okafor')).toBeInTheDocument();
  expect(screen.queryByText('Alice Nguyen')).not.toBeInTheDocument();
});

test('a failed load shows an alert', async () => {
  const net = installFetch();
  net.on('GET', '/api/orders', () => json(500, { error: 'boom' }));
  renderPage();
  expect(await screen.findByRole('alert')).toHaveTextContent('Could not load orders.');
});

test('flagging an order sends the new flag and shows it', async () => {
  const net = installFetch();
  net.on('GET', '/api/orders', () => ({ items: ORDERS, page: 1, pages: 1, total: 2 }));
  net.on('POST', '/api/orders/7/flag', (call) => ({ id: 7, flagged: call.body.flagged }));
  renderPage();
  const button = await screen.findByRole('button', { name: 'Flag order 7' });
  expect(button).toHaveAttribute('aria-pressed', 'false');
  fireEvent.click(button);
  expect(button).toHaveAttribute('aria-pressed', 'true');
  await screen.findByRole('button', { name: 'Flag order 7' });
  expect(net.calls.find((call) => call.method === 'POST').body).toEqual({ flagged: true });
});
