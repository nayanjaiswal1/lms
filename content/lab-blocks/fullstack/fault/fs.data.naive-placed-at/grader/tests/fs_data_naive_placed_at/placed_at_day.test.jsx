import { vi } from 'vitest';
import { render, screen, within } from '@testing-library/react';
import { SEED_USER, createBrowser, useBackend } from '@mf/fullstack';
import OrdersPage from '@/features/orders/OrdersPage.jsx';

const backend = useBackend();
const JSON_HEADERS = { 'Content-Type': 'application/json' };

async function signIn(browser = { fetch }) {
  const login = await browser.fetch('/api/auth/login', {
    method: 'POST',
    headers: JSON_HEADERS,
    credentials: 'include',
    body: JSON.stringify({ email: SEED_USER.email, password: SEED_USER.password }),
  });
  expect(login.status).toBe(200);
}

const DAY = { year: 'numeric', month: 'short', day: 'numeric' };
const NEWEST_DAY = new Date('2025-03-06T02:30:00Z').toLocaleDateString('en-US', DAY);

// jsdom's AbortSignal is not accepted by Node's fetch, so the page's abort signal is dropped in front of the backend.
beforeEach(() => {
  const browser = createBrowser(backend);
  vi.stubGlobal('fetch', (input, init = {}) => browser.fetch(input, { ...init, signal: undefined }));
});

test('the newest order shows the day it was placed in the viewer time zone', async () => {
  await signIn();
  render(<OrdersPage />);
  const row = (await screen.findByText('#23')).closest('tr');
  expect(within(row).getByText(NEWEST_DAY)).toBeInTheDocument();
});

test('the time zone of the run is west of UTC, so the day differs from the UTC day', () => {
  expect(NEWEST_DAY).toBe('Mar 5, 2025');
});
