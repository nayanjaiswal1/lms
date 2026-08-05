import {
  Bot,
  Building2,
  ClipboardCheck,
  FileText,
  GitBranch,
  GraduationCap,
  Link2,
  MessagesSquare,
  ShieldCheck,
} from "lucide-react";

import { LandingMotionConfig } from "@/components/landing/landing-motion";
import { LandingHeader } from "@/components/landing/landing-header";
import { LandingHero } from "@/components/landing/landing-hero";
import { LandingFeatures, type FeatureShowcaseItem } from "@/components/landing/landing-features";
import { LandingPricing } from "@/components/landing/landing-pricing";
import { LandingFaq, type FaqItem } from "@/components/landing/landing-faq";
import { LandingCta } from "@/components/landing/landing-cta";
import { LandingFooter } from "@/components/landing/landing-footer";
import { OrgIllustration } from "@/components/landing/landing-illustration";
import { FEATURE_META } from "@/lib/features";
import type { PricingTier } from "@/lib/server/pricing";
import ROUTES from "@/lib/routes";

const NAV_LINKS = [
  { label: "Features", href: "#features" },
  { label: "Pricing", href: "#pricing" },
  { label: "FAQ", href: "#faq" },
] as const;

const SHOWCASE: FeatureShowcaseItem[] = [
  { icon: Building2, ...FEATURE_META.multi_org },
  { icon: ShieldCheck, label: "Role-based access", description: "Admin, instructor, mentor, and student roles scoped to your organization." },
  { icon: ClipboardCheck, ...FEATURE_META.assessments },
  { icon: MessagesSquare, ...FEATURE_META.batch_chat },
  { icon: FileText, ...FEATURE_META.wiki },
  { icon: GraduationCap, ...FEATURE_META.session_booking },
  { icon: Link2, ...FEATURE_META.anonymous_tests },
  { icon: GitBranch, ...FEATURE_META.gitlab_integration },
  { icon: Bot, ...FEATURE_META.ai_connector },
];

const FAQS: FaqItem[] = [
  {
    question: "Can my college, bootcamp, or company use this?",
    answer:
      "Yes. Create an organization to get your own tenant with member invites, role-based access (admin, instructor, mentor, student), and a shared course library.",
  },
  {
    question: "Is our data isolated from other organizations?",
    answer:
      "Yes. MindForge is self-hosted and multi-tenant — each organization is its own tenant with no shared storage, and you can run the whole platform on your own infrastructure if you don't want it hosted for you.",
  },
  {
    question: "What counts as a seat?",
    answer:
      "Any invited member with a role — admin, instructor, mentor, or student. Learners using public/anonymous tests without an account don't count against your seat limit.",
  },
  {
    question: "Can we run assessments or interviews without asking candidates to sign up?",
    answer:
      "Yes — anonymous tests and public shareable links let anyone attempt a coding problem or quiz without an account, useful for screening or open practice.",
  },
  {
    question: "What's different about the Enterprise plan?",
    answer:
      "SSO, a custom domain, audit-log exports for compliance, and a dedicated AI token budget sized to your program instead of the shared default.",
  },
];

interface OrgLandingPageProps {
  orgName: string;
  tiers: PricingTier[];
}

export function OrgLandingPage({ orgName, tiers }: OrgLandingPageProps) {
  const roleCount = 4;
  const starterTier = tiers.find((tier) => tier.id === "org_starter");

  return (
    <div className="min-h-dvh bg-background text-foreground">
      <LandingHeader audience="org" navLinks={NAV_LINKS} />

      <LandingMotionConfig>
        <main>
          <LandingHero
            badge="Self-hosted · Your data, your tenant"
            description="Give every cohort its own tenant, role-based access down to mentor and student, a shared wiki, batch chat, and proctored assessments — deployed on your own infrastructure, not rented from someone else's cloud."
            footline={`${Object.keys(FEATURE_META).length}+ built-in tools · ${roleCount} roles per organization · Free up to 10 seats`}
            heading={
              <>
                Run your training program without renting out{" "}
                <span className="text-primary">your data</span>
              </>
            }
            illustration={<OrgIllustration className="mx-auto w-full max-w-xs sm:max-w-sm lg:mx-0 lg:max-w-md" />}
            primaryCta={{ label: "Set up your organization", href: ROUTES.ORG_CREATE }}
            secondaryCta={{ label: "See pricing", href: "#pricing" }}
          />
          <LandingFeatures
            items={SHOWCASE}
            subtitle="One tenant per organization, role-based access, and usage you can actually audit."
            title={`Built to run a cohort, not just ${orgName || "a course"}`}
          />
          <LandingPricing
            note="Buying course seats for a specific cohort instead of the whole org? Courses can still be priced per learner by their instructor, independent of your organization plan."
            subtitle="Per seat, billed monthly. Starter is free while you stay under 10 seats."
            tiers={tiers}
            title="Pricing"
          />
          <LandingFaq faqs={FAQS} />
          <LandingCta
            description={`Free while you're under 10 seats. ${starterTier?.tagline ?? ""}`}
            heading="Set up your organization"
            primaryCta={{ label: "Set up your organization", href: ROUTES.ORG_CREATE }}
            secondaryCta={{ label: "Learning on your own instead?", href: ROUTES.HOME }}
          />
        </main>
      </LandingMotionConfig>

      <LandingFooter />
    </div>
  );
}
