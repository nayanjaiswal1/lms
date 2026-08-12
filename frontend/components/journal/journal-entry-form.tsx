"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { toast } from "sonner";
import { z } from "zod";

import { Button } from "@/components/ui/button";
import { Form } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { FormTextareaField } from "@/components/ui/form-textarea-field";
import ROUTES from "@/lib/routes";
import { createJournalEntryAction, updateJournalEntryAction } from "@/app/(app)/journal/actions";
import type { JournalCategoryNode, JournalEntry } from "@/lib/server/journal";

const Schema = z.object({
  entry_date: z.string().optional(),
  category: z.string().trim().min(1, "Required").max(60, "Must not exceed 60 characters"),
  subcategory: z.string().trim().min(1, "Required").max(60, "Must not exceed 60 characters"),
  title: z.string().trim().min(1, "Required").max(200, "Must not exceed 200 characters"),
  content: z.string().trim().min(1, "Required").max(20000, "Must not exceed 20,000 characters"),
});
type FormValues = z.infer<typeof Schema>;

// Local (not UTC) so the default doesn't roll over a day early/late near
// midnight — matches the "2006-01-02" format the backend's entry_date expects.
function todayLocalISODate(): string {
  const d = new Date();
  const month = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${d.getFullYear()}-${month}-${day}`;
}

interface JournalEntryFormProps {
  entry?: JournalEntry;
  categories: JournalCategoryNode[];
  // Prefill for a new entry that didn't come from an existing saved row —
  // e.g. an AI-structured suggestion from a pasted note. Ignored when entry
  // is set (editing always wins).
  draft?: Partial<Pick<FormValues, "category" | "subcategory" | "title" | "content">>;
  // Called instead of navigating to the journal list on save — lets a
  // dialog-hosted usage (paste-to-structure) close itself in place.
  onSaved?: () => void;
}

export function JournalEntryForm({ entry, categories, draft, onSaved }: JournalEntryFormProps) {
  const router = useRouter();
  const form = useForm<FormValues>({
    resolver: zodResolver(Schema),
    defaultValues: {
      entry_date: entry?.entry_date ?? todayLocalISODate(),
      category: entry?.category ?? draft?.category ?? "",
      subcategory: entry?.subcategory ?? draft?.subcategory ?? "",
      title: entry?.title ?? draft?.title ?? "",
      content: entry?.content ?? draft?.content ?? "",
    },
  });
  const selectedCategory = form.watch("category");
  const subcategoryOptions =
    categories.find((c) => c.category.toLowerCase() === selectedCategory.trim().toLowerCase())?.subcategories ?? [];

  async function onSubmit(data: FormValues) {
    if (entry) {
      const result = await updateJournalEntryAction(entry.id, data);
      if (!result.ok) {
        toast.error(result.error ?? "Couldn't save this entry.");
        return;
      }
      toast.success("Entry updated.");
    } else {
      const result = await createJournalEntryAction(data);
      if (!result.ok) {
        toast.error(result.error ?? "Couldn't save this entry.");
        return;
      }
      const similar = result.data?.similar_entries[0];
      if (similar) toast.info(`You've written about this before: ${similar.entry_date} · ${similar.title}`);
      toast.success("Entry added.");
    }
    if (onSaved) onSaved();
    else router.push(ROUTES.JOURNAL);
  }

  return (
    <Form {...form}>
      <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
        <FormInputField control={form.control} label="Title" name="title" placeholder="e.g. Modal Verbs (Can/Could)" />
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div className="flex flex-col gap-1.5">
            <FormInputField control={form.control} label="Category" list="journal-categories" name="category" placeholder="e.g. Backend" />
            <datalist id="journal-categories">
              {categories.map((c) => (
                <option key={c.category} value={c.category} />
              ))}
            </datalist>
          </div>
          <div className="flex flex-col gap-1.5">
            <FormInputField
              control={form.control}
              label="Subcategory"
              list="journal-subcategories"
              name="subcategory"
              placeholder="e.g. Redis"
            />
            <datalist id="journal-subcategories">
              {subcategoryOptions.map((s) => (
                <option key={s} value={s} />
              ))}
            </datalist>
          </div>
        </div>
        <FormInputField control={form.control} label="Date" name="entry_date" type="date" />
        <FormTextareaField control={form.control} label="What did you learn?" name="content" rows={8} />
        <div className="flex justify-end gap-2">
          <Button disabled={form.formState.isSubmitting} type="submit">
            {form.formState.isSubmitting ? "Saving…" : entry ? "Save changes" : "Add Learning"}
          </Button>
        </div>
      </form>
    </Form>
  );
}
