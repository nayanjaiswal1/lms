import { fireEvent, render, screen } from '@testing-library/react';
import { installFetch, json } from '@mf/harness';
import ProfilePage from '@/features/profile/ProfilePage.jsx';

const PROFILE = { name: 'Alice Nguyen', email: 'alice@shop.test', phone: '555-0100', version: 1 };

test('the profile is loaded into the form', async () => {
  const net = installFetch();
  net.on('GET', '/api/profile', () => PROFILE);
  render(<ProfilePage />);
  expect(await screen.findByLabelText('Name')).toHaveValue('Alice Nguyen');
  expect(screen.getByLabelText('Phone')).toHaveValue('555-0100');
  expect(screen.getByText('alice@shop.test')).toBeInTheDocument();
});

test('a save sends the version it was based on and shows the result', async () => {
  const net = installFetch();
  net.on('GET', '/api/profile', () => PROFILE);
  net.on('PUT', '/api/profile', (call) => ({ ...PROFILE, name: call.body.name, version: 2 }));
  render(<ProfilePage />);

  fireEvent.change(await screen.findByLabelText('Name'), { target: { value: 'Alice N.' } });
  fireEvent.click(screen.getByRole('button', { name: 'Save' }));

  expect(await screen.findByRole('status')).toHaveTextContent('Profile saved.');
  expect(net.calls.find((call) => call.method === 'PUT').body).toEqual({ name: 'Alice N.', phone: '555-0100', version: 1 });
  expect(screen.getByLabelText('Name')).toHaveValue('Alice N.');
});

test('a version conflict tells the customer to reload', async () => {
  const net = installFetch();
  net.on('GET', '/api/profile', () => PROFILE);
  net.on('PUT', '/api/profile', () => json(409, { error: { code: 'version_conflict', message: 'changed' } }));
  render(<ProfilePage />);

  await screen.findByLabelText('Name');
  fireEvent.click(screen.getByRole('button', { name: 'Save' }));
  expect(await screen.findByRole('alert')).toHaveTextContent('changed in another tab or device');
});
