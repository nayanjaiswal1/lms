import { installFetch, json } from '@mf/harness';
import { ApiError, del, get, post, put } from '@/lib/api.js';

test('get requests the path and returns the parsed body', async () => {
  const net = installFetch();
  net.on('GET', '/api/ping', () => ({ ok: true }));

  await expect(get('/api/ping')).resolves.toEqual({ ok: true });
  expect(net.calls).toHaveLength(1);
  expect(net.calls[0]).toMatchObject({ method: 'GET', url: '/api/ping' });
});

test('post and put send a JSON body', async () => {
  const net = installFetch();
  net.on('POST', '/api/things', (call) => json(201, { echoed: call.body }));
  net.on('PUT', '/api/things/1', (call) => json(200, { echoed: call.body }));

  await expect(post('/api/things', { name: 'a' })).resolves.toEqual({ echoed: { name: 'a' } });
  await expect(put('/api/things/1', { name: 'b' })).resolves.toEqual({ echoed: { name: 'b' } });
  expect(net.fetch.mock.calls[0][1].headers).toEqual({ 'Content-Type': 'application/json' });
});

test('a 204 response resolves to null', async () => {
  const net = installFetch();
  net.on('DELETE', '/api/things/1', () => json(204));

  await expect(del('/api/things/1')).resolves.toBeNull();
});

test('the abort signal is passed to fetch', async () => {
  const net = installFetch();
  net.on('GET', '/api/ping', () => ({}));
  const controller = new AbortController();

  await get('/api/ping', { signal: controller.signal });
  expect(net.calls[0].signal).toBe(controller.signal);
});

test('a network failure rejects the request', async () => {
  const net = installFetch();
  net.on('GET', '/api/ping', () => {
    throw new TypeError('Failed to fetch');
  });

  await expect(get('/api/ping')).rejects.toThrow('Failed to fetch');
});

test('ApiError carries the status', () => {
  const error = new ApiError(404, 'missing');
  expect(error).toBeInstanceOf(Error);
  expect(error.status).toBe(404);
  expect(error.name).toBe('ApiError');
});
