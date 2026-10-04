import { useState } from 'react';
import { saveCustomer } from './useCustomer.js';

export default function CustomerForm({ customer }) {
  const [name, setName] = useState(customer.name);
  const [email, setEmail] = useState(customer.email);
  const [status, setStatus] = useState('idle');

  async function submit(event) {
    event.preventDefault();
    setStatus('saving');
    try {
      await saveCustomer(customer.id, { name, email });
      setStatus('saved');
    } catch {
      setStatus('error');
    }
  }

  return (
    <form aria-label="Edit customer" onSubmit={submit}>
      <label>
        Name <input value={name} onChange={(event) => setName(event.target.value)} />
      </label>
      <label>
        Email <input type="email" value={email} onChange={(event) => setEmail(event.target.value)} />
      </label>
      <button type="submit" disabled={status === 'saving'}>
        Save
      </button>
      {status === 'saved' && <p role="status">Saved</p>}
      {status === 'error' && <p role="alert">Could not save the customer.</p>}
    </form>
  );
}
