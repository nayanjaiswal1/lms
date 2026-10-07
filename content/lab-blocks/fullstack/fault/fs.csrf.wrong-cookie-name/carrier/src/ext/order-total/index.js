import { formatMoney } from '../../lib/format.js';

export default {
  id: 'order-total',
  label: 'Page total',
  run(orders) {
    const cents = orders.reduce((sum, order) => sum + order.total_cents, 0);
    return `Total: ${formatMoney(cents)}`;
  },
};
