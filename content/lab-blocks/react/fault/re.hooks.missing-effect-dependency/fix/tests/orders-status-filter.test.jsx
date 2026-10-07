import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { flush, installFetch } from '@mf/harness';
import OrdersPage from '@/features/orders/OrdersPage.jsx';
import { SettingsProvider } from '@/context/settings.jsx';

test('changing the status requests the orders with that status', async () => {
  localStorage.clear();
  const net = installFetch({ maxCalls: 30 });
  net.on('GET', '/api/orders', () => ({ items: [], page: 1, pages: 1, total: 0 }));
  render(
    <SettingsProvider>
      <OrdersPage />
    </SettingsProvider>,
  );
  await flush();
  fireEvent.change(screen.getByLabelText('Status'), { target: { value: 'paid' } });
  await waitFor(() => expect(net.calls.map((call) => call.url)).toContain('/api/orders?status=paid&page=1'));
});
