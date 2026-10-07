import { useEffect, useState } from 'react';
import { get } from '../../lib/api.js';

/** One page of orders for a status filter; `updates` counts completed loads. */
export function useOrders(status, page) {
  const [state, setState] = useState({ items: [], pages: 1, loading: true, error: null, updates: 0 });

  // mf:slot orders.hook.effect
  useEffect(() => {
    let ignore = false;
    setState((current) => ({ ...current, loading: true, error: null }));
    get(`/api/orders?status=${status}&page=${page}`).then(
      (data) => {
        if (!ignore) {
          setState((current) => ({
            items: data.items,
            pages: data.pages,
            loading: false,
            error: null,
            updates: current.updates + 1,
          }));
        }
      },
      (error) => {
        if (!ignore) setState((current) => ({ ...current, loading: false, error }));
      },
    );
    return () => {
      ignore = true;
    };
  }, [status, page]);
  // mf:endslot

  return state;
}
