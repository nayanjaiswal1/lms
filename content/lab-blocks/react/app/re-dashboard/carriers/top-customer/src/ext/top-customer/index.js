export default {
  id: 'top-customer',
  label: 'Top customer',
  run(orders) {
    const counts = new Map();
    for (const order of orders) counts.set(order.customer, (counts.get(order.customer) ?? 0) + 1);
    if (counts.size === 0) return 'No orders';
    const [name, count] = [...counts.entries()].sort(([a, x], [b, y]) => y - x || a.localeCompare(b))[0];
    return `${name} (${count} ${count === 1 ? 'order' : 'orders'})`;
  },
};
