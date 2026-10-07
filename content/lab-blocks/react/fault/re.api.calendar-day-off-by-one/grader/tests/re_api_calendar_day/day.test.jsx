import { render, screen, within } from '@testing-library/react';
import RevenueTable from '@/features/reports/RevenueTable.jsx';
import { SettingsProvider } from '@/context/settings.jsx';
import { formatDay, parseDay } from '@/lib/format.js';

test('a calendar day keeps its date whatever the viewer time zone', () => {
  expect(formatDay('2025-03-05')).toBe('Mar 5, 2025');
  expect(formatDay('2025-01-01')).toBe('Jan 1, 2025');
  expect(formatDay('2024-12-31')).toBe('Dec 31, 2024');
});

test('parseDay returns local midnight of that day', () => {
  const day = parseDay('2025-03-05');
  expect([day.getFullYear(), day.getMonth(), day.getDate(), day.getHours()]).toEqual([2025, 2, 5, 0]);
});

test('the revenue table labels the rows with the days the API sent', () => {
  localStorage.clear();
  render(
    <SettingsProvider>
      <RevenueTable days={[{ date: '2025-03-04', orders: 2, revenue_cents: 5000 }]} filter="" />
    </SettingsProvider>,
  );
  expect(within(screen.getByRole('table')).getByText('Mar 4, 2025')).toBeInTheDocument();
});
