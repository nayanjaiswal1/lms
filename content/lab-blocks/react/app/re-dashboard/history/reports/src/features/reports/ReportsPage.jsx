import { useState } from 'react';
import { useSettings } from '../../context/settings.jsx';
import { formatMoney } from '../../lib/format.js';
import RevenueTable from './RevenueTable.jsx';
import { useRevenue } from './useRevenue.js';

const RANGES = [7, 30, 90];

export default function ReportsPage({ filter = '' }) {
  const [range, setRange] = useState(30);
  const { currency } = useSettings();
  const { days, loading, error } = useRevenue({ days: range });
  const total = days.reduce((sum, day) => sum + day.revenue_cents, 0);

  return (
    <section aria-labelledby="reports-title">
      <h2 id="reports-title">Revenue</h2>
      <div className="toolbar">
        <label>
          Range{' '}
          <select value={range} onChange={(event) => setRange(Number(event.target.value))}>
            {RANGES.map((value) => (
              <option key={value} value={value}>
                Last {value} days
              </option>
            ))}
          </select>
        </label>
        <strong>Total {formatMoney(total, currency)}</strong>
      </div>
      {error && <p role="alert">Could not load the report.</p>}
      {loading ? <p>Loading...</p> : <RevenueTable days={days} filter={filter} />}
    </section>
  );
}
