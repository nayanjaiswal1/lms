import Link from "next/link";
import { ClipboardCheck } from "lucide-react";
import { Button } from "@/components/ui/button";
import ROUTES from "@/lib/routes";

interface ModuleAssessmentProps {
  moduleId: string;
  assessmentId: string;
}

export function ModuleAssessment({ assessmentId }: ModuleAssessmentProps) {
  return (
    <div className="empty-state flex-col gap-4 py-12">
      <ClipboardCheck aria-hidden className="h-12 w-12 text-muted-foreground" />
      <div className="flex flex-col items-center gap-1 text-center">
        <p className="text-sm text-muted-foreground">Complete this assessment to mark the module finished.</p>
      </div>
      <Button asChild>
        <Link href={ROUTES.assessmentTake(assessmentId)}>Start Assessment</Link>
      </Button>
    </div>
  );
}
