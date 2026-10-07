import { installFetch, json } from '@mf/harness';
import { get } from '@/lib/api.js';

test('a 503 response is an error, not a result', async () => {
  const net = installFetch();
  net.on('GET', '/api/ping', () => json(503, { error: 'unavailable' }));
  await expect(get('/api/ping')).rejects.toMatchObject({ status: 503 });
});
