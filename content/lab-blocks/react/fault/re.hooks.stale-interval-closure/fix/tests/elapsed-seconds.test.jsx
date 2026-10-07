import { act, renderHook } from '@testing-library/react';
import { useElapsedSeconds } from '@/hooks/useElapsedSeconds.js';

test('the elapsed counter keeps counting after the first second', () => {
  vi.useFakeTimers();
  const { result } = renderHook(() => useElapsedSeconds('a'));
  act(() => {
    vi.advanceTimersByTime(4000);
  });
  expect(result.current).toBe(4);
});
