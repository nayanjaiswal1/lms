"use client";

import { useState } from "react";
import { ArrowDown, ArrowUp, Plus, X } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import type { PickableCourse } from "@/lib/server/bundles";

interface BundleCoursePickerProps {
  value: string[];
  onChange: (courseIDs: string[]) => void;
  courses: PickableCourse[];
}

// Ordered course list for a bundle: pick to add, arrows to reorder, X to remove.
export function BundleCoursePicker({ value, onChange, courses }: BundleCoursePickerProps) {
  const [toAdd, setToAdd] = useState("");
  const byID = new Map(courses.map((c) => [c.id, c]));
  const addable = courses.filter((c) => !value.includes(c.id));

  function move(index: number, delta: number) {
    const next = [...value];
    [next[index], next[index + delta]] = [next[index + delta], next[index]];
    onChange(next);
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-col gap-2 sm:flex-row">
        <Select value={toAdd} onValueChange={setToAdd}>
          <SelectTrigger aria-label="Course to add" className="w-full sm:flex-1">
            <SelectValue placeholder={addable.length ? "Pick a course to add" : "No more courses to add"} />
          </SelectTrigger>
          <SelectContent>
            {addable.map((c) => (
              <SelectItem key={c.id} value={c.id}>
                {c.status === "published" ? c.title : `${c.title} (${c.status})`}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <Button
          className="touch-target"
          disabled={!toAdd}
          type="button"
          variant="outline"
          onClick={() => {
            onChange([...value, toAdd]);
            setToAdd("");
          }}
        >
          <Plus aria-hidden className="mr-2 h-4 w-4" />
          Add
        </Button>
      </div>

      {value.length === 0 ? (
        <p className="text-sm text-muted-foreground">No courses yet. Add at least one.</p>
      ) : (
        <ol className="flex flex-col divide-y divide-border rounded-lg border border-border">
          {value.map((id, i) => {
            const course = byID.get(id);
            const title = course?.title ?? "Unavailable course";
            return (
              <li className="flex items-center gap-2 px-3 py-2" key={id}>
                <span className="w-6 shrink-0 text-sm text-muted-foreground">{i + 1}</span>
                <span className="min-w-0 flex-1 truncate text-sm">{title}</span>
                {course && course.status !== "published" && (
                  <Badge className="capitalize" variant="outline">{course.status}</Badge>
                )}
                <Button aria-label={`Move ${title} up`} className="touch-target" disabled={i === 0} size="icon" type="button" variant="ghost" onClick={() => move(i, -1)}>
                  <ArrowUp aria-hidden className="h-4 w-4" />
                </Button>
                <Button
                  aria-label={`Move ${title} down`}
                  className="touch-target"
                  disabled={i === value.length - 1}
                  size="icon"
                  type="button"
                  variant="ghost"
                  onClick={() => move(i, 1)}
                >
                  <ArrowDown aria-hidden className="h-4 w-4" />
                </Button>
                <Button
                  aria-label={`Remove ${title}`}
                  className="touch-target"
                  size="icon"
                  type="button"
                  variant="ghost"
                  onClick={() => onChange(value.filter((x) => x !== id))}
                >
                  <X aria-hidden className="h-4 w-4" />
                </Button>
              </li>
            );
          })}
        </ol>
      )}
      <p className="text-xs text-muted-foreground">
        Students only see published courses. Drafts stay hidden until they are published.
      </p>
    </div>
  );
}
