import { useCallback, useEffect, useState } from 'react';
import { del, get, post, put } from '../../lib/api.js';

/** The notes of one order, with add / save / remove that keep the list in sync. */
export function useNotes(orderId) {
  const [state, setState] = useState({ notes: [], loading: true, error: null });

  useEffect(() => {
    let ignore = false;
    setState({ notes: [], loading: true, error: null });
    get(`/api/orders/${orderId}/notes`).then(
      (notes) => {
        if (!ignore) setState({ notes, loading: false, error: null });
      },
      (error) => {
        if (!ignore) setState({ notes: [], loading: false, error });
      },
    );
    return () => {
      ignore = true;
    };
  }, [orderId]);

  const add = useCallback(
    async (text) => {
      const note = await post(`/api/orders/${orderId}/notes`, { text });
      setState((current) => ({ ...current, notes: [...current.notes, note] }));
    },
    [orderId],
  );

  const save = useCallback(async (id, text) => {
    const note = await put(`/api/notes/${id}`, { text });
    setState((current) => ({ ...current, notes: current.notes.map((n) => (n.id === id ? note : n)) }));
  }, []);

  const remove = useCallback(async (id) => {
    await del(`/api/notes/${id}`);
    setState((current) => ({ ...current, notes: current.notes.filter((n) => n.id !== id) }));
  }, []);

  return { ...state, add, save, remove };
}
