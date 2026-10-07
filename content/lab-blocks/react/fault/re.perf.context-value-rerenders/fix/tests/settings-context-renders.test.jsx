import { fireEvent, render, screen } from '@testing-library/react';
import { useState } from 'react';
import { createRenderProbe } from '@mf/harness';
import { SettingsProvider, useSettings } from '@/context/settings.jsx';

test('a settings consumer does not re-render when only the provider parent re-renders', () => {
  localStorage.clear();
  const probe = createRenderProbe(() => useSettings());
  const child = <probe.Probe />;
  function Host() {
    const [text, setText] = useState('');
    return (
      <>
        <input aria-label="text" value={text} onChange={(event) => setText(event.target.value)} />
        <SettingsProvider>{child}</SettingsProvider>
      </>
    );
  }
  render(<Host />);
  const before = probe.renders;
  fireEvent.change(screen.getByLabelText('text'), { target: { value: 'abc' } });
  expect(probe.renders).toBe(before);
});
