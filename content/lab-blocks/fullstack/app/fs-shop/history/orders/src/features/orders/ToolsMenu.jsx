import { useState } from 'react';
import { extensions } from '../../ext/registry.js';

/** Actions contributed by src/ext/<name>; each one reports on the orders currently shown. */
export default function ToolsMenu({ orders }) {
  const [result, setResult] = useState('');
  if (extensions.length === 0) return null;
  return (
    <details>
      <summary>Tools</summary>
      <ul>
        {extensions.map((extension) => (
          <li key={extension.id}>
            <button type="button" onClick={() => setResult(extension.run(orders))}>
              {extension.label}
            </button>
          </li>
        ))}
      </ul>
      {result && <output>{result}</output>}
    </details>
  );
}
