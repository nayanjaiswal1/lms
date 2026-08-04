import Link from "next/link";

import { BrandMark } from "@/components/shared/brand-mark";
import ROUTES from "@/lib/routes";

export function LandingFooter() {
  return (
    <footer className="border-t border-border py-8">
      <div className="page-container flex flex-wrap items-center justify-between gap-4 text-sm text-muted-foreground">
        <div className="flex flex-wrap items-center gap-4">
          <BrandMark iconClassName="h-6 w-6" />
          <span>© {new Date().getFullYear()} MindForge</span>
        </div>
        <nav aria-label="Footer" className="flex items-center gap-4">
          <Link className="hover:text-foreground" href={ROUTES.LOGIN}>
            Log in
          </Link>
          <Link className="hover:text-foreground" href={ROUTES.REGISTER}>
            Register
          </Link>
          <Link className="hover:text-foreground" href={ROUTES.ORG_CREATE}>
            For organizations
          </Link>
          <Link className="hover:text-foreground" href={ROUTES.LEGAL_PRIVACY}>
            Privacy Policy
          </Link>
          <Link className="hover:text-foreground" href={ROUTES.LEGAL_TERMS}>
            Terms of Service
          </Link>
        </nav>
      </div>
    </footer>
  );
}
