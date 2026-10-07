export default {
  id: 'flagged-count',
  label: 'Flagged orders',
  run(orders) {
    const flagged = orders.filter((order) => order.flagged).length;
    return `${flagged} of ${orders.length} flagged`;
  },
};
