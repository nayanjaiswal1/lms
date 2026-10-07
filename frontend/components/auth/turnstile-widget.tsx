"use client";

import Script from "next/script";

import { TURNSTILE_SCRIPT_URL } from "@/lib/captcha";

declare global {
  interface Window {
    turnstile?: { reset: () => void };
  }
}

const SITE_KEY = process.env.NEXT_PUBLIC_TURNSTILE_SITE_KEY;

// Cloudflare Turnstile via implicit rendering: the script finds .cf-turnstile
// and injects a hidden `cf-turnstile-response` input into the enclosing <form>.
// Renders nothing when no site key is configured (dev). Next.js stamps the
// request's CSP nonce on <Script>, and 'strict-dynamic' trusts what it loads.
export function TurnstileWidget() {
  if (!SITE_KEY) return null;
  return (
    <>
      <Script src={TURNSTILE_SCRIPT_URL} strategy="afterInteractive" />
      <div className="cf-turnstile" data-sitekey={SITE_KEY} />
    </>
  );
}

// Reads the solved token off the submitted form, then resets the widget:
// a Turnstile token is single-use, so every submit (even a failed one) needs
// a fresh challenge.
export function takeCaptchaToken(target: EventTarget | undefined): string {
  if (!(target instanceof HTMLFormElement)) return "";
  const token = new FormData(target).get("cf-turnstile-response");
  window.turnstile?.reset();
  return typeof token === "string" ? token : "";
}
