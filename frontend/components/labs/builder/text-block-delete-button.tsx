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
import { deleteTextBlockAction } from "@/lib/labs/builder/actions";
import ROUTES from "@/lib/routes";

interface TextBlockDeleteButtonProps {
  blockId: string;
}

export function TextBlockDeleteButton({ blockId }: TextBlockDeleteButtonProps) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();

  const handleDelete = () =>
    startTransition(async () => {
      const res = await deleteTextBlockAction(blockId);
      if (!res.ok) {
        toast.error(res.code === "block_in_use" ? "This block is used by a recipe or build, so it can't be deleted." : (res.error ?? "Could not delete the block."));
        return;
      }
      toast.success("Block deleted");
      router.push(ROUTES.LAB_BUILDER_BLOCKS);
    });

  return (
    <AlertDialog>
      <AlertDialogTrigger asChild>
        <Button disabled={pending} type="button" variant="outline">
          <Trash2 aria-hidden className="mr-2 h-4 w-4" />
          Delete
        </Button>
      </AlertDialogTrigger>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>Delete this block?</AlertDialogTitle>
          <AlertDialogDescription>
            Only blocks no recipe or build uses can be deleted. Otherwise save a new version instead.
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
