"use client";

import { useTransition } from "react";
import { parseAsString, useQueryState } from "nuqs";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";

interface CoursePickerProps {
  options: { label: string; value: string }[];
  /** Fallback when the URL has no ?course= (the recipe's target placement). */
  defaultCourseId: string;
}

/** Course choice for publishing; kept in the URL so the server loads that course's sections. */
export function CoursePicker({ options, defaultCourseId }: CoursePickerProps) {
  const [, startTransition] = useTransition();
  const [course, setCourse] = useQueryState(
    "course",
    parseAsString.withDefault(defaultCourseId).withOptions({ shallow: false, startTransition }),
  );

  return (
    <div className="flex flex-col gap-2">
      <Label htmlFor="publish-course">Course</Label>
      <Select value={course || undefined} onValueChange={(v) => void setCourse(v)}>
        <SelectTrigger className="w-full sm:w-80" id="publish-course">
          <SelectValue placeholder="Choose a course" />
        </SelectTrigger>
        <SelectContent>
          {options.map((o) => (
            <SelectItem key={o.value} value={o.value}>
              {o.label}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </div>
  );
}
