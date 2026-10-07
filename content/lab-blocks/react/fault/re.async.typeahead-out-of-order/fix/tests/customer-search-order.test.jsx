import { act, fireEvent, render, screen } from '@testing-library/react';
import { installFetch } from '@mf/harness';
import CustomersPage from '@/features/customers/CustomersPage.jsx';

test('an old search answer arriving late does not replace the current results', async () => {
  const net = installFetch();
  const search = net.hold('GET', '/api/customers');
  render(<CustomersPage />);
  const box = screen.getByLabelText('Search customers');
  fireEvent.change(box, { target: { value: 'a' } });
  fireEvent.change(box, { target: { value: 'al' } });
  await act(async () => search.requests[1].respond(200, [{ id: 1, name: 'Alice Nguyen', email: 'alice@shop.test' }]));
  await act(async () => search.requests[0].respond(200, [{ id: 5, name: 'Aaron Pike', email: 'aaron@shop.test' }]));
  expect(screen.queryByText(/Aaron Pike/)).not.toBeInTheDocument();
});
