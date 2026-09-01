import type { Sample } from "@/lib/algo-visualizer/samples";

interface AlgorithmHeroProps {
  sample: Sample;
}

export function AlgorithmHero({ sample }: AlgorithmHeroProps) {
  return (
    <div className="card-raised mx-auto flex max-w-2xl flex-col items-center gap-4 text-center">
      <span className="rounded-pill border border-primary/20 bg-primary/10 px-3 py-1 text-xs font-semibold uppercase tracking-wide text-primary">
        {sample.tag}
      </span>
      <h2 className="text-2xl font-bold text-foreground sm:text-3xl">{sample.name}</h2>
      <p className="text-sm text-muted-foreground sm:text-base">{sample.description}</p>
      <div className="flex flex-wrap items-center justify-center gap-2">
        <span className="rounded-pill border border-border bg-muted px-3 py-1 font-mono text-xs text-foreground">
          <span className="text-muted-foreground">TIME</span> {sample.timeComplexity}
        </span>
        <span className="rounded-pill border border-border bg-muted px-3 py-1 font-mono text-xs text-foreground">
          <span className="text-muted-foreground">SPACE</span> {sample.spaceComplexity}
        </span>
      </div>
    </div>
  );
}
