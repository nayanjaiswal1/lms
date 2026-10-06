import { fireEvent, render, screen } from '@testing-library/react';
import { installFetch } from '@mf/harness';
import OrdersPage from '@/features/orders/OrdersPage.jsx';

const order = (id) => ({ id, status: 'paid', total_cents: 1000, placed_at: '2025-03-05T14:30:00Z', item_count: 1 });

test('the console counts pages from 1 and shows what the API returns', async () => {
  const net = installFetch();
  net.on('GET', '/api/orders', (call) => {
    const page = Number(new URL(call.url, 'http://x').searchParams.get('page'));
    return { items: page === 1 ? [order(23), order(22)] : [order(13)], page, pages: 2, total: 3 };
  });
  render(<OrdersPage />);
  expect(await screen.findByText('#23')).toBeInTheDocument();
  expect(net.calls[0].url).toBe('/api/orders?page=1');
  fireEvent.click(screen.getByRole('button', { name: 'Next' }));
  expect(await screen.findByText('#13')).toBeInTheDocument();
  expect(net.calls.map((call) => call.url)).toContain('/api/orders?page=2');
});
