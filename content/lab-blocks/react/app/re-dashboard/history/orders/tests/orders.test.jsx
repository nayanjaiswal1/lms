import { render, screen } from '@testing-library/react';
import { installFetch } from '@mf/harness';
import OrdersPage from '@/features/orders/OrdersPage.jsx';
import { SettingsProvider } from '@/context/settings.jsx';

const ORDER = { id: 7, customer: 'Alice Nguyen', status: 'paid', total_cents: 4250, placed_at: '2025-03-05T14:30:00Z', flagged: false };

test('the orders page lists the first page of orders', async () => {
  const net = installFetch();
  net.on('GET', '/api/orders', () => ({ items: [ORDER], page: 1, pages: 1, total: 1 }));

  render(
    <SettingsProvider>
      <OrdersPage />
    </SettingsProvider>,
  );

  expect(await screen.findByText('Alice Nguyen')).toBeInTheDocument();
  expect(screen.getByText('$42.50')).toBeInTheDocument();
  expect(net.calls[0].url).toBe('/api/orders?status=all&page=1');
});
