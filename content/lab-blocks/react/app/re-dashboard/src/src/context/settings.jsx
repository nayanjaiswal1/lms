import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';

const STORAGE_KEY = 'mf-settings';
export const DEFAULT_SETTINGS = { currency: 'USD', density: 'comfortable' };

function loadSettings() {
  try {
    return { ...DEFAULT_SETTINGS, ...JSON.parse(localStorage.getItem(STORAGE_KEY) ?? '{}') };
  } catch {
    return DEFAULT_SETTINGS;
  }
}

const SettingsContext = createContext(null);

export function SettingsProvider({ children }) {
  const [settings, setSettings] = useState(loadSettings);

  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(settings));
    } catch {
      // Storage is optional: private mode or a full quota only loses persistence.
    }
  }, [settings]);

  const update = useCallback((patch) => setSettings((current) => ({ ...current, ...patch })), []);

  // mf:slot settings.provider.value
  const value = useMemo(() => ({ ...settings, update }), [settings, update]);
  // mf:endslot

  return <SettingsContext.Provider value={value}>{children}</SettingsContext.Provider>;
}

export function useSettings() {
  const value = useContext(SettingsContext);
  if (value === null) {
    throw new Error('useSettings must be used inside <SettingsProvider>');
  }
  return value;
}
