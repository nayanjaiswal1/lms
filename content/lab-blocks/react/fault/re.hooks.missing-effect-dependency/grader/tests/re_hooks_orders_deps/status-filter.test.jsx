import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { flush, installFetch } from '@mf/harness';
import OrdersPage from '@/features/orders/OrdersPage.jsx';
import { SettingsProvider } from '@/context/settings.jsx';

const ALL = [
  { id: 7, customer: 'Alice Nguyen', status: 'paid', total_cents: 4250, placed_at: '2025-03-05T14:30:00Z', flagged: false },
  { id: 8, customer: 'Bob Okafor', status: 'pending', total_cents: 1999, placed_at: '2025-03-06T09:00:00Z', flagged: false },
];

function setup() {
  localStorage.clear();
  const net = installFetch({ maxCalls: 30 });
  net.on('GET', '/api/orders', (call) => {
    const status = new URL(call.url, 'http://localhost').searchParams.get('status');
    const items = status === 'all' ? ALL : ALL.filter((order) => order.status === status);
    return { items, page: 1, pages: 1, total: items.length };
  });
  render(
    <SettingsProvider>
      <OrdersPage />
    </SettingsProvider>,
  );
  return net;
}

test('choosing a status loads the orders of that status', async () => {
  const net = setup();
  expect(await screen.findByText('Bob Okafor')).toBeInTheDocument();
  fireEvent.change(screen.getByLabelText('Status'), { target: { value: 'paid' } });
  await waitFor(() => expect(screen.queryByText('Bob Okafor')).not.toBeInTheDocument());
  expect(screen.getByText('Alice Nguyen')).toBeInTheDocument();
  expect(net.calls.map((call) => call.url)).toContain('/api/orders?status=paid&page=1');
});

test('one filter change sends exactly one request', async () => {
  const net = setup();
  await screen.findByText('Bob Okafor');
  fireEvent.change(screen.getByLabelText('Status'), { target: { value: 'pending' } });
  await waitFor(() => expect(screen.queryByText('Alice Nguyen')).not.toBeInTheDocument());
  await flush();
  await flush();
  expect(net.count('GET', '/api/orders')).toBe(2);
});
