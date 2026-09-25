import type { ReactNode } from "react";
import Link from "next/link";

import { AuthBrandPanel } from "@/components/auth/auth-brand-panel";
import { BrandMark } from "@/components/shared/brand-mark";
import ROUTES from "@/lib/routes";

interface AuthPageShellProps {
  title: string;
  description: string;
  alternatePrompt: string;
  alternateLabel: string;
  alternateHref: string;
  children: ReactNode;
  /** Optional extra line grouped tightly with the alternate prompt below the
   * form (e.g. login's "Just exploring? Try demo") — kept in one footer
   * group so related links don't float apart at the shell's section gap. */
  footerExtra?: ReactNode;
}

export function AuthPageShell({
  title,
  description,
  alternatePrompt,
  alternateLabel,
  alternateHref,
  children,
  footerExtra,
}: AuthPageShellProps) {
  return (
    <main className="grid min-h-dvh lg:h-dvh lg:grid-cols-2 lg:overflow-hidden">
      <AuthBrandPanel />

      <section className="flex min-h-dvh flex-col gap-10 px-6 py-8 sm:px-10 lg:min-h-0 lg:overflow-y-auto lg:px-16">
        <header className="flex items-center">
          <Link
            aria-label="Home"
            className="text-foreground hover:no-underline lg:invisible"
            href={ROUTES.HOME}
          >
            <BrandMark />
          </Link>
        </header>

        <div className="m-auto flex w-full max-w-sm flex-col gap-8">
          <div className="flex flex-col gap-2 text-center sm:text-left">
            <h1>{title}</h1>
            <p className="text-muted-foreground">{description}</p>
          </div>
          {children}
          <div className="flex flex-col gap-2 text-center text-sm text-muted-foreground sm:text-left">
            {footerExtra}
            <p>
              {alternatePrompt}{" "}
              <Link className="font-medium" href={alternateHref}>
                {alternateLabel}
              </Link>
            </p>
          </div>
        </div>

        <footer className="text-center text-xs text-muted-foreground sm:text-left">
          © {new Date().getFullYear()} MindForge. All rights reserved.
        </footer>
      </section>
    </main>
  );
}
