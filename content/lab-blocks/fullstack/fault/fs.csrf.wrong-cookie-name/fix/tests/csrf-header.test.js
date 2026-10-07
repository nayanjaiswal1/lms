import { installFetch, json } from '@mf/harness';
import { put } from '@/lib/api.js';

test('a state-changing request echoes the csrf_token cookie in the header', async () => {
  document.cookie = 'csrf_token=tok-123; path=/';
  const net = installFetch();
  net.on('PUT', '/api/things/1', () => json(200, { ok: true }));
  await put('/api/things/1', {});
  expect(net.fetch.mock.calls[0][1].headers['X-CSRF-Token']).toBe('tok-123');
});
