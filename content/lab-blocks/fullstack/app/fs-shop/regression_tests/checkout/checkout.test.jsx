import { fireEvent, render, screen } from '@testing-library/react';
import { installFetch, json } from '@mf/harness';
import CheckoutPage from '@/features/checkout/CheckoutPage.jsx';

const PRODUCTS = [
  { id: 2, sku: 'MS-210', name: 'Wireless Mouse', price_cents: 3450, stock: 40 },
  { id: 3, sku: 'RD-301', name: 'R&D Kit', price_cents: 15900, stock: 6 },
];

function stubShop(net) {
  net.on('GET', '/api/products', () => ({ items: PRODUCTS }));
}

test('an order is placed with the chosen product and quantity', async () => {
  const net = installFetch();
  stubShop(net);
  net.on('POST', '/api/orders', () => json(201, { id: 27, status: 'pending', total_cents: 6900, item_count: 2 }));
  render(<CheckoutPage />);

  fireEvent.change(await screen.findByLabelText('Product'), { target: { value: '2' } });
  fireEvent.change(screen.getByLabelText('Quantity'), { target: { value: '2' } });
  fireEvent.click(screen.getByRole('button', { name: 'Place order' }));

  expect(await screen.findByRole('status')).toHaveTextContent('Order #27 placed: $69.00');
  expect(net.calls.find((call) => call.method === 'POST').body).toEqual({ items: [{ product_id: 2, quantity: 2 }] });
});

test('the server message is shown when the order is refused', async () => {
  const net = installFetch();
  stubShop(net);
  net.on('POST', '/api/orders', () =>
    json(409, { error: { code: 'insufficient_stock', message: 'Only 6 left of R&D Kit.' } }),
  );
  render(<CheckoutPage />);

  await screen.findByLabelText('Product');
  fireEvent.click(screen.getByRole('button', { name: 'Place order' }));
  expect(await screen.findByRole('alert')).toHaveTextContent('Only 6 left of R&D Kit.');
});

test('the button is disabled while the order is being placed', async () => {
  const net = installFetch();
  stubShop(net);
  const held = net.hold('POST', '/api/orders');
  render(<CheckoutPage />);

  await screen.findByLabelText('Product');
  fireEvent.click(screen.getByRole('button', { name: 'Place order' }));
  expect(screen.getByRole('button', { name: 'Place order' })).toBeDisabled();
  held.requests[0].respond(201, { id: 27, status: 'pending', total_cents: 3450, item_count: 1 });
  expect(await screen.findByRole('status')).toBeInTheDocument();
});
