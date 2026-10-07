import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { flush, installFetch } from '@mf/harness';
import ReportsPage from '@/features/reports/ReportsPage.jsx';
import { SettingsProvider } from '@/context/settings.jsx';

test('the revenue report is requested once, not in a loop', async () => {
  localStorage.clear();
  const net = installFetch({ maxCalls: 25 });
  net.on('GET', '/api/reports/revenue', () => ({ days: [] }));
  render(
    <SettingsProvider>
      <ReportsPage />
    </SettingsProvider>,
  );
  await flush();
  await flush();
  await flush();
  expect(net.count('GET', '/api/reports/revenue')).toBe(1);
});
