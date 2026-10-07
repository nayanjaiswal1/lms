export default {
  id: 'status-breakdown',
  label: 'Status breakdown',
  run(orders) {
    const counts = {};
    for (const order of orders) counts[order.status] = (counts[order.status] ?? 0) + 1;
    const parts = Object.keys(counts)
      .sort()
      .map((status) => `${status}: ${counts[status]}`);
    return parts.length ? parts.join(', ') : 'No orders';
  },
};
