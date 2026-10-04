import CustomerForm from './CustomerForm.jsx';
import { useCustomer } from './useCustomer.js';

export default function CustomerEditor({ id }) {
  const { customer, loading, error } = useCustomer(id);

  if (customer === null) {
    if (error) return <p role="alert">Could not load the customer.</p>;
    return <p>{loading ? 'Loading...' : 'Select a customer to edit.'}</p>;
  }
  return (
    <section aria-label="Customer" aria-busy={loading}>
      {error && <p role="alert">Could not load the customer.</p>}
      {/* mf:slot customers.editor.form */}
      <CustomerForm key={customer.id} customer={customer} />
      {/* mf:endslot */}
    </section>
  );
}
