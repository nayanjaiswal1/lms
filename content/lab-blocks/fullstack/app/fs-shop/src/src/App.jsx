import { useState } from 'react';
import { PAGES } from './pages.js';

export default function App() {
  const [pageId, setPageId] = useState(PAGES[0].id);
  const { Component: Page } = PAGES.find((page) => page.id === pageId);

  return (
    <div className="app">
      <header>
        <h1>Shop Console</h1>
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
      </header>
      <main>
        <Page />
      </main>
    </div>
  );
}
