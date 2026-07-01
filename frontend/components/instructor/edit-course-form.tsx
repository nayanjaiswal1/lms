"use client";

import { useActionState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Checkbox } from "@/components/ui/checkbox";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Label } from "@/components/ui/label";
import { updateCourseAction } from "@/lib/courses/actions";
import { COURSE_DIFFICULTY_OPTIONS } from "@/lib/constants";
import ROUTES from "@/lib/routes";
import type { Course } from "@/lib/server/courses";

interface Props {
  course: Course;
}

interface State {
  error?: string;
}

export function EditCourseForm({ course }: Props) {
  const router = useRouter();

  const [state, formAction, pending] = useActionState(
    async (_prev: State | null, fd: globalThis.FormData): Promise<State | null> => {
      const title = (fd.get("title") as string).trim();
      if (!title) return { error: "Title is required." };
      if (title.length < 3 || title.length > 200) {
        return { error: "Title must be 3–200 characters." };
      }

      const description = (fd.get("description") as string).trim() || undefined;
      const cover_url = (fd.get("cover_url") as string).trim() || undefined;
      const difficulty = (fd.get("difficulty") as string) || "beginner";
      const tagsRaw = (fd.get("tags") as string) ?? "";
      const tags = tagsRaw.split(",").map((t) => t.trim()).filter(Boolean);
      const is_free = fd.get("is_free") === "on";

      const result = await updateCourseAction(course.id, {
        title,
        description,
        cover_url,
        difficulty,
        tags,
        is_free,
      });

      if (!result.ok) return { error: result.error ?? "Failed to save changes." };
      router.push(ROUTES.manageCourse(course.id));
      return null;
    },
    null,
  );

  return (
    <form action={formAction} className="form-stack">
      <div className="flex flex-col gap-1.5">
        <Label htmlFor="title">Course title</Label>
        <Input
          required
          defaultValue={course.title}
          disabled={pending}
          id="title"
          name="title"
          placeholder="Introduction to Go"
        />
      </div>

      <div className="flex flex-col gap-1.5">
        <Label htmlFor="description">Description</Label>
        <Textarea
          className="resize-none"
          defaultValue={course.description ?? ""}
          disabled={pending}
          id="description"
          name="description"
          placeholder="What will students learn?"
          rows={4}
        />
      </div>

      <div className="flex flex-col gap-1.5">
        <Label htmlFor="cover_url">Cover image URL</Label>
        <Input
          defaultValue={course.cover_url ?? ""}
          disabled={pending}
          id="cover_url"
          name="cover_url"
          placeholder="https://example.com/cover.jpg"
          type="url"
        />
      </div>

      <div className="grid-responsive-2 gap-4">
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="difficulty">Difficulty</Label>
          <Select defaultValue={course.difficulty || "beginner"} disabled={pending} name="difficulty">
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
          <Input
            defaultValue={(course.tags ?? []).join(", ")}
            disabled={pending}
            id="tags"
            name="tags"
            placeholder="go, backend, concurrency"
          />
        </div>
      </div>

      <div className="flex items-center gap-2">
        <Checkbox defaultChecked={course.is_free} disabled={pending} id="is_free" name="is_free" />
        <Label className="cursor-pointer font-normal" htmlFor="is_free">Free course (no enrollment fee)</Label>
      </div>

      {state?.error && <p className="text-sm text-destructive">{state.error}</p>}

      <div className="flex justify-end gap-3">
        <Button
          disabled={pending}
          type="button"
          variant="outline"
          onClick={() => router.push(ROUTES.manageCourse(course.id))}
        >
          Cancel
        </Button>
        <Button disabled={pending} type="submit">
          {pending ? "Saving…" : "Save changes"}
        </Button>
      </div>
    </form>
  );
}
