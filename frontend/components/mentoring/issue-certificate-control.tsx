"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Award } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { issueCertificateAction } from "@/lib/mentoring/actions";

interface IssueCertificateControlProps {
  courseId: string;
  studentId: string;
}

// Manual override for a mentor/instructor/admin to award a student's
// certificate directly, bypassing the final-test/threshold gates — for
// cases the automatic paths don't cover (e.g. offline assessment).
export function IssueCertificateControl({ courseId, studentId }: IssueCertificateControlProps) {
  const [pending, setPending] = useState(false);
  const router = useRouter();

  async function handleIssue() {
    setPending(true);
    const result = await issueCertificateAction(courseId, studentId);
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Certificate issued.");
    router.refresh();
  }

  return (
    <Button disabled={pending} size="sm" variant="outline" onClick={handleIssue}>
      <Award aria-hidden className="h-4 w-4" />
      {pending ? "Issuing…" : "Issue certificate"}
    </Button>
  );
}
