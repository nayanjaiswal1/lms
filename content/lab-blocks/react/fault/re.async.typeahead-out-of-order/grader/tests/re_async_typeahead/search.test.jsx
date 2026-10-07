import { act, fireEvent, render, screen } from '@testing-library/react';
import { installFetch } from '@mf/harness';
import CustomersPage from '@/features/customers/CustomersPage.jsx';

const AARON = { id: 5, name: 'Aaron Pike', email: 'aaron@shop.test' };
const ALICE = { id: 1, name: 'Alice Nguyen', email: 'alice@shop.test' };
const ALINA = { id: 2, name: 'Alina Reyes', email: 'alina@shop.test' };

function setup() {
  const net = installFetch();
  const search = net.hold('GET', '/api/customers');
  render(<CustomersPage />);
  const box = screen.getByLabelText('Search customers');
  return { search, type: (text) => fireEvent.change(box, { target: { value: text } }) };
}

const answer = (request, body) => act(async () => request.respond(200, body));

test('a late answer for an older query is not shown', async () => {
  const { search, type } = setup();
  type('a');
  type('al');
  expect(search.requests).toHaveLength(2);
  await answer(search.requests[1], [ALICE]);
  expect(await screen.findByText(/Alice Nguyen/)).toBeInTheDocument();
  await answer(search.requests[0], [AARON, ALICE]);
  expect(screen.queryByText(/Aaron Pike/)).not.toBeInTheDocument();
  expect(screen.getByText(/Alice Nguyen/)).toBeInTheDocument();
});

test('the last query wins whatever the order of the answers', async () => {
  const { search, type } = setup();
  type('a');
  type('al');
  type('ali');
  expect(search.requests).toHaveLength(3);
  await answer(search.requests[2], [ALICE]);
  await answer(search.requests[0], [AARON]);
  await answer(search.requests[1], [ALICE, ALINA]);
  expect(screen.getByText(/Alice Nguyen/)).toBeInTheDocument();
  expect(screen.queryByText(/Alina Reyes/)).not.toBeInTheDocument();
  expect(screen.queryByText(/Aaron Pike/)).not.toBeInTheDocument();
});
