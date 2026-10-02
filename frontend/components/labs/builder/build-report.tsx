import { CheckCircle2, CircleDashed, XCircle } from "lucide-react";
import { BuildRunRow } from "@/components/labs/builder/build-run-row";
import { LabMarkdown } from "@/components/labs/kinds/debug/lab-markdown";
import type { BuildView } from "@/lib/labs/builder/types";

interface BuildReportProps {
  build: BuildView;
}

/** The live verification matrix of a build, per variant, plus each variant's final ticket. */
export function BuildReport({ build }: BuildReportProps) {
  const report = build.report;
  return (
    <div className="flex flex-col gap-4">
      {report?.error && <p className="text-sm text-destructive">{report.error}</p>}
      {(report?.issues ?? []).map((is, i) => (
        <p className="text-sm text-destructive" key={`${is.code}-${i}`}>
          {is.block && <span className="font-mono">{is.block}: </span>}
          {is.message}
        </p>
      ))}
      {(report?.variants ?? []).map((v) => (
        <section aria-label={`Variant ${v.variant_key}`} className="card-base flex flex-col gap-2" key={v.variant_key}>
          <h3 className="flex items-center gap-2 text-sm font-semibold">
            {v.passed ? (
              <CheckCircle2 aria-hidden className="h-4 w-4 text-success" />
            ) : (
              <XCircle aria-hidden className="h-4 w-4 text-destructive" />
            )}
            Variant <span className="font-mono">{v.variant_key}</span>
          </h3>
          {v.capture_note && <p className="text-xs text-destructive">{v.capture_note}</p>}
          <ul>
            {(v.runs ?? []).map((r) => (
              <BuildRunRow key={r.name} run={r} />
            ))}
          </ul>
          {(v.pending_runs ?? []).map((name) => (
            <p className="flex items-center gap-2 text-xs text-muted-foreground" key={name}>
              <CircleDashed aria-hidden className="h-3.5 w-3.5" />
              <span className="font-mono">{name}</span> waiting for a sandbox
            </p>
          ))}
        </section>
      ))}
      {build.variants.map((v) => (
        <details className="card-base" key={v.key}>
          <summary className="cursor-pointer text-sm font-semibold">
            Student ticket — variant <span className="font-mono">{v.key}</span>
          </summary>
          <div className="mt-3">
            <LabMarkdown>{v.brief_md}</LabMarkdown>
          </div>
        </details>
      ))}
    </div>
  );
}
