"use client";

import { useActionState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import ROUTES from "@/lib/routes";
import { createSheetAction } from "@/lib/sheets/actions";

interface State {
  error?: string;
}

export function CreateCustomPanel() {
  const router = useRouter();

  const [state, formAction, pending] = useActionState<State | null, FormData>(
    async (_prev, fd) => {
      const name = (fd.get("name") as string)?.trim() ?? "";
      if (!name) return { error: "Name is required." };

      const description = (fd.get("description") as string)?.trim();
      const category = (fd.get("category") as string)?.trim();

      const result = await createSheetAction({
        name,
        description: description || undefined,
        category: category || undefined,
      });
      if (!result.ok) return { error: result.error };
      if (result.data) router.push(`${ROUTES.SHEETS}?sheet=${encodeURIComponent(result.data.slug)}`);
      return null;
    },
    null,
  );

  return (
    <form action={formAction} className="form-stack max-w-lg">
      <div className="flex flex-col gap-1.5">
        <Label htmlFor="sheet-name">Name</Label>
        <Input required disabled={pending} id="sheet-name" name="name" placeholder="My DSA Revision List" />
      </div>
      <div className="flex flex-col gap-1.5">
        <Label htmlFor="sheet-category">Category</Label>
        <Input disabled={pending} id="sheet-category" name="category" placeholder="DSA" />
      </div>
      <div className="flex flex-col gap-1.5">
        <Label htmlFor="sheet-description">Description</Label>
        <Textarea disabled={pending} id="sheet-description" name="description" rows={3} />
      </div>
      {state?.error && <p className="text-sm text-destructive">{state.error}</p>}
      <div>
        <Button disabled={pending} type="submit">
          {pending ? "Creating…" : "Create sheet"}
        </Button>
      </div>
    </form>
  );
}
