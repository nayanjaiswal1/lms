import Link from "next/link";
import type { ReactNode } from "react";
import type { LucideIcon } from "lucide-react";
import {
  ArrowRight,
  Award,
  Bot,
  BookOpen,
  Building2,
  ClipboardCheck,
  FlaskConical,
  GraduationCap,
  Layers,
  Link2,
  MessagesSquare,
  ShieldCheck,
} from "lucide-react";

import { Button } from "@/components/ui/button";
import { Reveal } from "@/components/landing/landing-motion";
import { LearnerIllustration, OrgIllustration } from "@/components/landing/landing-illustration";
import { FEATURE_META } from "@/lib/features";
import ROUTES from "@/lib/routes";

interface AudienceItem {
  icon: LucideIcon;
  label: string;
  description: string;
}

const LEARNER_ITEMS: AudienceItem[] = [
  { icon: BookOpen, ...FEATURE_META.courses },
  { icon: FlaskConical, label: "Hands-on labs", description: "Real coding environments built into every course — no local setup." },
  { icon: ClipboardCheck, ...FEATURE_META.quizzes },
  { icon: Layers, ...FEATURE_META.flashcards },
  { icon: Award, ...FEATURE_META.certificates },
  { icon: GraduationCap, ...FEATURE_META.session_booking },
];

const ORG_ITEMS: AudienceItem[] = [
  { icon: Building2, ...FEATURE_META.multi_org },
  { icon: ShieldCheck, label: "Role-based access", description: "Admin, instructor, mentor, and student roles scoped to your organization." },
  { icon: MessagesSquare, ...FEATURE_META.batch_chat },
  { icon: BookOpen, ...FEATURE_META.wiki },
  { icon: Link2, ...FEATURE_META.anonymous_tests },
  { icon: Bot, ...FEATURE_META.ai_connector },
];

function AudienceCard({
  id,
  eyebrow,
  title,
  description,
  items,
  cta,
  href,
  direction,
  illustration,
}: {
  id: string;
  eyebrow: string;
  title: string;
  description: string;
  items: AudienceItem[];
  cta: string;
  href: string;
  direction: "left" | "right";
  illustration: ReactNode;
}) {
  return (
    <Reveal className="card-raised scroll-mt-16 flex h-full flex-col p-6 sm:p-8" direction={direction} id={id}>
      <div className="mb-6 flex items-center justify-center rounded-lg border border-border bg-muted/40 p-6">
        {illustration}
      </div>
      <span className="text-xs font-bold uppercase tracking-wide text-primary">{eyebrow}</span>
      <h3 className="mt-2 text-xl font-bold sm:text-2xl">{title}</h3>
      <p className="mt-2 text-sm text-muted-foreground">{description}</p>

      <ul className="mt-6 flex flex-1 flex-col gap-4">
        {items.map(({ icon: Icon, label, description: itemDescription }) => (
          <li className="flex items-start gap-3" key={label}>
            <span className="flex-center h-9 w-9 shrink-0 rounded-md bg-primary/10 text-primary">
              <Icon aria-hidden className="h-5 w-5" />
            </span>
            <span className="flex min-w-0 flex-col gap-0.5">
              <span className="font-semibold text-foreground">{label}</span>
              <span className="text-sm text-muted-foreground">{itemDescription}</span>
            </span>
          </li>
        ))}
      </ul>

      <Button asChild className="mt-8 self-start">
        <Link href={href}>
          {cta}
          <ArrowRight aria-hidden className="h-4 w-4" />
        </Link>
      </Button>
    </Reveal>
  );
}

export function LandingAudience() {
  return (
    <section aria-labelledby="audience-heading" className="border-b border-border bg-muted/30 py-16 sm:py-24">
      <div className="page-container">
        <Reveal>
          <h2 className="text-center text-2xl font-bold sm:text-3xl" id="audience-heading">
            Built for however you learn
          </h2>
          <p className="mx-auto mt-2 max-w-xl text-center text-sm text-muted-foreground">
            The same platform, tuned for a single learner or an entire
            organization.
          </p>
        </Reveal>

        <div className="mt-10 grid gap-6 lg:grid-cols-2">
          <AudienceCard
            cta="Start learning free"
            description="Enroll in courses on your own, at your own pace — no organization required."
            direction="left"
            eyebrow="For individuals"
            href={ROUTES.REGISTER}
            id="individuals"
            illustration={<LearnerIllustration className="h-auto w-full max-w-72" />}
            items={LEARNER_ITEMS}
            title="Learn on your own"
          />
          <AudienceCard
            cta="Set up your organization"
            description="Run your college, bootcamp, or company's training on your own tenant — self-hosted, your data."
            direction="right"
            eyebrow="For colleges, bootcamps & teams"
            href={ROUTES.ORG_CREATE}
            id="teams"
            illustration={<OrgIllustration className="h-auto w-full max-w-72" />}
            items={ORG_ITEMS}
            title="Train your cohort"
          />
        </div>
      </div>
    </section>
  );
}
