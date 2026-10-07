import { installFetch, json } from '@mf/harness';
import { ApiError, get, post } from '@/lib/api.js';

test('requests carry credentials and a JSON body', async () => {
  const net = installFetch();
  net.on('POST', '/api/things', () => json(201, { id: 1 }));
  expect(await post('/api/things', { name: 'a' })).toEqual({ id: 1 });
  const [, init] = net.fetch.mock.calls[0];
  expect(init.credentials).toBe('include');
  expect(init.headers['Content-Type']).toBe('application/json');
  expect(JSON.parse(init.body)).toEqual({ name: 'a' });
});

test('an error response becomes an ApiError with the server message and code', async () => {
  const net = installFetch();
  net.on('GET', '/api/things', () => json(409, { error: { code: 'clash', message: 'Already there.' } }));
  const error = await get('/api/things').catch((e) => e);
  expect(error).toBeInstanceOf(ApiError);
  expect(error).toMatchObject({ status: 409, code: 'clash', message: 'Already there.' });
});

test('an error without a readable body falls back to a generic message', async () => {
  const net = installFetch();
  net.on('GET', '/api/things', () => new Response('<html>bad gateway</html>', { status: 502 }));
  const error = await get('/api/things').catch((e) => e);
  expect(error).toMatchObject({ status: 502, message: 'Request failed (502)' });
});
