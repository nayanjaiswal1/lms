"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { resolveReportAction } from "@/lib/mentoring/actions";

interface ResolveReportControlProps {
  reportId: string;
}

export function ResolveReportControl({ reportId }: ResolveReportControlProps) {
  const [pending, setPending] = useState<"resolved" | "dismissed" | null>(null);
  const router = useRouter();

  async function handle(status: "resolved" | "dismissed") {
    setPending(status);
    const result = await resolveReportAction(reportId, status);
    setPending(null);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(status === "resolved" ? "Report resolved." : "Report dismissed.");
    router.refresh();
  }

  return (
    <div className="flex items-center gap-2">
      <Button disabled={pending !== null} size="sm" onClick={() => void handle("resolved")}>
        {pending === "resolved" ? "Resolving…" : "Resolve"}
      </Button>
      <Button
        disabled={pending !== null}
        size="sm"
        variant="outline"
        onClick={() => void handle("dismissed")}
      >
        {pending === "dismissed" ? "Dismissing…" : "Dismiss"}
      </Button>
    </div>
  );
}
