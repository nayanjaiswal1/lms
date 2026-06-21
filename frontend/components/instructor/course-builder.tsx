"use client";

import { useActionState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Checkbox } from "@/components/ui/checkbox";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Label } from "@/components/ui/label";
import { createCourseAction } from "@/lib/courses/actions";
import { COURSE_DIFFICULTY_OPTIONS } from "@/lib/constants";
import ROUTES from "@/lib/routes";

interface State {
  error?: string;
  fields?: Record<string, string>;
}

export function CourseBuilder() {
  const router = useRouter();

  const [state, formAction, pending] = useActionState(
    async (_prev: State | null, fd: globalThis.FormData): Promise<State | null> => {
      const title = (fd.get("title") as string).trim();
      if (!title) return { error: "Title is required.", fields: { title } };

      const description = (fd.get("description") as string).trim() || undefined;
      const difficulty = (fd.get("difficulty") as string) || "beginner";
      const tagsRaw = (fd.get("tags") as string) ?? "";
      const tags = tagsRaw.split(",").map((t) => t.trim()).filter(Boolean);
      const is_free = fd.get("is_free") === "on";

      const result = await createCourseAction({ title, description, difficulty, tags, is_free });
      if (!result.ok || !result.data) return { error: result.error ?? "Course ID missing from response." };
      router.push(ROUTES.instructorCourse(result.data.id));
      return null;
    },
    null,
  );

  return (
    <form action={formAction} className="form-stack">
      <div className="flex flex-col gap-1.5">
        <Label htmlFor="title">Course title</Label>
        <Input required disabled={pending} id="title" name="title" placeholder="Introduction to Go" />
      </div>

      <div className="flex flex-col gap-1.5">
        <Label htmlFor="description">Description</Label>
        <Textarea
          className="resize-none"
          disabled={pending}
          id="description"
          name="description"
          placeholder="What will students learn?"
          rows={4}
        />
      </div>

      <div className="grid-responsive-2 gap-4">
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="difficulty">Difficulty</Label>
          <Select defaultValue="beginner" disabled={pending} name="difficulty">
            <SelectTrigger aria-label="Difficulty level" id="difficulty">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {COURSE_DIFFICULTY_OPTIONS.map((o) => (
                <SelectItem key={o.value} value={o.value}>{o.label}</SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        <div className="flex flex-col gap-1.5">
          <Label htmlFor="tags">Tags (comma-separated)</Label>
          <Input disabled={pending} id="tags" name="tags" placeholder="go, backend, concurrency" />
        </div>
      </div>

      <div className="flex items-center gap-2">
        <Checkbox defaultChecked disabled={pending} id="is_free" name="is_free" />
        <Label className="cursor-pointer font-normal" htmlFor="is_free">Free course (no enrollment fee)</Label>
      </div>

      {state?.error && <p className="text-sm text-destructive">{state.error}</p>}

      <div className="flex justify-end">
        <Button disabled={pending} type="submit">
          {pending ? "Creating…" : "Create course"}
        </Button>
      </div>
    </form>
  );
}
