import { act, fireEvent, render, screen } from '@testing-library/react';
import { installFetch } from '@mf/harness';
import OrdersPage from '@/features/orders/OrdersPage.jsx';
import { SettingsProvider } from '@/context/settings.jsx';

const ORDERS = [
  { id: 7, customer: 'Alice Nguyen', status: 'paid', total_cents: 4250, placed_at: '2025-03-05T14:30:00Z', flagged: false },
  { id: 8, customer: 'Bob Okafor', status: 'pending', total_cents: 1999, placed_at: '2025-03-06T09:00:00Z', flagged: true },
];

async function setup() {
  localStorage.clear();
  const net = installFetch();
  net.on('GET', '/api/orders', () => ({ items: ORDERS, page: 1, pages: 1, total: 2 }));
  const flag = net.hold('POST', /\/flag$/);
  render(
    <SettingsProvider>
      <OrdersPage />
    </SettingsProvider>,
  );
  await screen.findByText('Alice Nguyen');
  return flag;
}

const button = (id) => screen.getByRole('button', { name: `Flag order ${id}` });

test('a rejected flag is rolled back and the error is shown', async () => {
  const flag = await setup();
  fireEvent.click(button(7));
  expect(button(7)).toHaveAttribute('aria-pressed', 'true');
  await act(async () => flag.requests[0].respond(500, { error: 'boom' }));
  expect(await screen.findByRole('alert')).toHaveTextContent('Could not update the flag.');
  expect(button(7)).toHaveAttribute('aria-pressed', 'false');
});

test('a rejected unflag brings the flag back', async () => {
  const flag = await setup();
  fireEvent.click(button(8));
  expect(button(8)).toHaveAttribute('aria-pressed', 'false');
  await act(async () => flag.requests[0].respond(500, { error: 'boom' }));
  expect(await screen.findByRole('alert')).toBeInTheDocument();
  expect(button(8)).toHaveAttribute('aria-pressed', 'true');
});

test('an accepted flag stays', async () => {
  const flag = await setup();
  fireEvent.click(button(7));
  await act(async () => flag.requests[0].respond(200, { id: 7, flagged: true }));
  expect(button(7)).toHaveAttribute('aria-pressed', 'true');
  expect(screen.queryByRole('alert')).not.toBeInTheDocument();
});
