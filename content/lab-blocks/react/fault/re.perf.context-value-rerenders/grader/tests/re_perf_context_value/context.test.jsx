import { act, fireEvent, render, screen } from '@testing-library/react';
import { useState } from 'react';
import { createRenderProbe } from '@mf/harness';
import { SettingsProvider, useSettings } from '@/context/settings.jsx';

function setup() {
  localStorage.clear();
  const probe = createRenderProbe(() => useSettings());
  const child = <probe.Probe />;
  function Host() {
    const [text, setText] = useState('');
    return (
      <>
        <input aria-label="Quick filter" value={text} onChange={(event) => setText(event.target.value)} />
        <SettingsProvider>{child}</SettingsProvider>
      </>
    );
  }
  render(<Host />);
  return probe;
}

test('typing in a sibling field does not re-render the settings consumers', () => {
  const probe = setup();
  const before = probe.renders;
  const input = screen.getByLabelText('Quick filter');
  for (const text of ['a', 'ab', 'abc', 'abcd']) fireEvent.change(input, { target: { value: text } });
  expect(probe.renders).toBe(before);
});

test('consumers re-render once when a setting changes', () => {
  const probe = setup();
  const before = probe.renders;
  act(() => probe.lastValue.update({ currency: 'EUR' }));
  expect(probe.lastValue.currency).toBe('EUR');
  expect(probe.renders).toBe(before + 1);
});
