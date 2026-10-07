import { fireEvent, render, screen } from '@testing-library/react';
import { installFetch } from '@mf/harness';
import CatalogPage from '@/features/catalog/CatalogPage.jsx';

const MOUSE = { id: 2, sku: 'MS-210', name: 'Wireless Mouse', price_cents: 3450, stock: 40 };
const SSD = { id: 11, sku: 'SD-512', name: '512GB SSD', price_cents: 9900, stock: 0 };

test('the catalog lists every product on load', async () => {
  const net = installFetch();
  net.on('GET', '/api/products', () => ({ items: [MOUSE, SSD] }));
  render(<CatalogPage />);
  expect(await screen.findByText('Wireless Mouse')).toBeInTheDocument();
  expect(screen.getByText('$34.50')).toBeInTheDocument();
  expect(screen.getByText('40 in stock')).toBeInTheDocument();
  expect(screen.getByText('Out of stock')).toBeInTheDocument();
  expect(net.calls.map((call) => call.url)).toContain('/api/products?q=');
});

test('searching sends the typed text', async () => {
  const net = installFetch();
  net.on('GET', '/api/products', () => ({ items: [MOUSE] }));
  render(<CatalogPage />);
  await screen.findByText('Wireless Mouse');
  fireEvent.change(screen.getByLabelText('Search products'), { target: { value: 'mouse' } });
  fireEvent.click(screen.getByRole('button', { name: 'Search' }));
  await screen.findByText('Wireless Mouse');
  expect(net.calls.map((call) => call.url)).toContain('/api/products?q=mouse');
});

test('an empty result says so', async () => {
  const net = installFetch();
  net.on('GET', '/api/products', () => ({ items: [] }));
  render(<CatalogPage />);
  expect(await screen.findByText('No products match.')).toBeInTheDocument();
});
