import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { installFetch } from '@mf/harness';
import NotesPanel from '@/features/notes/NotesPanel.jsx';

test('deleting a note keeps the unsaved edit of the next note', async () => {
  const net = installFetch();
  net.on('GET', '/api/orders/4/notes', () => [
    { id: 1, order_id: 4, text: 'first' },
    { id: 2, order_id: 4, text: 'second' },
  ]);
  net.on('DELETE', '/api/notes/1', () => new Response(null, { status: 204 }));
  render(<NotesPanel orderId={4} />);
  const [, second] = await screen.findAllByLabelText('Note text');
  fireEvent.change(second, { target: { value: 'second, edited' } });
  fireEvent.click(screen.getAllByRole('button', { name: 'Delete note' })[0]);
  await waitFor(() => expect(screen.getAllByLabelText('Note text')).toHaveLength(1));
  expect(screen.getByLabelText('Note text')).toHaveValue('second, edited');
});
