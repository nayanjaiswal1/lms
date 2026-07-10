"use client";

import { useActionState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import ROUTES from "@/lib/routes";
import { combineSheetsAction } from "@/lib/sheets/actions";
import type { UserSheetSummary } from "@/lib/server/sheets";

interface CombineSheetsPanelProps {
  sheets: UserSheetSummary[];
}

interface State {
  error?: string;
}

export function CombineSheetsPanel({ sheets }: CombineSheetsPanelProps) {
  const router = useRouter();

  const [state, formAction, pending] = useActionState<State | null, FormData>(
    async (_prev, fd) => {
      const name = (fd.get("name") as string)?.trim() ?? "";
      if (!name) return { error: "Name is required." };

      const sheetIds = fd.getAll("sheet_ids") as string[];
      if (sheetIds.length < 2) return { error: "Select at least 2 sheets to combine." };

      const result = await combineSheetsAction({ name, sheet_ids: sheetIds });
      if (!result.ok) return { error: result.error };
      if (result.data) router.push(`${ROUTES.SHEETS}?sheet=${encodeURIComponent(result.data.slug)}`);
      return null;
    },
    null,
  );

  if (sheets.length < 2) {
    return (
      <p className="text-sm text-muted-foreground py-4">
        You need at least 2 tracked sheets before you can combine them.
      </p>
    );
  }

  return (
    <form action={formAction} className="form-stack max-w-lg">
      <div className="flex flex-col gap-1.5">
        <Label htmlFor="combine-name">Name</Label>
        <Input required disabled={pending} id="combine-name" name="name" placeholder="My Combined Sheet" />
      </div>

      <div className="flex flex-col gap-1.5">
        <Label>Sheets to combine</Label>
        <ul className="flex flex-col divide-y divide-border rounded-md border border-border">
          {sheets.map((sheet) => (
            <li className="flex items-center gap-3 px-3 py-2.5" key={sheet.id}>
              <Checkbox disabled={pending} id={`combine-${sheet.id}`} name="sheet_ids" value={sheet.id} />
              <Label className="flex-1 cursor-pointer font-normal" htmlFor={`combine-${sheet.id}`}>
                {sheet.name}
              </Label>
            </li>
          ))}
        </ul>
        <p className="text-xs text-muted-foreground">
          Items are deduped by topic — the same problem in multiple sheets appears once.
        </p>
      </div>

      {state?.error && <p className="text-sm text-destructive">{state.error}</p>}
      <div>
        <Button disabled={pending} type="submit">
          {pending ? "Combining…" : "Combine sheets"}
        </Button>
      </div>
    </form>
  );
}
