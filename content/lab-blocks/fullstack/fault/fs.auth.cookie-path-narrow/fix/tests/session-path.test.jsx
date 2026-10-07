import { beforeEach, expect, test } from 'vitest';
import { SEED_USER, createBrowser, useBackend } from '@mf/fullstack';
import { get, post } from '@/lib/api.js';

const backend = useBackend({ each: true });
beforeEach(() => createBrowser(backend));
const signIn = () => post('/api/auth/login', { email: SEED_USER.email, password: SEED_USER.password });

test('the session survives a request outside the auth routes', async () => {
  await signIn();
  await expect(get('/api/orders')).resolves.toMatchObject({ items: expect.any(Array) });
});
