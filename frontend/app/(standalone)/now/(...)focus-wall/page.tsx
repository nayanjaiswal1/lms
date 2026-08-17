// Intercepts client-side navigation to /focus-wall while on /now (the
// WhatNowSwitch icon), rendering it inside the (standalone) shell — no
// sidebar. A direct URL visit or refresh falls through to
// app/(app)/focus-wall/page.tsx instead, which does show the sidebar.
import { FocusWallPageContent } from "@/components/focus-wall/focus-wall-page-content";

export const metadata = { title: "Focus Wall" };

export default function FocusWallInterceptedFromNow() {
  return <FocusWallPageContent standalone />;
}
