import Link from "next/link";
import { ArrowRight, Flame } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Float, Reveal } from "@/components/landing/landing-motion";
import { LandingIllustration } from "@/components/landing/landing-illustration";
import { FEATURE_META } from "@/lib/features";
import ROUTES from "@/lib/routes";
import styles from "./landing-hero.module.css";

interface LandingHeroProps {
  courseTotal: number;
}

const featureCount = Object.keys(FEATURE_META).length;

export function LandingHero({ courseTotal }: LandingHeroProps) {
  return (
    <section
      aria-labelledby="hero-heading"
      className="relative overflow-hidden border-b border-border py-20 sm:py-28"
    >
      <div aria-hidden className={`absolute inset-0 ${styles.dotGrid}`} />
      <Flame
        aria-hidden
        className="pointer-events-none absolute -bottom-14 -left-14 h-64 w-64 text-primary/5"
      />

      <div className="page-container relative grid items-center gap-12 lg:grid-cols-[1.1fr_1fr]">
        <div className="text-center lg:text-left">
          <Reveal>
            <Badge className="mb-4" variant="outline">
              Self-hosted · No vendor lock-in
            </Badge>
          </Reveal>

          <Reveal delay={0.06}>
            <h1
              className="mx-auto max-w-xl text-balance text-4xl font-bold leading-tight sm:text-5xl lg:mx-0"
              id="hero-heading"
            >
              Structured learning, forged for learners{" "}
              <span className="text-primary">and</span> the teams who train them
            </h1>
          </Reveal>

          <Reveal delay={0.12}>
            <p className="mx-auto mt-5 max-w-xl text-pretty text-base text-muted-foreground sm:text-lg lg:mx-0">
              MindForge is a multi-tenant platform for individual learners and for
              the colleges, bootcamps, and companies that run them — courses,
              hands-on labs, mentoring, and a daily plan, all in one place.
            </p>
          </Reveal>

          <Reveal delay={0.18}>
            <div className="mt-8 flex flex-wrap items-center justify-center gap-3 lg:justify-start">
              <Button asChild size="lg">
                <Link href={ROUTES.REGISTER}>
                  Start learning free
                  <ArrowRight aria-hidden className="h-4 w-4" />
                </Link>
              </Button>
              <Button asChild size="lg" variant="outline">
                <Link href={ROUTES.ORG_CREATE}>Set up your organization</Link>
              </Button>
            </div>
          </Reveal>

          <Reveal delay={0.24}>
            <p className="mt-6 text-sm text-muted-foreground">
              {courseTotal > 0 ? `${courseTotal} published courses` : "New courses shipping weekly"} ·{" "}
              {featureCount}+ built-in tools · Free while in beta
            </p>
          </Reveal>
        </div>

        <Reveal delay={0.15} direction="right">
          <Float>
            <LandingIllustration className="mx-auto w-full max-w-xs sm:max-w-sm lg:mx-0 lg:max-w-md" />
          </Float>
        </Reveal>
      </div>
    </section>
  );
}
