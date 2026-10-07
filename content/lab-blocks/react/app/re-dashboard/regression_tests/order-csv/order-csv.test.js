import extension from '@/ext/order-csv/index.js';

const ORDERS = [
  { id: 1, customer: 'Alice Nguyen', status: 'paid', total_cents: 1500, flagged: true },
  { id: 2, customer: 'Bob Okafor', status: 'pending', total_cents: 2500, flagged: false },
  { id: 3, customer: 'Alice Nguyen', status: 'paid', total_cents: 1000, flagged: false },
];

test('the CSV has a header and one line per order', () => {
  expect(extension.run(ORDERS)).toBe(
    ['id,customer,status,total_cents', '1,Alice Nguyen,paid,1500', '2,Bob Okafor,pending,2500', '3,Alice Nguyen,paid,1000'].join('\n'),
  );
});

test('a value with a comma is quoted', () => {
  const text = extension.run([{ id: 9, customer: 'Nguyen, Alice', status: 'paid', total_cents: 1 }]);
  expect(text.split('\n')[1]).toBe('9,"Nguyen, Alice",paid,1');
});
