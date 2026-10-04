import { act, renderHook } from '@testing-library/react';
import { useElapsedSeconds } from '@/hooks/useElapsedSeconds.js';
import { useViewportWidth } from '@/hooks/useViewportWidth.js';

test('the elapsed counter starts at zero and owns one timer', () => {
  vi.useFakeTimers();
  const { result, unmount } = renderHook(() => useElapsedSeconds('a'));
  expect(result.current).toBe(0);
  expect(vi.getTimerCount()).toBe(1);
  unmount();
  expect(vi.getTimerCount()).toBe(0);
});

test('changing the reset key restarts the counter at zero', () => {
  vi.useFakeTimers();
  const { result, rerender } = renderHook(({ id }) => useElapsedSeconds(id), { initialProps: { id: 'a' } });
  act(() => {
    vi.advanceTimersByTime(1000);
  });
  rerender({ id: 'b' });
  expect(result.current).toBe(0);
  expect(vi.getTimerCount()).toBe(1);
});

test('the viewport width is read on mount and follows resize events', () => {
  window.innerWidth = 1024;
  const { result } = renderHook(() => useViewportWidth());
  expect(result.current).toBe(1024);

  window.innerWidth = 500;
  act(() => {
    window.dispatchEvent(new Event('resize'));
  });
  expect(result.current).toBe(500);
});
