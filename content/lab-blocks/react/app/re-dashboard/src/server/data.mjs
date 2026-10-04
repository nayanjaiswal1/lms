// Deterministic in-memory dataset for the mock API (no database, no randomness
// beyond a fixed-seed generator, so every session sees the same shop).

let state = 20250310;
const random = () => {
  state = (state * 1664525 + 1013904223) % 4294967296;
  return state / 4294967296;
};
const pick = (list) => list[Math.floor(random() * list.length)];

const FIRST = ['Alice', 'Bob', 'Carol', 'Dan', 'Erin', 'Frank', 'Grace', 'Heidi', 'Ivan', 'Judy', 'Mallory', 'Niaj'];
const LAST = ['Nguyen', 'Okafor', 'Petrov', 'Garcia', 'Silva', 'Kim', 'Rossi', 'Haddad'];
const STATUSES = ['pending', 'paid', 'shipped'];
const LAST_DAY = Date.UTC(2025, 2, 10);
const DAY_MS = 24 * 60 * 60 * 1000;

export const customers = [];
for (let i = 0; i < 24; i += 1) {
  const first = FIRST[i % FIRST.length];
  const last = LAST[(i * 3) % LAST.length];
  customers.push({
    id: i + 1,
    name: `${first} ${last}`,
    email: `${first}.${last}${i}@shop.test`.toLowerCase(),
  });
}

export const orders = [];
for (let i = 0; i < 87; i += 1) {
  const customer = pick(customers);
  const placed = LAST_DAY - Math.floor(random() * 90) * DAY_MS + Math.floor(random() * 86400) * 1000;
  orders.push({
    id: i + 1,
    customer: customer.name,
    status: pick(STATUSES),
    total_cents: 1500 + Math.floor(random() * 46500),
    placed_at: new Date(placed).toISOString(),
    flagged: false,
  });
}
orders.sort((a, b) => b.placed_at.localeCompare(a.placed_at));

export const notes = [
  { id: 1, order_id: 1, text: 'Customer asked for a gift receipt' },
  { id: 2, order_id: 1, text: 'Address confirmed by phone' },
  { id: 3, order_id: 1, text: 'Left at the front desk' },
];
