import { installFetch } from '@mf/harness';
import { searchProducts } from '@/features/catalog/searchProducts.js';

test('reserved characters in the query are percent-encoded', async () => {
  const net = installFetch();
  net.on('GET', '/api/products', () => ({ items: [] }));
  await searchProducts('R&D Kit');
  expect(net.calls[0].url).toBe('/api/products?q=R%26D%20Kit');
});
