import { useEffect, useState } from 'react';

/** Whole seconds since `resetKey` last changed (0 on mount). */
export function useElapsedSeconds(resetKey) {
  const [seconds, setSeconds] = useState(0);

  useEffect(() => {
    setSeconds(0);
    const timer = setInterval(() => {
      // mf:slot hooks.elapsed.tick
      setSeconds((current) => current + 1);
      // mf:endslot
    }, 1000);
    return () => clearInterval(timer);
  }, [resetKey]);

  return seconds;
}
