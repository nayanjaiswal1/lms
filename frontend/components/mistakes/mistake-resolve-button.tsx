"use client";

import { useActionState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Check } from "lucide-react";
import { Button } from "@/components/ui/button";
import { resolveMistakeAction } from "@/app/(app)/mistakes/actions";

export function MistakeResolveButton({ entryId }: { entryId: string }) {
  const router = useRouter();

  const [, formAction, pending] = useActionState<null>(async () => {
    const result = await resolveMistakeAction(entryId);
    if (!result.ok) {
      toast.error(result.error ?? "Could not mark this resolved.");
      return null;
    }
    router.refresh();
    return null;
  }, null);

  return (
    <Button disabled={pending} size="sm" variant="outline" onClick={() => formAction()}>
      <Check aria-hidden className="mr-1.5 size-3.5" />
      {pending ? "Saving…" : "Mark resolved"}
    </Button>
  );
}
