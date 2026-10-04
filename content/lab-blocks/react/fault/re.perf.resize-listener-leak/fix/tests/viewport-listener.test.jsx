import { renderHook } from '@testing-library/react';
import { trackListeners } from '@mf/harness';
import { useViewportWidth } from '@/hooks/useViewportWidth.js';

test('unmounting the viewport hook removes its resize listener', () => {
  const listeners = trackListeners();
  try {
    const { unmount } = renderHook(() => useViewportWidth());
    expect(listeners.count('resize', window)).toBe(1);
    unmount();
    expect(listeners.count('resize', window)).toBe(0);
  } finally {
    listeners.restore();
  }
});
