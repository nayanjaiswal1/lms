"use client";

import { useActionState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { DIFFICULTY_OPTIONS } from "@/lib/constants";
import { addSheetItemAction } from "@/lib/sheets/actions";
import type { Difficulty } from "@/lib/server/sheets";

interface AddItemInlineRowProps {
  sheetId: string;
  cancelHref: string;
}

interface State {
  error?: string;
}

export function AddItemInlineRow({ sheetId, cancelHref }: AddItemInlineRowProps) {
  const router = useRouter();

  const [state, formAction, pending] = useActionState<State | null, FormData>(
    async (_prev, fd) => {
      const title = (fd.get("title") as string)?.trim() ?? "";
      if (!title) return { error: "Title is required." };

      const category = (fd.get("category") as string)?.trim();
      const difficulty = (fd.get("difficulty") as string)?.trim();
      const externalUrl = (fd.get("external_url") as string)?.trim();

      const result = await addSheetItemAction(sheetId, {
        title,
        category: category || undefined,
        difficulty: (difficulty as Difficulty) || undefined,
        external_url: externalUrl || undefined,
      });
      if (!result.ok) return { error: result.error };
      router.push(cancelHref);
      return null;
    },
    null,
  );

  return (
    <div className="rounded-md border border-primary/30 bg-primary/5 p-3 mt-3">
      <form action={formAction} className="flex flex-col gap-2 md:flex-row md:items-start" id="inline-add-item-form">
        <Input required className="md:flex-1" disabled={pending} name="title" placeholder="Problem title" />
        <Input className="md:w-56" disabled={pending} name="external_url" placeholder="Problem URL" type="url" />
        <Input className="md:w-40" disabled={pending} name="category" placeholder="Category" />
        <Select disabled={pending} name="difficulty">
          <SelectTrigger className="md:w-32">
            <SelectValue placeholder="Difficulty" />
          </SelectTrigger>
          <SelectContent>
            {DIFFICULTY_OPTIONS.map((d) => (
              <SelectItem key={d.value} value={d.value}>
                {d.label}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <div className="flex gap-2 shrink-0">
          <Button disabled={pending} size="sm" type="submit">
            {pending ? "Adding…" : "Add"}
          </Button>
          <Button asChild disabled={pending} size="sm" variant="ghost">
            <Link href={cancelHref}>Cancel</Link>
          </Button>
        </div>
      </form>
      {state?.error && <p className="text-sm text-destructive mt-2">{state.error}</p>}
    </div>
  );
}
