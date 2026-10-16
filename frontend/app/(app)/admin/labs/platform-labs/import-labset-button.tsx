"use client";

import { useTransition } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { importLabsetAction } from "./actions";

export function ImportLabsetButton() {
  const [pending, startTransition] = useTransition();

  const onClick = () =>
    startTransition(async () => {
      const { result, error } = await importLabsetAction();
      if (error || !result) {
        toast.error(error ?? "Labset import failed.");
        return;
      }
      toast.success(`${result.recipes} labs checked, ${result.published} newly published.`);
    });

  return (
    <Button className="self-start" disabled={pending} onClick={onClick}>
      {pending ? "Importing…" : "Import published labset"}
    </Button>
  );
}
