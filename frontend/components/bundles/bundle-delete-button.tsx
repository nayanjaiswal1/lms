"use client";

import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { Trash2 } from "lucide-react";
import { toast } from "sonner";
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
import { deleteBundleAction } from "@/lib/bundles/actions";
import ROUTES from "@/lib/routes";

interface BundleDeleteButtonProps {
  bundleID: string;
}

export function BundleDeleteButton({ bundleID }: BundleDeleteButtonProps) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();

  function handleDelete() {
    startTransition(async () => {
      const result = await deleteBundleAction(bundleID);
      if (!result.ok) {
        toast.error(result.error ?? "Could not delete the bundle.");
        return;
      }
      toast.success("Bundle deleted.");
      router.push(ROUTES.COURSES);
    });
  }

  return (
    <AlertDialog>
      <AlertDialogTrigger asChild>
        <Button className="touch-target" disabled={pending} type="button" variant="outline">
          <Trash2 aria-hidden className="mr-2 h-4 w-4" />
          Delete bundle
        </Button>
      </AlertDialogTrigger>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>Delete this bundle?</AlertDialogTitle>
          <AlertDialogDescription>
            The courses themselves, and every student&apos;s enrollment and progress in them, stay as they are.
          </AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel>Cancel</AlertDialogCancel>
          <AlertDialogAction onClick={handleDelete}>Delete</AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}
