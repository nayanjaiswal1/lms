import { useSettings } from '../../context/settings.jsx';

const CURRENCIES = ['USD', 'EUR', 'GBP'];
const DENSITIES = ['comfortable', 'compact'];

export default function SettingsPage() {
  const { currency, density, update } = useSettings();

  return (
    <section aria-labelledby="settings-title">
      <h2 id="settings-title">Settings</h2>
      <label>
        Currency{' '}
        <select value={currency} onChange={(event) => update({ currency: event.target.value })}>
          {CURRENCIES.map((code) => (
            <option key={code} value={code}>
              {code}
            </option>
          ))}
        </select>
      </label>
      <fieldset>
        <legend>Table density</legend>
        {DENSITIES.map((value) => (
          <label key={value}>
            <input
              type="radio"
              name="density"
              value={value}
              checked={density === value}
              onChange={() => update({ density: value })}
            />{' '}
            {value}
          </label>
        ))}
      </fieldset>
    </section>
  );
}
