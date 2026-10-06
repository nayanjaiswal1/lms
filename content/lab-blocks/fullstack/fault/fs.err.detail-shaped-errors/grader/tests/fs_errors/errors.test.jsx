import { beforeEach, expect, test } from 'vitest';
import { SEED_USER, createBrowser, useBackend } from '@mf/fullstack';
import { get, post } from '@/lib/api.js';

const backend = useBackend({ each: true });
beforeEach(() => createBrowser(backend));
const signIn = () => post('/api/auth/login', { email: SEED_USER.email, password: SEED_USER.password });

test('a missing order shows the server message and code', async () => {
  await signIn();
  await expect(get('/api/orders/9999')).rejects.toMatchObject({
    status: 404,
    code: 'order_not_found',
    message: 'No such order.',
  });
});

test('an unknown product at checkout shows the server code', async () => {
  await signIn();
  await expect(post('/api/orders', { items: [{ product_id: 999, quantity: 1 }] })).rejects.toMatchObject({
    status: 404,
    code: 'product_not_found',
  });
});
