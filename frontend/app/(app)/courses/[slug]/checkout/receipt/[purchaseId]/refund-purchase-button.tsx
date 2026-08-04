"use client";

import { useState } from "react";
import { toast } from "sonner";
import { Loader2 } from "lucide-react";

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
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import { refundPurchaseAction } from "@/lib/mentoring/actions";

interface RefundPurchaseButtonProps {
  courseId: string;
  purchaseId: string;
}

export function RefundPurchaseButton({ courseId, purchaseId }: RefundPurchaseButtonProps) {
  const [pending, setPending] = useState(false);

  async function handleRefund() {
    setPending(true);
    const result = await refundPurchaseAction(courseId, purchaseId);
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Purchase refunded.");
  }

  return (
    <AlertDialog>
      <AlertDialogTrigger asChild>
        <Button disabled={pending} size="sm" variant="destructive">
          {pending ? <Loader2 aria-hidden className="animate-spin" /> : null}
          Issue refund
        </Button>
      </AlertDialogTrigger>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>Refund this purchase?</AlertDialogTitle>
          <AlertDialogDescription>
            This calls the payment gateway to reverse the charge and revokes the student&apos;s
            course access. This cannot be undone.
          </AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel>Cancel</AlertDialogCancel>
          <AlertDialogAction onClick={() => void handleRefund()}>Refund</AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}
