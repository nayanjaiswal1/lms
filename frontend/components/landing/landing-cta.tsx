import Link from "next/link";
import { ArrowRight } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Reveal } from "@/components/landing/landing-motion";
import ROUTES from "@/lib/routes";

export function LandingCta() {
  return (
    <section aria-labelledby="cta-heading" className="py-16 sm:py-24">
      <Reveal className="page-container text-center">
        <h2 className="text-2xl font-bold sm:text-3xl" id="cta-heading">
          Start your first course today
        </h2>
        <p className="mx-auto mt-2 max-w-xl text-sm text-muted-foreground">
          Free to sign up. Enroll in free courses instantly, buy paid ones
          when you&rsquo;re ready, or set up an organization for your team.
        </p>
        <div className="mt-6 flex flex-wrap items-center justify-center gap-3">
          <Button asChild size="lg">
            <Link href={ROUTES.REGISTER}>
              Get started
              <ArrowRight aria-hidden className="h-4 w-4" />
            </Link>
          </Button>
          <Button asChild size="lg" variant="outline">
            <Link href={ROUTES.ORG_CREATE}>Set up your organization</Link>
          </Button>
        </div>
      </Reveal>
    </section>
  );
}
