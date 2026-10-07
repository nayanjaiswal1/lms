import { useEffect, useState } from 'react';
import { post } from '../../lib/api.js';
import { formatMoney } from '../../lib/format.js';
import { searchProducts } from '../catalog/searchProducts.js';

export default function CheckoutPage() {
  const [products, setProducts] = useState([]);
  const [productId, setProductId] = useState('');
  const [quantity, setQuantity] = useState(1);
  const [placed, setPlaced] = useState(null);
  const [error, setError] = useState('');
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    const controller = new AbortController();
    searchProducts('', controller.signal)
      .then((body) => {
        setProducts(body.items);
        setProductId(String(body.items[0]?.id ?? ''));
      })
      .catch(() => {});
    return () => controller.abort();
  }, []);

  async function submit(event) {
    event.preventDefault();
    setError('');
    setPlaced(null);
    setSubmitting(true);
    try {
      const order = await post('/api/orders', { items: [{ product_id: Number(productId), quantity: Number(quantity) }] });
      setPlaced(order);
    } catch (err) {
      setError(err.message);
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <section>
      <h2>Place an order</h2>
      <form onSubmit={submit} aria-label="Place an order">
        <label>
          Product
          <select value={productId} onChange={(event) => setProductId(event.target.value)}>
            {products.map((product) => (
              <option key={product.id} value={product.id}>
                {product.name} ({formatMoney(product.price_cents)})
              </option>
            ))}
          </select>
        </label>
        <label>
          Quantity
          <input type="number" min="1" value={quantity} onChange={(event) => setQuantity(event.target.value)} />
        </label>
        <button type="submit" disabled={submitting || !productId}>
          Place order
        </button>
      </form>
      {error && <p role="alert">{error}</p>}
      {placed && (
        <p role="status">
          Order #{placed.id} placed: {formatMoney(placed.total_cents)}
        </p>
      )}
    </section>
  );
}
