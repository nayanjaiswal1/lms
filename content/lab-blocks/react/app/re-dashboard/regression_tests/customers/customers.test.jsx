import { fireEvent, render, screen } from '@testing-library/react';
import { installFetch } from '@mf/harness';
import CustomersPage from '@/features/customers/CustomersPage.jsx';

const ALICE = { id: 1, name: 'Alice Nguyen', email: 'alice@shop.test' };

test('typing searches customers and lists the matches', async () => {
  const net = installFetch();
  net.on('GET', '/api/customers', () => [ALICE]);
  render(<CustomersPage />);
  fireEvent.change(screen.getByLabelText('Search customers'), { target: { value: 'ali' } });
  expect(await screen.findByText('Alice Nguyen (alice@shop.test)')).toBeInTheDocument();
  expect(net.calls[0].url).toBe('/api/customers?q=ali');
});

test('an empty search shows no results and sends no request', () => {
  const net = installFetch();
  render(<CustomersPage />);
  expect(screen.getByRole('list', { name: 'Search results' }).children).toHaveLength(0);
  expect(net.calls).toHaveLength(0);
});

test('a selected customer can be edited and saved', async () => {
  const net = installFetch();
  net.on('GET', '/api/customers/1', () => ALICE);
  net.on('GET', '/api/customers', () => [ALICE]);
  net.on('PUT', '/api/customers/1', (call) => ({ id: 1, ...call.body }));
  render(<CustomersPage />);
  fireEvent.change(screen.getByLabelText('Search customers'), { target: { value: 'ali' } });
  fireEvent.click(await screen.findByText('Alice Nguyen (alice@shop.test)'));
  const name = await screen.findByLabelText('Name');
  expect(name).toHaveValue('Alice Nguyen');
  fireEvent.change(name, { target: { value: 'Alice N.' } });
  fireEvent.click(screen.getByText('Save'));
  expect(await screen.findByRole('status')).toHaveTextContent('Saved');
  expect(net.calls.find((call) => call.method === 'PUT').body).toEqual({ name: 'Alice N.', email: 'alice@shop.test' });
});
