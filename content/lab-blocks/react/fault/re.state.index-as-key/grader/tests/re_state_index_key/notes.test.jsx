import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { installFetch } from '@mf/harness';
import NotesPanel from '@/features/notes/NotesPanel.jsx';

function setup(notes) {
  const net = installFetch();
  net.on('GET', '/api/orders/4/notes', () => notes);
  net.on('DELETE', /^\/api\/notes\/\d+$/, () => new Response(null, { status: 204 }));
  render(<NotesPanel orderId={4} />);
}

const values = () => screen.getAllByLabelText('Note text').map((input) => input.value);

test('an unsaved edit stays with its note when an earlier note is deleted', async () => {
  setup([
    { id: 1, order_id: 4, text: 'Called the customer' },
    { id: 2, order_id: 4, text: 'Refund approved' },
    { id: 3, order_id: 4, text: 'Ship it' },
  ]);
  const inputs = await screen.findAllByLabelText('Note text');
  fireEvent.change(inputs[1], { target: { value: 'Refund approved by Dana' } });
  fireEvent.click(screen.getAllByRole('button', { name: 'Delete note' })[0]);
  await waitFor(() => expect(screen.getAllByLabelText('Note text')).toHaveLength(2));
  expect(values()).toEqual(['Refund approved by Dana', 'Ship it']);
});

test('the remaining notes show their own text after a delete', async () => {
  setup([
    { id: 1, order_id: 4, text: 'Called the customer' },
    { id: 2, order_id: 4, text: 'Refund approved' },
  ]);
  fireEvent.click((await screen.findAllByRole('button', { name: 'Delete note' }))[0]);
  await waitFor(() => expect(screen.getAllByLabelText('Note text')).toHaveLength(1));
  expect(values()).toEqual(['Refund approved']);
});

test('notes with identical text keep their own edits', async () => {
  setup([
    { id: 1, order_id: 4, text: 'Follow up' },
    { id: 2, order_id: 4, text: 'Follow up' },
    { id: 3, order_id: 4, text: 'Ship it' },
  ]);
  const inputs = await screen.findAllByLabelText('Note text');
  fireEvent.change(inputs[1], { target: { value: 'Follow up (call Monday)' } });
  fireEvent.click(screen.getAllByRole('button', { name: 'Delete note' })[0]);
  await waitFor(() => expect(screen.getAllByLabelText('Note text')).toHaveLength(2));
  expect(values()).toEqual(['Follow up (call Monday)', 'Ship it']);
});
