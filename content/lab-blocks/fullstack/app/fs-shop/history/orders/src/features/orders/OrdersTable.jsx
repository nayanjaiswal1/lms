import { formatDate, formatMoney } from '../../lib/format.js';

export default function OrdersTable({ orders }) {
  return (
    <table>
      <caption>Orders</caption>
      <thead>
        <tr>
          <th scope="col">Order</th>
          <th scope="col">Status</th>
          <th scope="col">Items</th>
          <th scope="col">Total</th>
          <th scope="col">Placed</th>
        </tr>
      </thead>
      <tbody>
        {orders.map((order) => (
          <tr key={order.id}>
            <td>#{order.id}</td>
            <td>{order.status}</td>
            <td>{order.item_count}</td>
            <td>{formatMoney(order.total_cents)}</td>
            <td>{formatDate(order.placed_at)}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
