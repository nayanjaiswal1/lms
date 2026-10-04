import { useEffect, useState } from 'react';
import { get } from '../../lib/api.js';

/** Customers matching the typed text; an empty query shows nothing. */
export function useCustomerSearch(query) {
  const [state, setState] = useState({ results: [], loading: false, error: null });

  // mf:slot customers.search.effect
  useEffect(() => {
    const term = query.trim();
    if (term === '') {
      setState({ results: [], loading: false, error: null });
      return undefined;
    }
    const controller = new AbortController();
    setState((current) => ({ ...current, loading: true, error: null }));
    get(`/api/customers?q=${encodeURIComponent(term)}`, { signal: controller.signal }).then(
      (results) => setState({ results, loading: false, error: null }),
      (error) => {
        if (error.name !== 'AbortError') setState((current) => ({ ...current, loading: false, error }));
      },
    );
    return () => controller.abort();
  }, [query]);
  // mf:endslot

  return state;
}
