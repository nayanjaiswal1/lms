import { beforeEach, expect, test } from 'vitest';
import { SEED_USER, createBrowser, useBackend } from '@mf/fullstack';
import { post } from '@/lib/api.js';

const backend = useBackend({ each: true });
beforeEach(() => createBrowser(backend));
const signIn = () => post('/api/auth/login', { email: SEED_USER.email, password: SEED_USER.password });

test('a failed sign-in carries the server message instead of a generic one', async () => {
  await expect(post('/api/auth/login', { email: SEED_USER.email, password: 'nope' })).rejects.toMatchObject({
    code: 'invalid_credentials',
    message: 'Wrong email or password.',
  });
});
