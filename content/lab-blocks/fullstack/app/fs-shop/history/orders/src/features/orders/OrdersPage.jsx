import { useState } from 'react';
import OrdersTable from './OrdersTable.jsx';
import ToolsMenu from './ToolsMenu.jsx';
import { useOrders } from './useOrders.js';

export default function OrdersPage() {
  const [page, setPage] = useState(1);
  const { status, orders, pages } = useOrders(page);

  return (
    <section>
      <h2>Your orders</h2>
      {status === 'error' && <p role="alert">Could not load orders.</p>}
      <OrdersTable orders={orders} />
      <div className="pagination">
        <button type="button" disabled={page <= 1} onClick={() => setPage(page - 1)}>
          Previous
        </button>
        <span>
          Page {page} of {pages}
        </span>
        <button type="button" disabled={page >= pages} onClick={() => setPage(page + 1)}>
          Next
        </button>
      </div>
      <ToolsMenu orders={orders} />
    </section>
  );
}
