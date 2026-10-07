import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { installFetch } from '@mf/harness';
import NotesPanel from '@/features/notes/NotesPanel.jsx';

const NOTES = [
  { id: 1, order_id: 4, text: 'Called the customer' },
  { id: 2, order_id: 4, text: 'Refund approved' },
];

function setup() {
  const net = installFetch();
  net.on('GET', '/api/orders/4/notes', () => NOTES);
  net.on('POST', '/api/orders/4/notes', (call) => ({ id: 3, order_id: 4, text: call.body.text }));
  net.on('PUT', '/api/notes/2', (call) => ({ id: 2, order_id: 4, text: call.body.text }));
  net.on('DELETE', '/api/notes/1', () => new Response(null, { status: 204 }));
  render(<NotesPanel orderId={4} />);
  return net;
}

test('the notes of the order are listed', async () => {
  setup();
  const list = await screen.findByRole('list', { name: 'Notes for order 4' });
  const inputs = within(list).getAllByLabelText('Note text');
  expect(inputs.map((input) => input.value)).toEqual(['Called the customer', 'Refund approved']);
});

test('a new note is added to the end of the list', async () => {
  const net = setup();
  await screen.findByRole('list', { name: 'Notes for order 4' });
  fireEvent.change(screen.getByLabelText('New note'), { target: { value: 'Shipped today' } });
  fireEvent.click(screen.getByText('Add note'));
  expect(await screen.findByDisplayValue('Shipped today')).toBeInTheDocument();
  expect(net.calls.find((call) => call.method === 'POST').body).toEqual({ text: 'Shipped today' });
});

test('an edited note is saved on request', async () => {
  const net = setup();
  const [, second] = await screen.findAllByLabelText('Note text');
  fireEvent.change(second, { target: { value: 'Refund sent' } });
  fireEvent.click(screen.getByText('Save'));
  expect(await screen.findByDisplayValue('Refund sent')).toBeInTheDocument();
  expect(net.calls.find((call) => call.method === 'PUT').body).toEqual({ text: 'Refund sent' });
});


test('a deleted note leaves the list', async () => {
  const net = setup();
  const [first] = await screen.findAllByRole('button', { name: 'Delete note' });
  fireEvent.click(first);
  await waitFor(() => expect(screen.getAllByLabelText('Note text')).toHaveLength(1));
  expect(net.calls.some((call) => call.method === 'DELETE' && call.url === '/api/notes/1')).toBe(true);
});
