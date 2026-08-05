import {
  Award,
  BookOpen,
  ClipboardCheck,
  FlaskConical,
  GraduationCap,
  Layers,
  ListChecks,
  MessageCircleQuestion,
  MonitorPlay,
  Sparkles,
  TerminalSquare,
  Workflow,
} from "lucide-react";

import { LandingMotionConfig } from "@/components/landing/landing-motion";
import { LandingHeader } from "@/components/landing/landing-header";
import { LandingHero } from "@/components/landing/landing-hero";
import { LandingStats } from "@/components/landing/landing-stats";
import { LandingFeatures, type FeatureShowcaseItem } from "@/components/landing/landing-features";
import { LandingPricing } from "@/components/landing/landing-pricing";
import { LandingFaq, type FaqItem } from "@/components/landing/landing-faq";
import { LandingCta } from "@/components/landing/landing-cta";
import { LandingFooter } from "@/components/landing/landing-footer";
import { LearnerIllustration } from "@/components/landing/landing-illustration";
import { FEATURE_META } from "@/lib/features";
import type { PricingTier } from "@/lib/server/pricing";
import ROUTES from "@/lib/routes";

const NAV_LINKS = [
  { label: "Features", href: "#features" },
  { label: "Pricing", href: "#pricing" },
  { label: "FAQ", href: "#faq" },
] as const;

const SHOWCASE: FeatureShowcaseItem[] = [
  { icon: BookOpen, ...FEATURE_META.courses },
  { icon: TerminalSquare, ...FEATURE_META.coding_problems },
  { icon: FlaskConical, label: "Hands-on labs", description: "Real coding environments built into every course — no local setup." },
  { icon: ClipboardCheck, ...FEATURE_META.quizzes },
  { icon: Layers, ...FEATURE_META.flashcards },
  { icon: Workflow, ...FEATURE_META.system_design },
  { icon: MonitorPlay, ...FEATURE_META.interview_board },
  { icon: ListChecks, ...FEATURE_META.sheet_tracker },
  { icon: Award, ...FEATURE_META.certificates },
  { icon: GraduationCap, ...FEATURE_META.session_booking },
  { icon: Sparkles, ...FEATURE_META.practice_ai },
  { icon: MessageCircleQuestion, ...FEATURE_META.interview_exp },
];

const FAQS: FaqItem[] = [
  {
    question: "Is MindForge free to use?",
    answer:
      "The Free plan is live today, not a beta placeholder — enroll in free courses, run coding problems, and build flashcard decks at no cost, permanently. Plus and Pro add more lab time and mentoring once billing ships.",
  },
  {
    question: "Do I need to join an organization to start?",
    answer:
      "No. Register on your own, enroll in courses, and use labs, mentoring, and review tools without ever joining a college, bootcamp, or company tenant.",
  },
  {
    question: "How does paid course pricing work?",
    answer:
      "Each course is priced individually by whoever built it — free or a one-time purchase you keep forever. That's separate from the account plans below, which control lab time, AI features, and mentoring credits.",
  },
  {
    question: "What happens if I run out of lab hours on Plus or Pro?",
    answer:
      "New lab sessions queue until your next billing cycle — anything already running keeps going uninterrupted. You can also drop down to Free's single-session limit at any time.",
  },
];

interface LandingPageProps {
  total: number;
  tiers: PricingTier[];
}

export function LandingPage({ total, tiers }: LandingPageProps) {
  const stats = [
    { value: String(total), label: "Published courses" },
    { value: `${Object.keys(FEATURE_META).length}+`, label: "Built-in tools" },
    { value: "SM-2", label: "Spaced-repetition scheduling" },
    { value: "₹0", label: "To get started" },
  ];

  return (
    <div className="min-h-dvh bg-background text-foreground">
      <LandingHeader audience="individual" navLinks={NAV_LINKS} />

      <LandingMotionConfig>
        <main>
          <LandingHero
            badge="Self-hosted · No vendor lock-in"
            description="Enroll in a course, open a real terminal for the labs, drill weak spots with spaced-repetition flashcards, and book a mentor when you're stuck — one account instead of five subscriptions."
            footline={`${total > 0 ? `${total} published courses` : "New courses shipping weekly"} · Free plan, no time limit`}
            heading={
              <>
                A learning path that ends in something <span className="text-primary">built</span>,
                not just watched
              </>
            }
            illustration={<LearnerIllustration className="mx-auto w-full max-w-xs sm:max-w-sm lg:mx-0 lg:max-w-md" />}
            primaryCta={{ label: "Start learning free", href: ROUTES.REGISTER }}
            secondaryCta={{ label: "Browse courses", href: ROUTES.COURSES }}
          />
          <LandingStats stats={stats} />
          <LandingFeatures
            items={SHOWCASE}
            subtitle="No separate video host, no separate judge, no separate flashcard app — it's one course, one account."
            title="Everything a course needs, built in"
          />
          <LandingPricing
            note="Buying one course instead? Pricing is set per course by its instructor — free or a one-time purchase, shown on the course page before you enroll."
            subtitle="Free is live today. The tiers below are what ships next — you won't be charged until they do."
            tiers={tiers}
            title="Pricing"
          />
          <LandingFaq faqs={FAQS} />
          <LandingCta
            description="Free to sign up, no credit card. Enroll in a free course today or buy a paid one when you're ready."
            heading="Start your first course today"
            primaryCta={{ label: "Get started", href: ROUTES.REGISTER }}
            secondaryCta={{ label: "Hiring or training a team?", href: ROUTES.ORG_LANDING }}
          />
        </main>
      </LandingMotionConfig>

      <LandingFooter />
    </div>
  );
}
