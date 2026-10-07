import { memo, useMemo } from 'react';
import { useSettings } from '../../context/settings.jsx';
import { formatDay, formatMoney } from '../../lib/format.js';

const RevenueRow = memo(function RevenueRow({ day }) {
  const { currency } = useSettings();
  return (
    <tr>
      <td>{formatDay(day.date)}</td>
      <td>{day.orders}</td>
      <td>{formatMoney(day.revenue_cents, currency)}</td>
    </tr>
  );
});

/** One row per day. `filter` keeps the days whose ISO date contains the text. */
export default function RevenueTable({ days, filter }) {
  const rows = useMemo(() => {
    const term = filter.trim();
    return term === '' ? days : days.filter((day) => day.date.includes(term));
  }, [days, filter]);

  return (
    <table aria-label="Revenue by day">
      <thead>
        <tr>
          <th>Day</th>
          <th>Orders</th>
          <th>Revenue</th>
        </tr>
      </thead>
      <tbody>
        {rows.map((day) => (
          <RevenueRow key={day.date} day={day} />
        ))}
      </tbody>
    </table>
  );
}
