import { render, screen, within } from '@testing-library/react';
import { installFetch } from '@mf/harness';
import RevenueTable from '@/features/reports/RevenueTable.jsx';
import ReportsPage from '@/features/reports/ReportsPage.jsx';
import { SettingsProvider } from '@/context/settings.jsx';

const DAYS = [
  { date: '2025-03-04', orders: 2, revenue_cents: 5000 },
  { date: '2025-03-05', orders: 1, revenue_cents: 2500 },
];

function renderWithSettings(ui) {
  localStorage.clear();
  return render(<SettingsProvider>{ui}</SettingsProvider>);
}

test('the revenue table shows one row per day', () => {
  renderWithSettings(<RevenueTable days={DAYS} filter="" />);
  const rows = within(screen.getByRole('table', { name: 'Revenue by day' })).getAllByRole('row');
  expect(rows).toHaveLength(3);
  expect(rows[1]).toHaveTextContent('$50.00');
});

test('the revenue table filter keeps the days containing the text', () => {
  renderWithSettings(<RevenueTable days={DAYS} filter="03-05" />);
  expect(within(screen.getByRole('table')).getAllByRole('row')).toHaveLength(2);
});

test('the report page shows the total of the loaded days', async () => {
  const net = installFetch({ maxCalls: 20 });
  net.on('GET', '/api/reports/revenue', () => ({ days: DAYS }));
  renderWithSettings(<ReportsPage />);
  expect(await screen.findByText('Total $75.00')).toBeInTheDocument();
  expect(net.calls[0].url).toBe('/api/reports/revenue?days=30');
});
