import { beforeEach, expect, test } from 'vitest';
import { SEED_USER, createBrowser, useBackend } from '@mf/fullstack';
import { post, put } from '@/lib/api.js';

const backend = useBackend({ each: true });
beforeEach(() => createBrowser(backend));
const signIn = () => post('/api/auth/login', { email: SEED_USER.email, password: SEED_USER.password });

test('a save after sign-in carries the csrf token and is accepted', async () => {
  await signIn();
  await expect(put('/api/profile', { name: 'Alice N.', phone: '555-0100', version: 1 })).resolves.toMatchObject({ version: 2 });
});
