import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { installFetch } from '@mf/harness';
import CustomersPage from '@/features/customers/CustomersPage.jsx';

test('the editor shows the customer that was selected last', async () => {
  const net = installFetch();
  const alice = { id: 1, name: 'Alice Nguyen', email: 'alice@shop.test' };
  const bob = { id: 2, name: 'Bob Okafor', email: 'bob@shop.test' };
  net.on('GET', '/api/customers', () => [alice, bob]);
  net.on('GET', '/api/customers/1', () => alice);
  net.on('GET', '/api/customers/2', () => bob);
  render(<CustomersPage />);
  fireEvent.change(screen.getByLabelText('Search customers'), { target: { value: 'o' } });
  fireEvent.click(await screen.findByText('Alice Nguyen (alice@shop.test)'));
  await waitFor(() => expect(screen.getByLabelText('Name')).toHaveValue('Alice Nguyen'));
  fireEvent.click(screen.getByText('Bob Okafor (bob@shop.test)'));
  await waitFor(() => expect(screen.getByLabelText('Name')).toHaveValue('Bob Okafor'));
});
