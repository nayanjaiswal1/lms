import { useState } from 'react';
import { SessionProvider, useSession } from './context/session.jsx';
import LoginForm from './features/auth/LoginForm.jsx';
import { PAGES } from './pages.js';

function Shell() {
  const { status, user, logout } = useSession();
  const [pageId, setPageId] = useState(PAGES[0].id);
  const { Component: Page } = PAGES.find((page) => page.id === pageId);

  let content = <LoginForm />;
  if (status === 'loading') content = <p>Loading...</p>;
  else if (user) content = <Page />;

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
        {user && (
          <div className="account">
            <span>{user.name}</span>
            <button type="button" onClick={logout}>
              Sign out
            </button>
          </div>
        )}
      </header>
      <main>{content}</main>
    </div>
  );
}

export default function App() {
  return (
    <SessionProvider>
      <Shell />
    </SessionProvider>
  );
}
