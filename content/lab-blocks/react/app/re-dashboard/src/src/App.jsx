import { useState } from 'react';
import ErrorBoundary from './components/ErrorBoundary.jsx';
import { SettingsProvider } from './context/settings.jsx';
import { PAGES } from './pages.js';

export default function App() {
  const [pageId, setPageId] = useState(PAGES[0].id);
  const [filter, setFilter] = useState('');
  const { Component: Page } = PAGES.find((page) => page.id === pageId);

  return (
    <SettingsProvider>
      <div className="app">
        <header>
          <h1>Ops Console</h1>
          <nav aria-label="Main">
            {PAGES.map((page) => (
              <button
                key={page.id}
                type="button"
                aria-current={page.id === pageId ? 'page' : undefined}
                onClick={() => setPageId(page.id)}
              >
                {page.title}
              </button>
            ))}
          </nav>
          <input
            type="search"
            aria-label="Quick filter"
            placeholder="Quick filter"
            value={filter}
            onChange={(event) => setFilter(event.target.value)}
          />
        </header>
        <main>
          <ErrorBoundary key={pageId}>
            <Page filter={filter} />
          </ErrorBoundary>
        </main>
      </div>
    </SettingsProvider>
  );
}
