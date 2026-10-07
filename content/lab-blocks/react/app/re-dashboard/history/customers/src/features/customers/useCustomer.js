import { useEffect, useState } from 'react';
import { get, put } from '../../lib/api.js';

/** One customer by id. The previous customer stays on screen while the next one loads. */
export function useCustomer(id) {
  const [state, setState] = useState({ customer: null, loading: id != null, error: null });

  useEffect(() => {
    if (id == null) return undefined;
    let ignore = false;
    setState((current) => ({ ...current, loading: true, error: null }));
    get(`/api/customers/${id}`).then(
      (customer) => {
        if (!ignore) setState({ customer, loading: false, error: null });
      },
      (error) => {
        if (!ignore) setState((current) => ({ ...current, loading: false, error }));
      },
    );
    return () => {
      ignore = true;
    };
  }, [id]);

  return state;
}

export const saveCustomer = (id, values) => put(`/api/customers/${id}`, values);
