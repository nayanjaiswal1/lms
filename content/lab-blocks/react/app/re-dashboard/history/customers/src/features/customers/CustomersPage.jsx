import { useState } from 'react';
import CustomerEditor from './CustomerEditor.jsx';
import CustomerSearch from './CustomerSearch.jsx';

export default function CustomersPage() {
  const [query, setQuery] = useState('');
  const [selectedId, setSelectedId] = useState(null);

  return (
    <section aria-labelledby="customers-title">
      <h2 id="customers-title">Customers</h2>
      <CustomerSearch query={query} onQueryChange={setQuery} onSelect={setSelectedId} />
      <CustomerEditor id={selectedId} />
    </section>
  );
}
