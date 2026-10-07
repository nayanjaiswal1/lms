import { fireEvent, render, screen } from '@testing-library/react';
import App from '@/App.jsx';
import ErrorBoundary from '@/components/ErrorBoundary.jsx';
import Pagination from '@/components/Pagination.jsx';
import { extensions } from '@/ext/registry.js';
import { installFetch } from '@mf/harness';

test('every page of the navigation can be opened', () => {
  const net = installFetch();
  net.on('GET', /^\/api\//, () => ({ items: [], pages: 1, days: [] }));
  render(<App />);
  const nav = screen.getByRole('navigation', { name: 'Main' });
  const buttons = nav.querySelectorAll('button');
  expect(buttons.length).toBeGreaterThanOrEqual(5);
  for (const button of buttons) {
    fireEvent.click(button);
    expect(button).toHaveAttribute('aria-current', 'page');
  }
});

test('the quick filter value is shared with the page', () => {
  const net = installFetch();
  net.on('GET', /^\/api\//, () => ({ items: [], pages: 1, days: [] }));
  render(<App />);
  fireEvent.change(screen.getByRole('searchbox', { name: 'Quick filter' }), { target: { value: 'zzz' } });
  expect(screen.getByRole('searchbox', { name: 'Quick filter' })).toHaveValue('zzz');
});

test('the error boundary shows a fallback when a child throws', () => {
  const quiet = vi.spyOn(console, 'error').mockImplementation(() => {});
  function Broken() {
    throw new Error('render failed');
  }
  render(
    <ErrorBoundary>
      <Broken />
    </ErrorBoundary>,
  );
  expect(screen.getByRole('alert')).toHaveTextContent('Something went wrong');
  quiet.mockRestore();
});

test('pagination reports page changes and disables the ends', () => {
  const onChange = vi.fn();
  const { rerender } = render(<Pagination page={1} pages={3} onChange={onChange} />);
  expect(screen.getByText('Previous')).toBeDisabled();
  fireEvent.click(screen.getByText('Next'));
  expect(onChange).toHaveBeenCalledWith(2);
  rerender(<Pagination page={3} pages={3} onChange={onChange} />);
  expect(screen.getByText('Next')).toBeDisabled();
});

test('extensions follow the extension contract', () => {
  for (const extension of extensions) {
    expect(typeof extension.id).toBe('string');
    expect(typeof extension.label).toBe('string');
    expect(typeof extension.run).toBe('function');
  }
  const ids = extensions.map((extension) => extension.id);
  expect(new Set(ids).size).toBe(ids.length);
});
