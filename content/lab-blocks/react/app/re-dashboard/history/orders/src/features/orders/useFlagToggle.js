import { useState } from 'react';
import { post } from '../../lib/api.js';

/** Flag state of one order. The toggle is optimistic: the flag flips at once and the request follows. */
export function useFlagToggle(order) {
  const [flagged, setFlagged] = useState(order.flagged);
  const [error, setError] = useState(null);

  async function toggle() {
    const next = !flagged;
    setError(null);
    // mf:slot orders.flag.toggle
    setFlagged(next);
    try {
      await post(`/api/orders/${order.id}/flag`, { flagged: next });
    } catch (failure) {
      setFlagged(!next);
      setError(failure);
    }
    // mf:endslot
  }

  return { flagged, toggle, error };
}
