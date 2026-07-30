"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { ArrowRightLeft } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { setAssessmentStatusAction } from "@/app/(app)/assessments/actions";
import { ASSESSMENT_MANUAL_STATUS_OPTIONS } from "@/lib/constants";

interface StatusActionProps {
  assessmentId: string;
  status: string;
}

export function StatusAction({ assessmentId, status }: StatusActionProps) {
  const router = useRouter();
  const [target, setTarget] = React.useState<string | null>(null);
  const [pending, setPending] = React.useState(false);

  const statusOptions = ASSESSMENT_MANUAL_STATUS_OPTIONS.filter((o) => o.value !== status);
  const targetOption = ASSESSMENT_MANUAL_STATUS_OPTIONS.find((o) => o.value === target);

  if (statusOptions.length === 0) return null;

  const confirmMove = async () => {
    if (!target) return;
    setPending(true);
    const res = await setAssessmentStatusAction(assessmentId, target);
    setPending(false);
    if (res.error) {
      toast.error(res.error);
      return;
    }
    toast.success(`Moved to ${targetOption?.label ?? target}.`);
    setTarget(null);
    router.refresh();
  };

  return (
    <>
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="outline">
            <ArrowRightLeft aria-hidden className="h-4 w-4" /> Move to…
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          {statusOptions.map((o) => (
            <DropdownMenuItem key={o.value} onSelect={() => setTarget(o.value)}>
              {o.label}
            </DropdownMenuItem>
          ))}
        </DropdownMenuContent>
      </DropdownMenu>

      <AlertDialog open={target !== null} onOpenChange={(open) => !open && setTarget(null)}>
        <AlertDialogContent className="modal-responsive">
          <AlertDialogHeader>
            <AlertDialogTitle>Move to {targetOption?.label}?</AlertDialogTitle>
            <AlertDialogDescription>
              {targetOption?.description}
              {(status === "active" || status === "published") &&
                " This assessment currently has students actively taking it — moving it will change what they see immediately."}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel disabled={pending}>Cancel</AlertDialogCancel>
            <AlertDialogAction disabled={pending} onClick={confirmMove}>
              {pending ? "Moving…" : "Move"}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  );
}
