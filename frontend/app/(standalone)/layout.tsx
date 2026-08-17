// Routes here (What Now?, Habits) are self-contained side-tools with their
// own visual identity — deliberately outside the app shell, no sidebar/
// bottom-nav chrome. Auth is still enforced by middleware.ts; each page does
// its own server-side entitlement guard where needed.
export default function StandaloneLayout({ children }: { children: React.ReactNode }) {
  return <main className="min-h-dvh">{children}</main>;
}
