import { Reveal } from "@/components/landing/landing-motion";

interface Stat {
  value: string;
  label: string;
}

interface LandingStatsProps {
  stats: Stat[];
}

export function LandingStats({ stats }: LandingStatsProps) {
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
