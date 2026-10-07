export const STATUSES = ['all', 'pending', 'paid', 'shipped'];

export function StatusFilter({ value, onChange }) {
  return (
    <label>
      Status{' '}
      <select value={value} onChange={(event) => onChange(event.target.value)}>
        {STATUSES.map((status) => (
          <option key={status} value={status}>
            {status}
          </option>
        ))}
      </select>
    </label>
  );
}

export function RefreshBadge({ seconds, loading }) {
  return <span className="refresh">{loading ? 'Refreshing...' : `Updated ${seconds}s ago`}</span>;
}
