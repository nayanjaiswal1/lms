import { fireEvent, render, screen } from '@testing-library/react';
import { installFetch } from '@mf/harness';
import CatalogPage from '@/features/catalog/CatalogPage.jsx';
import { searchProducts } from '@/features/catalog/searchProducts.js';

test.each([
  ['R&D Kit', '/api/products?q=R%26D%20Kit'],
  ['+ Mic', '/api/products?q=%2B%20Mic'],
  ['a#b', '/api/products?q=a%23b'],
  ['50%', '/api/products?q=50%25'],
  ['mouse', '/api/products?q=mouse'],
])('searching for %s requests %s', async (query, url) => {
  const net = installFetch();
  net.on('GET', '/api/products', () => ({ items: [] }));
  await searchProducts(query);
  expect(net.calls[0].url).toBe(url);
});

test('the search box sends the whole typed text', async () => {
  const net = installFetch();
  net.on('GET', '/api/products', () => ({ items: [] }));
  render(<CatalogPage />);
  await screen.findByText('No products match.');
  fireEvent.change(screen.getByLabelText('Search products'), { target: { value: 'R&D Kit' } });
  fireEvent.click(screen.getByRole('button', { name: 'Search' }));
  await screen.findByText('No products match.');
  expect(net.calls.map((call) => call.url)).toContain('/api/products?q=R%26D%20Kit');
});
