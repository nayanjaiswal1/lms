"use client";

import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { WARM_POOL_MODE } from "@/lib/constants";
import ROUTES from "@/lib/routes";

export interface WarmPoolRowData {
  image: string;
  lab_count: number;
  ready: number;
  warming: number;
  claimed: number;
  warmup_seconds: number;
  warmup_samples: number;
  mode: string;
  target: number;
  reason: string;
  decided_at: string | null;
}

function ModeBadge({ mode }: { mode: string }) {
  if (mode === WARM_POOL_MODE.FIXED) return <Badge className="badge-info" variant="outline">Fixed</Badge>;
  if (mode === WARM_POOL_MODE.OFF) return <Badge className="badge-muted" variant="outline">Off</Badge>;
  return <Badge className="badge-success" variant="outline">Auto</Badge>;
}

function PoolCell({ value, tone }: { value: number; tone: "success" | "warning" }) {
  const toneClass = value === 0 ? "text-muted-foreground" : tone === "success" ? "text-success" : "text-warning-foreground";
  return <span className={`font-semibold tabular-nums ${toneClass}`}>{value}</span>;
}

// An image with no measured warm start yet is sized off the platform default,
// so the number is shown as an estimate rather than a fact until the reconciler
// has actually timed a boot.
function WarmupCell({ seconds, samples }: { seconds: number; samples: number }) {
  if (samples === 0) {
    return <span className="tabular-nums text-muted-foreground">{Math.round(seconds)}s <span className="text-xs">est.</span></span>;
  }
  return (
    <span className="tabular-nums text-foreground">
      {Math.round(seconds)}s <span className="text-xs text-muted-foreground">n={samples}</span>
    </span>
  );
}

export function WarmPoolTable({ images }: { images: WarmPoolRowData[] }) {
  if (images.length === 0) {
    return (
      <div className="empty-state">
        <p className="font-medium text-foreground">No container-backed labs yet</p>
        <p className="text-sm text-muted-foreground mt-1">
          Publish a terminal, guided, playground, or sandbox lab to see its image here — code
          labs never appear, they don&apos;t use a container.
        </p>
      </div>
    );
  }

  return (
    <>
      <div className="page-header">
        <div>
          <h1 className="page-title">Warm Pool Sizing</h1>
          <p className="text-muted-foreground mt-1 max-w-2xl">
            Sandboxes are pooled per image, not per lab — every lab on the same image draws
            from the same pool. The platform sizes each pool automatically from arrival rate
            and measured warm-start time; the Target and Why columns show what it decided and
            on what evidence.
          </p>
          <Link
            className="text-sm text-primary underline underline-offset-2 mt-2 inline-block"
            href={ROUTES.ADMIN_LABS_USAGE}
          >
            View compute usage →
          </Link>
        </div>
        <Badge className="badge-muted" variant="outline">
          {images.length} image{images.length === 1 ? "" : "s"}
        </Badge>
      </div>

      <div className="mt-8 card-base table-responsive">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-border text-left text-muted-foreground whitespace-nowrap">
              <th className="p-4 font-medium">Image</th>
              <th className="p-4 font-medium">Mode</th>
              <th className="p-4 font-medium text-right">Ready</th>
              <th className="p-4 font-medium text-right">Warming</th>
              <th className="p-4 font-medium text-right">Claimed</th>
              <th className="p-4 font-medium text-right">Target</th>
              <th className="p-4 font-medium text-right">Warm start</th>
              <th className="p-4 font-medium">Why</th>
              <th className="p-4 font-medium">Decided</th>
            </tr>
          </thead>
          <tbody>
            {images.map((img) => {
              const isIdle = img.target === 0 && img.ready === 0 && img.warming === 0 && img.claimed === 0;
              return (
                <tr
                  className={`border-b border-border last:border-0 whitespace-nowrap ${isIdle ? "opacity-60" : ""}`}
                  key={img.image}
                >
                  <td className="p-4 max-w-64">
                    <div className="font-medium text-foreground truncate font-mono text-xs">{img.image}</div>
                    <div className="text-xs text-muted-foreground">
                      {img.lab_count} lab{img.lab_count === 1 ? "" : "s"}
                    </div>
                  </td>
                  <td className="p-4"><ModeBadge mode={img.mode} /></td>
                  <td className="p-4 text-right"><PoolCell tone="success" value={img.ready} /></td>
                  <td className="p-4 text-right"><PoolCell tone="warning" value={img.warming} /></td>
                  <td className="p-4 text-right text-muted-foreground tabular-nums">{img.claimed}</td>
                  <td className="p-4 text-right font-semibold text-primary tabular-nums">{img.target}</td>
                  <td className="p-4 text-right">
                    <WarmupCell samples={img.warmup_samples} seconds={img.warmup_seconds} />
                  </td>
                  <td className="p-4 text-xs text-muted-foreground whitespace-normal min-w-64">
                    {img.reason || "—"}
                  </td>
                  <td className="p-4 text-xs text-muted-foreground">
                    {img.decided_at ? new Date(img.decided_at).toLocaleString() : "—"}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </>
  );
}
