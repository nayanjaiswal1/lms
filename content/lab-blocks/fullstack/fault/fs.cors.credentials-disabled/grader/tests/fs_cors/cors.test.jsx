import { beforeEach, expect, test } from 'vitest';
import { SEED_USER, createBrowser, useBackend } from '@mf/fullstack';

const backend = useBackend({ each: true });
let browser;
beforeEach(() => {
  browser = createBrowser(backend);
});

const call = (path, init = {}) =>
  browser.fetch(`${backend.url}${path}`, { credentials: 'include', headers: { 'Content-Type': 'application/json' }, ...init });

test('the console can sign in and read its session across origins', async () => {
  const login = await call('/api/auth/login', { method: 'POST', body: JSON.stringify({ email: SEED_USER.email, password: SEED_USER.password }) });
  expect(login.status).toBe(200);
  const me = await call('/api/auth/me');
  expect((await me.json()).user.email).toBe(SEED_USER.email);
});
