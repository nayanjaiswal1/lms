import { useSettings } from '../../context/settings.jsx';
import { useViewportWidth } from '../../hooks/useViewportWidth.js';
import { formatDateTime, formatMoney } from '../../lib/format.js';
import { useFlagToggle } from './useFlagToggle.js';

const COMPACT_BELOW = 700;

function OrderRow({ order, currency, compact }) {
  const { flagged, toggle, error } = useFlagToggle(order);
  return (
    <tr>
      <td>{order.id}</td>
      <td>{order.customer}</td>
      <td>{order.status}</td>
      {!compact && <td>{formatDateTime(order.placed_at)}</td>}
      <td>{formatMoney(order.total_cents, currency)}</td>
      <td>
        <button type="button" aria-pressed={flagged} aria-label={`Flag order ${order.id}`} onClick={toggle}>
          {flagged ? 'Flagged' : 'Flag'}
        </button>
        {error && <span role="alert">Could not update the flag.</span>}
      </td>
    </tr>
  );
}

export default function OrdersTable({ orders, loading }) {
  const { currency, density } = useSettings();
  const compact = useViewportWidth() < COMPACT_BELOW;

  if (!loading && orders.length === 0) return <p>No orders match.</p>;
  return (
    <table className={`orders ${density}`} aria-busy={loading}>
      <thead>
        <tr>
          <th>#</th>
          <th>Customer</th>
          <th>Status</th>
          {!compact && <th>Placed</th>}
          <th>Total</th>
          <th>Flag</th>
        </tr>
      </thead>
      <tbody>
        {orders.map((order) => (
          <OrderRow key={order.id} order={order} currency={currency} compact={compact} />
        ))}
      </tbody>
    </table>
  );
}
