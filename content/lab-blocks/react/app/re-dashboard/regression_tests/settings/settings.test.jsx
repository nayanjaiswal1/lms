import { fireEvent, render, screen } from '@testing-library/react';
import SettingsPage from '@/features/settings/SettingsPage.jsx';
import { SettingsProvider } from '@/context/settings.jsx';

function renderPage() {
  localStorage.clear();
  render(
    <SettingsProvider>
      <SettingsPage />
    </SettingsProvider>,
  );
}

test('the currency can be changed and is stored', () => {
  renderPage();
  fireEvent.change(screen.getByLabelText('Currency'), { target: { value: 'EUR' } });
  expect(screen.getByLabelText('Currency')).toHaveValue('EUR');
  expect(JSON.parse(localStorage.getItem('mf-settings')).currency).toBe('EUR');
});

test('the table density can be switched', () => {
  renderPage();
  expect(screen.getByLabelText('comfortable')).toBeChecked();
  fireEvent.click(screen.getByLabelText('compact'));
  expect(screen.getByLabelText('compact')).toBeChecked();
});
