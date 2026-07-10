"use client";

import { useActionState } from "react";
import { Upload, FileSpreadsheet } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { importParseAction } from "@/app/(app)/batches/actions";
import type { ImportMemberRow } from "@/lib/server/batches";

interface ParseState {
  rows?: ImportMemberRow[];
  error?: string;
}

interface UploadStepProps {
  batchId: string;
  onParsed: (rows: ImportMemberRow[]) => void;
}

export function UploadStep({ batchId, onParsed }: UploadStepProps) {
  const [state, dispatch, pending] = useActionState<ParseState, FormData>(async (_prev, formData) => {
    const result = await importParseAction(batchId, formData);
    if (result.error) return { error: result.error };
    const rows = result.data?.rows ?? [];
    if (rows.length === 0) return { error: "No student rows found in this file." };
    onParsed(rows);
    return { rows };
  }, {});

  return (
    <section aria-labelledby="import-upload-heading" className="card-base p-6 space-y-5">
      <div>
        <h2 className="subsection-title text-foreground" id="import-upload-heading">
          Upload roster
        </h2>
        <p className="text-sm text-muted-foreground mt-1">
          Upload an .xlsx file with columns for Full Name and Email (required), plus optional Roll
          Number, Phone Number, Department, and any other custom columns.
        </p>
      </div>

      <form action={dispatch} className="space-y-4">
        <div className="space-y-1.5">
          <Label htmlFor="import-file">Excel file (.xlsx)</Label>
          <label
            className="flex flex-col items-center justify-center gap-2 w-full min-h-[140px] rounded-lg border-2 border-dashed border-border bg-muted/40 cursor-pointer transition-colors hover:border-primary hover:bg-muted/60"
            htmlFor="import-file"
          >
            <Upload aria-hidden className="h-6 w-6 text-muted-foreground" />
            <span className="text-sm text-muted-foreground">Click to choose an .xlsx file</span>
            <input
              accept=".xlsx"
              className="sr-only"
              id="import-file"
              name="file"
              type="file"
            />
          </label>
        </div>

        {state.error && <p className="text-sm text-destructive">{state.error}</p>}

        <Button className="px-5 py-2.5" disabled={pending} type="submit">
          {pending ? (
            "Parsing…"
          ) : (
            <>
              <FileSpreadsheet aria-hidden className="mr-2 h-4 w-4" />
              Parse Roster
            </>
          )}
        </Button>
      </form>
    </section>
  );
}
