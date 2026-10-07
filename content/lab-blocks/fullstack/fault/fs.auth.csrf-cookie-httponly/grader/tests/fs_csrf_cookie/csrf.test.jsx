import { beforeEach, expect, test } from 'vitest';
import { SEED_USER, createBrowser, useBackend } from '@mf/fullstack';
import { post, put } from '@/lib/api.js';

const backend = useBackend({ each: true });
beforeEach(() => createBrowser(backend));
const signIn = () => post('/api/auth/login', { email: SEED_USER.email, password: SEED_USER.password });

test('the page script can read the csrf cookie after sign-in', async () => {
  await signIn();
  expect(document.cookie).toContain('csrf_token=');
  expect(document.cookie).not.toContain('session=');
});

test('a profile save and a sign-out are accepted', async () => {
  await signIn();
  await expect(put('/api/profile', { name: 'Alice N.', phone: '555-0100', version: 1 })).resolves.toMatchObject({ version: 2 });
  await expect(post('/api/auth/logout')).resolves.toEqual({ ok: true });
});
