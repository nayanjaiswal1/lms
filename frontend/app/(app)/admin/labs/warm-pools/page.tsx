import { notFound } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { getMyPermissions } from "@/lib/server/permissions";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import { apiGet } from "@/lib/server/api";
import { WarmPoolRowForm } from "./warm-pool-row-form";

interface WarmPoolMatrixRow {
  lab_id: string;
  title: string;
  lab_type: string;
  mode: string;
  fixed_size: number;
  max_size: number;
  ready: number;
  warming: number;
  claimed: number;
  target: number;
  decided_at: string | null;
  inputs: Record<string, unknown>;
}

function formatSignalKey(key: string): string {
  return key.replace(/_/g, " ");
}

export default async function WarmPoolsPage() {
  const myPerms = await getMyPermissions();
  if (!myPerms.includes(PERMISSIONS.ADMIN.MANAGE_ORG)) {
    notFound();
  }

  const { labs } = await apiGet<{ labs: WarmPoolMatrixRow[] }>("/api/admin/labs/warm-pools");

  const signalKeys = Array.from(
    new Set(labs.flatMap((lab) => Object.keys(lab.inputs ?? {}))),
  ).sort();

  return (
    <div className="page-container py-8">
      <div className="page-header">
        <div>
          <h1 className="page-title">Warm Pool Sizing</h1>
          <p className="text-muted-foreground mt-1">
            The signals each lab&apos;s reconciler last used to decide its target pool size, and
            the current mode/override controls per lab.
          </p>
        </div>
        <Badge variant="outline">{labs.length} labs</Badge>
      </div>

      <div className="mt-8 table-responsive">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-border text-left text-muted-foreground">
              <th className="pb-2 pr-6 font-medium">Lab</th>
              <th className="pb-2 pr-6 font-medium">Ready</th>
              <th className="pb-2 pr-6 font-medium">Warming</th>
              <th className="pb-2 pr-6 font-medium">Claimed</th>
              <th className="pb-2 pr-6 font-medium">Target</th>
              <th className="pb-2 pr-6 font-medium">Decided at</th>
              {signalKeys.map((key) => (
                <th key={key} className="pb-2 pr-6 font-medium capitalize whitespace-nowrap">
                  {formatSignalKey(key)}
                </th>
              ))}
              <th className="pb-2 font-medium">Config</th>
            </tr>
          </thead>
          <tbody>
            {labs.map((lab) => (
              <tr key={lab.lab_id} className="border-b border-border last:border-0 align-top">
                <td className="py-3 pr-6">
                  <div className="font-medium">{lab.title}</div>
                  <div className="text-muted-foreground text-xs">{lab.lab_type}</div>
                </td>
                <td className="py-3 pr-6">{lab.ready}</td>
                <td className="py-3 pr-6">{lab.warming}</td>
                <td className="py-3 pr-6">{lab.claimed}</td>
                <td className="py-3 pr-6">{lab.target}</td>
                <td className="py-3 pr-6 text-muted-foreground whitespace-nowrap">
                  {lab.decided_at ? new Date(lab.decided_at).toLocaleString() : "—"}
                </td>
                {signalKeys.map((key) => (
                  <td key={key} className="py-3 pr-6 text-muted-foreground whitespace-nowrap">
                    {lab.inputs?.[key] === undefined ? "—" : String(lab.inputs[key])}
                  </td>
                ))}
                <td className="py-3">
                  <WarmPoolRowForm
                    labId={lab.lab_id}
                    mode={lab.mode}
                    fixedSize={lab.fixed_size}
                    maxSize={lab.max_size}
                  />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
