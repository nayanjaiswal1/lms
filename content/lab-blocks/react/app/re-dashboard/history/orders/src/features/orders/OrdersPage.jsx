import { useMemo, useState } from 'react';
import Pagination from '../../components/Pagination.jsx';
import { useElapsedSeconds } from '../../hooks/useElapsedSeconds.js';
import OrdersTable from './OrdersTable.jsx';
import { RefreshBadge, StatusFilter } from './OrdersToolbar.jsx';
import ToolsMenu from './ToolsMenu.jsx';
import { useOrders } from './useOrders.js';

export default function OrdersPage({ filter = '' }) {
  const [status, setStatus] = useState('all');
  const [page, setPage] = useState(1);
  const { items, pages, loading, error, updates } = useOrders(status, page);
  const seconds = useElapsedSeconds(updates);

  const visible = useMemo(() => {
    const term = filter.trim().toLowerCase();
    if (term === '') return items;
    return items.filter((order) => order.customer.toLowerCase().includes(term) || String(order.id) === term);
  }, [items, filter]);

  function changeStatus(next) {
    setStatus(next);
    setPage(1);
  }

  return (
    <section aria-labelledby="orders-title">
      <h2 id="orders-title">Orders</h2>
      <div className="toolbar">
        <StatusFilter value={status} onChange={changeStatus} />
        <RefreshBadge seconds={seconds} loading={loading} />
        <ToolsMenu orders={visible} />
      </div>
      {error && <p role="alert">Could not load orders.</p>}
      <OrdersTable orders={visible} loading={loading} />
      <Pagination page={page} pages={pages} onChange={setPage} />
    </section>
  );
}
