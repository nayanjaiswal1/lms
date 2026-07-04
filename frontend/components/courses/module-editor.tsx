"use client";

import { useActionState, useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Label } from "@/components/ui/label";
import { MODULE_CONTENT_TYPE_OPTIONS } from "@/lib/constants";
import { createModuleAction } from "@/lib/courses/actions";

interface ModuleEditorProps {
  courseId: string;
  sectionId: string;
  initialValues?: {
    title?: string;
    type?: string;
    content_body?: string;
    estimated_minutes?: number;
  };
  onSaved?: () => void;
}

interface State { error?: string }

export function ModuleEditor({ courseId, sectionId, initialValues, onSaved }: ModuleEditorProps) {
  const [contentType, setContentType] = useState(initialValues?.type ?? "video");

  const [state, formAction, pending] = useActionState(
    async (_prev: State | null, fd: globalThis.FormData): Promise<State | null> => {
      const title = (fd.get("title") as string).trim();
      if (!title) return { error: "Title is required." };

      const result = await createModuleAction({
        course_id: courseId,
        section_id: sectionId,
        title,
        type: fd.get("type") as string,
        content_body: (fd.get("content_body") as string) || undefined,
        estimated_minutes: fd.get("estimated_minutes") ? Number(fd.get("estimated_minutes")) : undefined,
      });

      if (!result.ok) return { error: result.error };

      onSaved?.();
      return null;
    },
    null,
  );

  return (
    <form action={formAction} className="form-stack">
      <div className="flex flex-col gap-1.5">
        <Label htmlFor="mod-title">Module title</Label>
        <Input
          required
          defaultValue={initialValues?.title}
          disabled={pending}
          id="mod-title"
          name="title"
          placeholder="Introduction"
        />
      </div>

      <div className="grid-responsive-2 gap-4">
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="mod-type">Content type</Label>
          <Select defaultValue={contentType} disabled={pending} name="type" onValueChange={setContentType}>
            <SelectTrigger aria-label="Module content type" id="mod-type">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {MODULE_CONTENT_TYPE_OPTIONS.map((o) => (
                <SelectItem key={o.value} value={o.value}>{o.label}</SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        <div className="flex flex-col gap-1.5">
          <Label htmlFor="mod-minutes">Duration (minutes)</Label>
          <Input
            defaultValue={initialValues?.estimated_minutes}
            disabled={pending}
            id="mod-minutes"
            min={1}
            name="estimated_minutes"
            placeholder="15"
            type="number"
          />
        </div>
      </div>

      {contentType === "notes" && (
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="mod-body">Notes content</Label>
          <Textarea
            className="resize-y font-mono text-sm"
            defaultValue={initialValues?.content_body}
            disabled={pending}
            id="mod-body"
            name="content_body"
            placeholder="Write your notes here…"
            rows={10}
          />
        </div>
      )}

      {state?.error && <p className="text-sm text-destructive">{state.error}</p>}

      <div className="flex justify-end">
        <Button disabled={pending} type="submit">
          {pending ? "Saving…" : "Save module"}
        </Button>
      </div>
    </form>
  );
}
