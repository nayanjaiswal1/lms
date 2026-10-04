import { installFetch, json } from '@mf/harness';

async function freshClient() {
  vi.resetModules();
  return import('@/lib/api.js');
}

test('requests go to the API URL configured at build time', async () => {
  vi.stubEnv('VITE_API_URL', 'https://api.example.test');
  const net = installFetch();
  net.on('GET', /\/api\/ping$/, () => json(200, { ok: true }));
  const { get } = await freshClient();
  await get('/api/ping');
  expect(net.calls[0].url).toBe('https://api.example.test/api/ping');
});

test('without the variable requests stay relative to the host', async () => {
  const net = installFetch();
  net.on('GET', /\/api\/ping$/, () => json(200, { ok: true }));
  const { get } = await freshClient();
  await get('/api/ping');
  expect(net.calls[0].url).toBe('/api/ping');
});
