import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { flush, installFetch } from '@mf/harness';
import ReportsPage from '@/features/reports/ReportsPage.jsx';
import { SettingsProvider } from '@/context/settings.jsx';

const DAYS = [
  { date: '2025-03-04', orders: 2, revenue_cents: 5000 },
  { date: '2025-03-05', orders: 1, revenue_cents: 2500 },
];

function setup() {
  localStorage.clear();
  const net = installFetch({ maxCalls: 25 });
  net.on('GET', '/api/reports/revenue', (call) => {
    const days = Number(new URL(call.url, 'http://localhost').searchParams.get('days'));
    return { days: days > 7 ? DAYS : DAYS.slice(0, 1) };
  });
  render(
    <SettingsProvider>
      <ReportsPage />
    </SettingsProvider>,
  );
  return net;
}

async function settle() {
  for (let i = 0; i < 4; i += 1) await flush();
}

test('the report is requested once for the selected range', async () => {
  const net = setup();
  expect(await screen.findByText('Total $75.00')).toBeInTheDocument();
  await settle();
  expect(net.count('GET', '/api/reports/revenue')).toBe(1);
});

test('another range sends exactly one more request', async () => {
  const net = setup();
  await screen.findByText('Total $75.00');
  fireEvent.change(screen.getByLabelText('Range'), { target: { value: '7' } });
  expect(await screen.findByText('Total $50.00')).toBeInTheDocument();
  await settle();
  expect(net.count('GET', '/api/reports/revenue')).toBe(2);
  expect(net.calls.at(-1).url).toBe('/api/reports/revenue?days=7');
});
