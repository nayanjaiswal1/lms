import { installFetch, json } from '@mf/harness';

test('the API client uses VITE_API_URL', async () => {
  vi.stubEnv('VITE_API_URL', 'https://api.example.test');
  vi.resetModules();
  const net = installFetch();
  net.on('GET', /\/api\/ping$/, () => json(200, {}));
  const { get } = await import('@/lib/api.js');
  await get('/api/ping');
  expect(net.calls[0].url).toBe('https://api.example.test/api/ping');
});
