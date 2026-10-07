import { useCustomerSearch } from './useCustomerSearch.js';

export default function CustomerSearch({ query, onQueryChange, onSelect }) {
  const { results, loading, error } = useCustomerSearch(query);

  return (
    <div>
      <label>
        Search customers{' '}
        <input type="search" value={query} onChange={(event) => onQueryChange(event.target.value)} />
      </label>
      {error && <p role="alert">Search failed.</p>}
      <ul aria-label="Search results" aria-busy={loading}>
        {results.map((customer) => (
          <li key={customer.id}>
            <button type="button" onClick={() => onSelect(customer.id)}>
              {customer.name} ({customer.email})
            </button>
          </li>
        ))}
      </ul>
    </div>
  );
}
