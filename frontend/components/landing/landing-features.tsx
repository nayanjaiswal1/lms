import type { LucideIcon } from "lucide-react";
import {
  Award,
  BookOpen,
  FileText,
  Gauge,
  Layers,
  ListChecks,
  MessageCircleQuestion,
  MonitorPlay,
  Sparkles,
  TerminalSquare,
  Users,
  Workflow,
} from "lucide-react";

import { Reveal } from "@/components/landing/landing-motion";
import { FEATURE_META, type Feature } from "@/lib/features";

const SHOWCASE: { feature: Feature; icon: LucideIcon }[] = [
  { feature: "courses", icon: BookOpen },
  { feature: "coding_problems", icon: TerminalSquare },
  { feature: "system_design", icon: Workflow },
  { feature: "interview_board", icon: MonitorPlay },
  { feature: "load_test", icon: Gauge },
  { feature: "sheet_tracker", icon: ListChecks },
  { feature: "flashcards", icon: Layers },
  { feature: "certificates", icon: Award },
  { feature: "wiki", icon: FileText },
  { feature: "ai_features", icon: Sparkles },
  { feature: "mentors", icon: Users },
  { feature: "interview_exp", icon: MessageCircleQuestion },
];

export function LandingFeatures() {
  return (
    <section
      aria-labelledby="features-heading"
      className="scroll-mt-16 border-b border-border py-16 sm:py-24"
      id="features"
    >
      <div className="page-container">
        <Reveal>
          <h2 className="text-center text-2xl font-bold sm:text-3xl" id="features-heading">
            More than videos
          </h2>
          <p className="mx-auto mt-2 max-w-xl text-center text-sm text-muted-foreground">
            Every course plugs into the same toolkit, so learning turns into
            doing.
          </p>
        </Reveal>

        <ul className="card-grid mt-10">
          {SHOWCASE.map(({ feature, icon: Icon }, index) => {
            const { label, description } = FEATURE_META[feature];
            return (
              <Reveal delay={(index % 3) * 0.08} key={feature}>
                <li className="card-interactive h-full">
                  <Icon aria-hidden className="h-6 w-6 text-primary" />
                  <h3 className="mt-3 text-base font-semibold">{label}</h3>
                  <p className="mt-1 text-sm text-muted-foreground">{description}</p>
                </li>
              </Reveal>
            );
          })}
        </ul>
      </div>
    </section>
  );
}
