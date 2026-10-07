import { fireEvent, render, screen } from '@testing-library/react';
import { installFetch, json } from '@mf/harness';
import CustomerForm from '@/features/customers/CustomerForm.jsx';
import { ApiError, get, put } from '@/lib/api.js';

const ALICE = { id: 1, name: 'Alice Nguyen', email: 'alice@shop.test' };

test.each([400, 404, 422, 500, 502, 503])('a %i response rejects with an ApiError carrying the status', async (status) => {
  const net = installFetch();
  net.on('GET', '/api/ping', () => json(status, { error: 'no' }));
  await expect(get('/api/ping')).rejects.toMatchObject({ name: 'ApiError', status });
  expect(net.calls).toHaveLength(1);
});

test('successful statuses still resolve', async () => {
  const net = installFetch();
  net.on('PUT', '/api/things/1', () => json(200, { ok: true }));
  net.on('GET', '/api/empty', () => json(204));
  await expect(put('/api/things/1', {})).resolves.toEqual({ ok: true });
  await expect(get('/api/empty')).resolves.toBeNull();
  expect(new ApiError(503, 'x').status).toBe(503);
});

test('the customer form reports a failed save instead of Saved', async () => {
  const net = installFetch();
  net.on('PUT', '/api/customers/1', () => json(503, { error: 'unavailable' }));
  render(<CustomerForm customer={ALICE} />);
  fireEvent.click(screen.getByText('Save'));
  expect(await screen.findByRole('alert')).toHaveTextContent('Could not save the customer.');
  expect(screen.queryByRole('status')).not.toBeInTheDocument();
});
