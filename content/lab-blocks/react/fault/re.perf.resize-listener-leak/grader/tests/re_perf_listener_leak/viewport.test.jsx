import { render, renderHook } from '@testing-library/react';
import { trackListeners } from '@mf/harness';
import OrdersTable from '@/features/orders/OrdersTable.jsx';
import { SettingsProvider } from '@/context/settings.jsx';
import { useViewportWidth } from '@/hooks/useViewportWidth.js';

const ORDERS = [
  { id: 7, customer: 'Alice Nguyen', status: 'paid', total_cents: 4250, placed_at: '2025-03-05T14:30:00Z', flagged: false },
];

test('the hook keeps exactly one resize listener while mounted and none afterwards', () => {
  const listeners = trackListeners();
  try {
    for (let i = 0; i < 5; i += 1) {
      const { unmount } = renderHook(() => useViewportWidth());
      expect(listeners.count('resize', window)).toBe(1);
      unmount();
    }
    expect(listeners.count('resize', window)).toBe(0);
  } finally {
    listeners.restore();
  }
});

test('opening and leaving the orders table repeatedly does not accumulate listeners', () => {
  localStorage.clear();
  const listeners = trackListeners();
  try {
    for (let i = 0; i < 10; i += 1) {
      const { unmount } = render(
        <SettingsProvider>
          <OrdersTable orders={ORDERS} loading={false} />
        </SettingsProvider>,
      );
      unmount();
    }
    expect(listeners.count('resize', window)).toBe(0);
  } finally {
    listeners.restore();
  }
});
