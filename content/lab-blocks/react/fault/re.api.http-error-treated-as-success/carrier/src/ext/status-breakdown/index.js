export default {
  id: 'status-breakdown',
  label: 'By status',
  run(orders) {
    const counts = new Map();
    for (const order of orders) counts.set(order.status, (counts.get(order.status) ?? 0) + 1);
    if (counts.size === 0) return 'No orders';
    return [...counts.entries()]
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([status, count]) => `${status}: ${count}`)
      .join(', ');
  },
};
