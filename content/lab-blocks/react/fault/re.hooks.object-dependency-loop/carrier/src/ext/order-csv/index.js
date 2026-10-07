const COLUMNS = ['id', 'customer', 'status', 'total_cents'];

const cell = (value) => (String(value).includes(',') ? `"${value}"` : String(value));

export default {
  id: 'order-csv',
  label: 'Copy as CSV',
  run(orders) {
    const rows = orders.map((order) => COLUMNS.map((column) => cell(order[column])).join(','));
    return [COLUMNS.join(','), ...rows].join('\n');
  },
};
