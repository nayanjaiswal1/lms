import { useEffect, useState } from 'react';
import { get } from '../../lib/api.js';

/** One page of the signed-in customer's orders (pages start at 1). */
export function useOrders(page) {
  const [state, setState] = useState({ status: 'loading', orders: [], pages: 1 });

  useEffect(() => {
    const controller = new AbortController();
    setState((current) => ({ ...current, status: 'loading' }));
    get(`/api/orders?page=${page}`, { signal: controller.signal })
      .then((body) => setState({ status: 'ready', orders: body.items, pages: body.pages }))
      .catch((error) => {
        if (error.name !== 'AbortError') setState({ status: 'error', orders: [], pages: 1 });
      });
    return () => controller.abort();
  }, [page]);

  return state;
}
