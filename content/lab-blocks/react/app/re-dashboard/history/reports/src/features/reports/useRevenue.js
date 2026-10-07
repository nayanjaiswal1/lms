import { useEffect, useState } from 'react';
import { get } from '../../lib/api.js';

/** Revenue per day for the last `options.days` days. */
export function useRevenue(options) {
  const [state, setState] = useState({ days: [], error: null, settled: false });

  // mf:slot reports.hook.effect
  const { days: range } = options;
  useEffect(() => {
    let ignore = false;
    get(`/api/reports/revenue?days=${range}`).then(
      (data) => {
        if (!ignore) setState({ days: data.days, error: null, settled: true });
      },
      (error) => {
        if (!ignore) setState((current) => ({ ...current, error, settled: true }));
      },
    );
    return () => {
      ignore = true;
    };
  }, [range]);
  // mf:endslot

  return { ...state, loading: !state.settled };
}
