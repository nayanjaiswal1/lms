import { act, fireEvent, render, screen } from '@testing-library/react';
import { installFetch } from '@mf/harness';
import OrdersPage from '@/features/orders/OrdersPage.jsx';
import { SettingsProvider } from '@/context/settings.jsx';

test('the flag is rolled back when the request fails', async () => {
  localStorage.clear();
  const net = installFetch();
  net.on('GET', '/api/orders', () => ({
    items: [{ id: 7, customer: 'Alice Nguyen', status: 'paid', total_cents: 4250, placed_at: '2025-03-05T14:30:00Z', flagged: false }],
    page: 1,
    pages: 1,
    total: 1,
  }));
  const flag = net.hold('POST', /\/flag$/);
  render(
    <SettingsProvider>
      <OrdersPage />
    </SettingsProvider>,
  );
  const button = await screen.findByRole('button', { name: 'Flag order 7' });
  fireEvent.click(button);
  await act(async () => flag.requests[0].respond(500, { error: 'boom' }));
  expect(button).toHaveAttribute('aria-pressed', 'false');
});
