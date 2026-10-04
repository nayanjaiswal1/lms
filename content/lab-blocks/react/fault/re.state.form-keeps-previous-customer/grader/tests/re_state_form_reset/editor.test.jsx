import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { installFetch } from '@mf/harness';
import CustomersPage from '@/features/customers/CustomersPage.jsx';

const ALICE = { id: 1, name: 'Alice Nguyen', email: 'alice@shop.test' };
const BOB = { id: 2, name: 'Bob Okafor', email: 'bob@shop.test' };
const SAM_A = { id: 3, name: 'Sam Lee', email: 'sam.a@shop.test' };
const SAM_B = { id: 4, name: 'Sam Lee', email: 'sam.b@shop.test' };

function setup(customers) {
  const net = installFetch();
  net.on('GET', '/api/customers', () => customers);
  for (const customer of customers) net.on('GET', `/api/customers/${customer.id}`, () => customer);
  render(<CustomersPage />);
  fireEvent.change(screen.getByLabelText('Search customers'), { target: { value: 'x' } });
}

async function select(customer) {
  fireEvent.click(await screen.findByText(`${customer.name} (${customer.email})`));
  await waitFor(() => expect(screen.getByLabelText('Email')).toHaveValue(customer.email));
}

test('selecting another customer shows that customer in the form', async () => {
  setup([ALICE, BOB]);
  await select(ALICE);
  await select(BOB);
  expect(screen.getByLabelText('Name')).toHaveValue('Bob Okafor');
});

test('two customers with the same name are not mixed up', async () => {
  setup([SAM_A, SAM_B]);
  await select(SAM_A);
  await select(SAM_B);
  expect(screen.getByLabelText('Email')).toHaveValue('sam.b@shop.test');
});

test('an edit in progress is dropped when another customer is selected', async () => {
  setup([ALICE, BOB]);
  await select(ALICE);
  fireEvent.change(screen.getByLabelText('Name'), { target: { value: 'Alice Typo' } });
  await select(BOB);
  expect(screen.getByLabelText('Name')).toHaveValue('Bob Okafor');
});
