"use client";

import Script from "next/script";

// Razorpay's own Checkout.js attaches window.Razorpay — there is no npm
// package for it, loading the script tag is the documented integration path.
declare global {
  interface Window {
    Razorpay?: new (options: RazorpayOptions) => { open(): void };
  }
}

interface RazorpayOptions {
  key: string;
  amount: string;
  currency: string;
  name: string;
  order_id: string;
  prefill?: { email?: string };
  handler: () => void;
  modal?: { ondismiss?: () => void };
}

// Loaded once, unconditionally, wherever a purchase button might open a
// Razorpay checkout — cheap no-op until openRazorpayCheckout is actually
// called, and avoids a useEffect-driven "load script then open" dance (the
// frontend's no-useEffect rule): the script tag is just always present, and
// opening the modal happens directly inside the button's click handler.
export function RazorpayScript() {
  return <Script src="https://checkout.razorpay.com/v1/checkout.js" strategy="afterInteractive" />;
}

// Opens Razorpay's Checkout.js modal from client_params (see
// courses.CheckoutSession). Its own success handler only calls onSuccess —
// it never grants access itself, only a webhook-confirmed purchase-status
// poll does (see the checkout return page), the same way a Stripe redirect
// doesn't grant access on its own either.
export function openRazorpayCheckout(
  params: Record<string, string>,
  handlers: { onSuccess: () => void; onClose: () => void },
) {
  if (!window.Razorpay) {
    handlers.onClose();
    return;
  }
  const rzp = new window.Razorpay({
    key: params.key_id,
    amount: params.amount,
    currency: params.currency,
    name: params.name,
    order_id: params.order_id,
    prefill: params.prefill_email ? { email: params.prefill_email } : undefined,
    handler: handlers.onSuccess,
    modal: { ondismiss: handlers.onClose },
  });
  rzp.open();
}
