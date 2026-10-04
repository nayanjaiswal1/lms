import { act, renderHook } from '@testing-library/react';
import { useElapsedSeconds } from '@/hooks/useElapsedSeconds.js';

function advance(seconds) {
  act(() => {
    vi.advanceTimersByTime(seconds * 1000);
  });
}

test('the counter follows the clock past the first second', () => {
  vi.useFakeTimers();
  const { result } = renderHook(() => useElapsedSeconds('a'));
  advance(3);
  expect(result.current).toBe(3);
  advance(62);
  expect(result.current).toBe(65);
});

test('a new reset key starts counting again from zero', () => {
  vi.useFakeTimers();
  const { result, rerender } = renderHook(({ id }) => useElapsedSeconds(id), { initialProps: { id: 'a' } });
  advance(5);
  expect(result.current).toBe(5);
  rerender({ id: 'b' });
  expect(result.current).toBe(0);
  advance(2);
  expect(result.current).toBe(2);
});
