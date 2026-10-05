import { get } from '../../lib/api.js';

/** Products whose name or SKU matches the query ("" lists everything). */
export function searchProducts(query, signal) {
  // mf:slot catalog.search.request
  return get(`/api/products?q=${encodeURIComponent(query)}`, { signal });
  // mf:endslot
}
