import { useState } from 'react';
import { extensions } from '../../ext/registry.js';

/** Actions contributed by extensions (src/ext/*), run against the orders on screen. */
export default function ToolsMenu({ orders }) {
  const [result, setResult] = useState(null);

  if (extensions.length === 0) return null;
  return (
    <div role="group" aria-label="Tools">
      {extensions.map((extension) => (
        <button
          key={extension.id}
          type="button"
          onClick={() => setResult({ id: extension.id, text: extension.run(orders) })}
        >
          {extension.label}
        </button>
      ))}
      {result && <output aria-label={`${result.id} result`}>{result.text}</output>}
    </div>
  );
}
