import { installFetch, json } from '@mf/harness';
import { get, post, put } from '@/lib/api.js';

function setCookies(...cookies) {
  for (const name of document.cookie.split('; ').map((c) => c.split('=')[0]).filter(Boolean)) {
    document.cookie = `${name}=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/`;
  }
  for (const cookie of cookies) document.cookie = `${cookie}; path=/`;
}

const sentHeaders = (net, index = 0) => net.fetch.mock.calls[index][1].headers;

test('a PUT echoes the csrf_token cookie in the X-CSRF-Token header', async () => {
  setCookies('csrf_token=tok-123');
  const net = installFetch();
  net.on('PUT', '/api/profile', () => json(200, { ok: true }));
  await put('/api/profile', { name: 'A' });
  expect(sentHeaders(net)['X-CSRF-Token']).toBe('tok-123');
});

test('the token is found whatever the cookie order', async () => {
  setCookies('csrf_token=tok-abc', 'session=s1', 'theme=dark');
  const net = installFetch();
  net.on('POST', '/api/orders', () => json(201, { id: 1 }));
  await post('/api/orders', {});
  expect(sentHeaders(net)['X-CSRF-Token']).toBe('tok-abc');
});

test('a percent-encoded token is decoded', async () => {
  setCookies('csrf_token=a%2Fb%3D', 'other=1');
  const net = installFetch();
  net.on('POST', '/api/orders', () => json(201, {}));
  await post('/api/orders', {});
  expect(sentHeaders(net)['X-CSRF-Token']).toBe('a/b=');
});

test('a similarly named cookie is not used as the token', async () => {
  setCookies('csrftoken=wrong', 'csrf_token=right');
  const net = installFetch();
  net.on('PUT', '/api/profile', () => json(200, {}));
  await put('/api/profile', {});
  expect(sentHeaders(net)['X-CSRF-Token']).toBe('right');
});

test('a GET carries no CSRF header', async () => {
  setCookies('csrf_token=tok-123');
  const net = installFetch();
  net.on('GET', '/api/profile', () => json(200, {}));
  await get('/api/profile');
  expect(sentHeaders(net)['X-CSRF-Token']).toBeUndefined();
});
