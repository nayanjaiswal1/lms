"use client";

import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { Hammer } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { startBuildAction } from "@/lib/labs/builder/actions";

interface StartBuildButtonProps {
  recipeId: string;
  disabled: boolean;
  label: string;
}

export function StartBuildButton({ recipeId, disabled, label }: StartBuildButtonProps) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();

  const start = () =>
    startTransition(async () => {
      const res = await startBuildAction(recipeId);
      if (!res.ok) {
        toast.error(res.status === 429 ? "Daily build limit reached. Try again tomorrow." : (res.error ?? "Could not start the build."));
        return;
      }
      toast.success(res.data?.reused ? "This composition is already verified." : "Build queued.");
      router.refresh();
    });

  return (
    <Button className="self-start" disabled={disabled || pending} onClick={start}>
      <Hammer aria-hidden className="h-4 w-4" />
      {label}
    </Button>
  );
}
