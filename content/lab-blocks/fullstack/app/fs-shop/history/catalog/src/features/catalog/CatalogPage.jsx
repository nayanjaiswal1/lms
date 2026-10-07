import { useEffect, useState } from 'react';
import { formatMoney } from '../../lib/format.js';
import { searchProducts } from './searchProducts.js';

export default function CatalogPage() {
  const [query, setQuery] = useState('');
  const [submitted, setSubmitted] = useState('');
  const [state, setState] = useState({ status: 'loading', products: [] });

  useEffect(() => {
    const controller = new AbortController();
    setState((current) => ({ ...current, status: 'loading' }));
    searchProducts(submitted, controller.signal)
      .then((body) => setState({ status: 'ready', products: body.items }))
      .catch((error) => {
        if (error.name !== 'AbortError') setState({ status: 'error', products: [] });
      });
    return () => controller.abort();
  }, [submitted]);

  function submit(event) {
    event.preventDefault();
    setSubmitted(query.trim());
  }

  return (
    <section>
      <h2>Catalog</h2>
      <form onSubmit={submit} role="search">
        <label>
          Search products
          <input type="search" value={query} onChange={(event) => setQuery(event.target.value)} />
        </label>
        <button type="submit">Search</button>
      </form>
      {state.status === 'error' && <p role="alert">Could not load products.</p>}
      {state.status === 'ready' && state.products.length === 0 && <p>No products match.</p>}
      <ul aria-label="Products">
        {state.products.map((product) => (
          <li key={product.id}>
            <strong>{product.name}</strong> <span>{product.sku}</span> <span>{formatMoney(product.price_cents)}</span>{' '}
            <span>{product.stock > 0 ? `${product.stock} in stock` : 'Out of stock'}</span>
          </li>
        ))}
      </ul>
    </section>
  );
}
