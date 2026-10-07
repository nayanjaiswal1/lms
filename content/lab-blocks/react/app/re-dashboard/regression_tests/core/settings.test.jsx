import { fireEvent, render, screen } from '@testing-library/react';
import { DEFAULT_SETTINGS, SettingsProvider, useSettings } from '@/context/settings.jsx';

function Readout() {
  const { currency, density, update } = useSettings();
  return (
    <div>
      <output aria-label="currency">{currency}</output>
      <output aria-label="density">{density}</output>
      <button type="button" onClick={() => update({ currency: 'EUR' })}>
        euro
      </button>
    </div>
  );
}

beforeEach(() => localStorage.clear());

test('settings start from the defaults', () => {
  render(
    <SettingsProvider>
      <Readout />
    </SettingsProvider>,
  );
  expect(screen.getByLabelText('currency')).toHaveTextContent(DEFAULT_SETTINGS.currency);
  expect(screen.getByLabelText('density')).toHaveTextContent(DEFAULT_SETTINGS.density);
});

test('update changes the value and keeps the other settings', () => {
  render(
    <SettingsProvider>
      <Readout />
    </SettingsProvider>,
  );
  fireEvent.click(screen.getByText('euro'));
  expect(screen.getByLabelText('currency')).toHaveTextContent('EUR');
  expect(screen.getByLabelText('density')).toHaveTextContent(DEFAULT_SETTINGS.density);
});

test('settings are persisted and restored', () => {
  const first = render(
    <SettingsProvider>
      <Readout />
    </SettingsProvider>,
  );
  fireEvent.click(screen.getByText('euro'));
  expect(JSON.parse(localStorage.getItem('mf-settings')).currency).toBe('EUR');
  first.unmount();

  render(
    <SettingsProvider>
      <Readout />
    </SettingsProvider>,
  );
  expect(screen.getByLabelText('currency')).toHaveTextContent('EUR');
});

test('unreadable stored settings fall back to the defaults', () => {
  localStorage.setItem('mf-settings', '{not json');
  render(
    <SettingsProvider>
      <Readout />
    </SettingsProvider>,
  );
  expect(screen.getByLabelText('currency')).toHaveTextContent(DEFAULT_SETTINGS.currency);
});

test('useSettings outside a provider is an error', () => {
  const quiet = vi.spyOn(console, 'error').mockImplementation(() => {});
  expect(() => render(<Readout />)).toThrow('SettingsProvider');
  quiet.mockRestore();
});
