"use client";

import * as React from "react";
import { Plus, X, Search, BookOpen } from "lucide-react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { assignCourseAction } from "@/lib/batches/actions";

interface CourseOption {
  id: string;
  title: string;
  slug: string;
  difficulty: string;
}

interface AssignCourseFormProps {
  batchId: string;
  courses: CourseOption[];
  assignedCourseIds: string[];
  onClose: () => void;
}

function AssignCourseForm({ batchId, courses, assignedCourseIds, onClose }: AssignCourseFormProps) {
  const [query, setQuery] = React.useState("");
  const [submitting, setSubmitting] = React.useState(false);
  const router = useRouter();

  const assignedSet = new Set(assignedCourseIds);
  const eligible = courses.filter((c) => !assignedSet.has(c.id));
  const filtered = query.trim()
    ? eligible.filter((c) => c.title.toLowerCase().includes(query.toLowerCase()))
    : eligible;

  async function assign(courseId: string, title: string) {
    setSubmitting(true);
    const result = await assignCourseAction(batchId, courseId);
    setSubmitting(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(`${title} assigned to batch.`);
    onClose();
    router.refresh();
  }

  return (
    <div className="card-raised flex w-full flex-col gap-4 p-6">
      <div className="flex items-center justify-between">
        <h2 className="subsection-title">Assign course</h2>
        <Button aria-label="Close assign course panel" size="icon" variant="ghost" onClick={onClose}>
          <X aria-hidden className="h-4 w-4" />
        </Button>
      </div>

      <div className="relative">
        <Search aria-hidden className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground pointer-events-none" />
        <Input
          aria-label="Search courses by title"
          className="pl-9"
          placeholder="Search by title…"
          type="search"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
      </div>

      {eligible.length === 0 ? (
        <p className="text-sm text-muted-foreground">All courses are already assigned to this batch.</p>
      ) : filtered.length === 0 ? (
        <p className="text-sm text-muted-foreground">No courses match your search.</p>
      ) : (
        <ul
          aria-label="Courses available to assign"
          className="max-h-64 overflow-y-auto divide-y divide-border rounded-md border border-border"
          role="listbox"
        >
          {filtered.map((c) => (
            <li aria-selected={false} className="flex items-center gap-3 px-3 py-2.5 text-sm" key={c.id} role="option">
              <span className="flex flex-1 flex-col gap-0.5 min-w-0">
                <span className="font-medium truncate">{c.title}</span>
                <span className="text-xs capitalize text-muted-foreground">{c.difficulty}</span>
              </span>
              <Button disabled={submitting} size="sm" variant="outline" onClick={() => assign(c.id, c.title)}>
                <Plus aria-hidden className="mr-1 h-3.5 w-3.5" />
                Assign
              </Button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

interface AssignCoursePanelProps {
  batchId: string;
  courses: CourseOption[];
  assignedCourseIds: string[];
}

export function AssignCoursePanel({ batchId, courses, assignedCourseIds }: AssignCoursePanelProps) {
  const [open, setOpen] = React.useState(false);

  if (!open) {
    return (
      <Button size="sm" onClick={() => setOpen(true)}>
        <BookOpen aria-hidden className="mr-1.5 h-4 w-4" />
        Assign course
      </Button>
    );
  }

  return (
    <AssignCourseForm
      assignedCourseIds={assignedCourseIds}
      batchId={batchId}
      courses={courses}
      onClose={() => setOpen(false)}
    />
  );
}
