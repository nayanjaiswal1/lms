import { Reveal } from "@/components/landing/landing-motion";
import { FEATURE_META, PLAN_TIERS } from "@/lib/features";

interface LandingStatsProps {
  courseTotal: number;
}

const featureCount = Object.keys(FEATURE_META).length;
const freeTier = PLAN_TIERS.find((tier) => tier.id === "free");

export function LandingStats({ courseTotal }: LandingStatsProps) {
  const stats = [
    { value: String(courseTotal), label: "Published courses" },
    { value: `${featureCount}+`, label: "Built-in tools" },
    { value: "4", label: "Roles per organization" },
    { value: freeTier?.price ?? "$0", label: freeTier?.tagline ?? "To get started" },
  ];

  return (
    <section aria-label="Platform stats" className="border-b border-border bg-muted/30 py-10">
      <Reveal className="page-container grid-stats">
        {stats.map(({ value, label }) => (
          <div className="flex flex-col items-center gap-1 text-center" key={label}>
            <span className="text-3xl font-bold text-primary sm:text-4xl">{value}</span>
            <span className="text-sm text-muted-foreground">{label}</span>
          </div>
        ))}
      </Reveal>
    </section>
  );
}
