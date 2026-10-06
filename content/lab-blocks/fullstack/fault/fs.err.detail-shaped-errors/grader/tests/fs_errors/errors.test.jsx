import { beforeEach, expect, test } from 'vitest';
import { SEED_USER, createBrowser, useBackend } from '@mf/fullstack';
import { get, post, put } from '@/lib/api.js';

const backend = useBackend({ each: true });
beforeEach(() => createBrowser(backend));
const signIn = () => post('/api/auth/login', { email: SEED_USER.email, password: SEED_USER.password });

test('a failed sign-in shows the server message and code', async () => {
  await expect(post('/api/auth/login', { email: SEED_USER.email, password: 'nope' })).rejects.toMatchObject({
    status: 401,
    code: 'invalid_credentials',
    message: 'Wrong email or password.',
  });
});

test('a profile version conflict shows the server message and code', async () => {
  await signIn();
  await expect(put('/api/profile', { name: 'A', phone: '1', version: 99 })).rejects.toMatchObject({
    status: 409,
    code: 'version_conflict',
    message: expect.stringContaining('changed elsewhere'),
  });
});
