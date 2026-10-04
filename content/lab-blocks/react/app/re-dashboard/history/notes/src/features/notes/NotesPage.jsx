import { useState } from 'react';
import NotesPanel from './NotesPanel.jsx';

export default function NotesPage() {
  const [orderId, setOrderId] = useState(1);

  return (
    <section aria-labelledby="notes-title">
      <h2 id="notes-title">Order notes</h2>
      <label>
        Order number{' '}
        <input
          type="number"
          min="1"
          value={orderId}
          onChange={(event) => setOrderId(Math.max(1, Number(event.target.value) || 1))}
        />
      </label>
      <NotesPanel orderId={orderId} />
    </section>
  );
}
