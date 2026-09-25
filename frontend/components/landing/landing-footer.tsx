import Link from "next/link";

import { BrandMark } from "@/components/shared/brand-mark";
import ROUTES from "@/lib/routes";

const FOOTER_LINKS = [
  { label: "Log in", href: ROUTES.LOGIN },
  { label: "Register", href: ROUTES.REGISTER },
  { label: "For organizations", href: ROUTES.ORG_CREATE },
  { label: "Privacy Policy", href: ROUTES.LEGAL_PRIVACY },
  { label: "Terms of Service", href: ROUTES.LEGAL_TERMS },
] as const;

// Phones: centred stack with the links in an even 2-col grid (44px tap targets,
// odd last link spans both columns). flex-wrap used to leave ragged, left-hugging
// rows. md+: the original single row, brand left, links right.
export function LandingFooter() {
  return (
    <footer className="border-t border-border py-8">
      <div className="page-container flex flex-col items-center gap-6 text-sm text-muted-foreground md:flex-row md:justify-between">
        <div className="flex flex-col items-center gap-2 md:flex-row md:gap-4">
          <BrandMark iconClassName="h-6 w-6" />
          <span>© {new Date().getFullYear()} MindForge</span>
        </div>
        <nav aria-label="Footer" className="grid w-full grid-cols-2 gap-x-4 md:flex md:w-auto md:items-center md:gap-6">
          {FOOTER_LINKS.map(({ label, href }) => (
            <Link
              className="flex min-h-11 items-center justify-center last:odd:col-span-2 hover:text-foreground md:min-h-0"
              href={href}
              key={href}
            >
              {label}
            </Link>
          ))}
        </nav>
      </div>
    </footer>
  );
}
