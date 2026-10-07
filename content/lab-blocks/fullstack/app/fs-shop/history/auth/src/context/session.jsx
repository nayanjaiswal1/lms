import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { get, post } from '../lib/api.js';

const SessionContext = createContext(null);

/** Who is signed in: { status: 'loading' | 'ready', user, login(email, password), logout() }. */
export function SessionProvider({ children }) {
  const [state, setState] = useState({ status: 'loading', user: null });

  useEffect(() => {
    let active = true;
    get('/api/auth/me')
      .then(({ user }) => active && setState({ status: 'ready', user }))
      .catch(() => active && setState({ status: 'ready', user: null }));
    return () => {
      active = false;
    };
  }, []);

  const login = useCallback(async (email, password) => {
    const { user } = await post('/api/auth/login', { email, password });
    setState({ status: 'ready', user });
  }, []);

  const logout = useCallback(async () => {
    await post('/api/auth/logout');
    setState({ status: 'ready', user: null });
  }, []);

  const value = useMemo(() => ({ ...state, login, logout }), [state, login, logout]);
  return <SessionContext.Provider value={value}>{children}</SessionContext.Provider>;
}

export function useSession() {
  const value = useContext(SessionContext);
  if (!value) throw new Error('useSession must be used inside a SessionProvider');
  return value;
}
