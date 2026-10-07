import { fireEvent, render, screen } from '@testing-library/react';
import { SEED_USER, createBrowser, useBackend } from '@mf/fullstack';
import ProfilePage from '@/features/profile/ProfilePage.jsx';

const backend = useBackend({ each: true });
const JSON_HEADERS = { 'Content-Type': 'application/json' };

async function signIn(browser) {
  const login = await browser.fetch('/api/auth/login', {
    method: 'POST',
    headers: JSON_HEADERS,
    credentials: 'include',
    body: JSON.stringify({ email: SEED_USER.email, password: SEED_USER.password }),
  });
  expect(login.status).toBe(200);
}

test('a stale tab is told to reload instead of overwriting the newer profile', async () => {
  const tab = createBrowser(backend);
  const otherDevice = createBrowser(backend, { install: false });
  await signIn(tab);
  await signIn(otherDevice);

  render(<ProfilePage />);
  const name = await screen.findByLabelText('Name');

  const elsewhere = await otherDevice.fetch('/api/profile', {
    method: 'PUT',
    headers: { ...JSON_HEADERS, 'X-CSRF-Token': otherDevice.cookie('csrf_token').value },
    credentials: 'include',
    body: JSON.stringify({ name: 'Alice Elsewhere', phone: '555-0100', version: 1 }),
  });
  expect(elsewhere.status).toBe(200);

  fireEvent.change(name, { target: { value: 'Alice Stale Tab' } });
  fireEvent.click(screen.getByRole('button', { name: 'Save' }));

  expect(await screen.findByRole('alert')).toHaveTextContent('changed in another tab or device');
  expect(screen.queryByRole('status')).not.toBeInTheDocument();
  const current = await otherDevice.fetch('/api/profile', { credentials: 'include' });
  expect((await current.json()).name).toBe('Alice Elsewhere');
});
