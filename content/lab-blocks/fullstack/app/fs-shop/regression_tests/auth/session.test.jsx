import { fireEvent, render, screen } from '@testing-library/react';
import { installFetch, json } from '@mf/harness';
import App from '@/App.jsx';

const USER = { id: 1, email: 'alice@shop.test', name: 'Alice Nguyen' };
const NOT_SIGNED_IN = { error: { code: 'not_authenticated', message: 'Sign in to continue.' } };

test('a visitor sees the sign-in form and can sign in', async () => {
  const net = installFetch();
  net.on('GET', '/api/auth/me', () => json(401, NOT_SIGNED_IN));
  net.on('POST', '/api/auth/login', () => ({ user: USER }));
  render(<App />);

  fireEvent.change(await screen.findByLabelText('Email'), { target: { value: 'alice@shop.test' } });
  fireEvent.change(screen.getByLabelText('Password'), { target: { value: 'correct-horse-battery' } });
  fireEvent.click(screen.getByRole('button', { name: 'Sign in' }));

  expect(await screen.findByText('Alice Nguyen')).toBeInTheDocument();
  const login = net.calls.find((call) => call.url === '/api/auth/login');
  expect(login.body).toEqual({ email: 'alice@shop.test', password: 'correct-horse-battery' });
});

test('a wrong password shows the server message', async () => {
  const net = installFetch();
  net.on('GET', '/api/auth/me', () => json(401, NOT_SIGNED_IN));
  net.on('POST', '/api/auth/login', () => json(401, { error: { code: 'invalid_credentials', message: 'Wrong email or password.' } }));
  render(<App />);

  fireEvent.change(await screen.findByLabelText('Email'), { target: { value: 'alice@shop.test' } });
  fireEvent.change(screen.getByLabelText('Password'), { target: { value: 'nope' } });
  fireEvent.click(screen.getByRole('button', { name: 'Sign in' }));

  expect(await screen.findByRole('alert')).toHaveTextContent('Wrong email or password.');
});

test('a returning customer is signed in from the session and can sign out', async () => {
  const net = installFetch();
  net.on('GET', '/api/auth/me', () => ({ user: USER }));
  net.on('POST', '/api/auth/logout', () => ({ ok: true }));
  render(<App />);

  expect(await screen.findByText('Alice Nguyen')).toBeInTheDocument();
  fireEvent.click(screen.getByRole('button', { name: 'Sign out' }));
  expect(await screen.findByRole('form', { name: 'Sign in' })).toBeInTheDocument();
  expect(net.count('POST', '/api/auth/logout')).toBe(1);
});
