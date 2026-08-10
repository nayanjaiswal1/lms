"use client";

import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { createCohortGroupAction, updateCohortGroupAction } from "@/app/(app)/cohort-groups/actions";
import type { CohortGroup } from "@/lib/server/cohorts";

const NO_PARENT = "__none__";

// Walks the flat group list to collect groupId itself plus every descendant,
// via each group's parent_id — the same relationship the picker already
// renders, so no extra fetch is needed to know the shape of the subtree.
function descendantIds(groups: CohortGroup[], groupId: string): Set<string> {
  const ids = new Set([groupId]);
  let grew = true;
  while (grew) {
    grew = false;
    for (const g of groups) {
      if (g.parent_id && ids.has(g.parent_id) && !ids.has(g.id)) {
        ids.add(g.id);
        grew = true;
      }
    }
  }
  return ids;
}

const Schema = z.object({
  name: z.string().min(2, "Name is too short."),
  level_label: z.string().optional(),
  parent_id: z.string().optional(),
});
type FormData = z.infer<typeof Schema>;

interface CreateCohortGroupFormProps {
  groups: CohortGroup[];
  presetParentId?: string;
  onCreated: () => void;
  /** When set, the form edits this group in place instead of creating a new one. */
  editingGroup?: CohortGroup;
}

export function CreateCohortGroupForm({ groups, presetParentId, onCreated, editingGroup }: CreateCohortGroupFormProps) {
  const router = useRouter();
  const form = useForm<FormData>({
    resolver: zodResolver(Schema),
    defaultValues: {
      name: editingGroup?.name ?? "",
      level_label: editingGroup?.level_label ?? "",
      parent_id: editingGroup?.parent_id ?? presetParentId ?? NO_PARENT,
    },
  });
  // Excludes the group itself and its whole descendant subtree — picking any
  // of those as the new parent would create a cycle. No dedicated "list
  // descendants" endpoint exists for cohort groups (only an internal
  // ancestor/candidate cycle check used by the update route itself), but the
  // full flat list already carries every group's parent_id, so the subtree
  // is walked client-side from data already on hand rather than adding a
  // backend route for it.
  const excludedIds = editingGroup ? descendantIds(groups, editingGroup.id) : new Set<string>();
  const parentOptions = groups.filter((g) => !excludedIds.has(g.id));

  const onSubmit = async (data: FormData) => {
    const input = {
      name: data.name,
      level_label: data.level_label?.trim() ? data.level_label.trim() : null,
      parent_id: data.parent_id && data.parent_id !== NO_PARENT ? data.parent_id : null,
    };
    const res = editingGroup
      ? await updateCohortGroupAction(editingGroup.id, input)
      : await createCohortGroupAction(input);
    if (res.error) {
      toast.error(res.error);
      return;
    }
    toast.success(editingGroup ? "Group updated." : "Group created.");
    form.reset();
    onCreated();
    router.refresh();
  };

  return (
    <Form {...form}>
      <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
        <FormInputField control={form.control} label="Name" name="name" placeholder="Class 10" />
        <FormInputField
          control={form.control}
          description="Free text — e.g. Class, Section, Program. Shown as a hint only."
          label="Level label (optional)"
          name="level_label"
          placeholder="Class"
        />
        <FormField
          control={form.control}
          name="parent_id"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Parent group</FormLabel>
              <Select value={field.value || NO_PARENT} onValueChange={field.onChange}>
                <FormControl>
                  <SelectTrigger>
                    <SelectValue placeholder="— Top level —" />
                  </SelectTrigger>
                </FormControl>
                <SelectContent>
                  <SelectItem value={NO_PARENT}>— Top level —</SelectItem>
                  {parentOptions.map((g) => (
                    <SelectItem key={g.id} value={g.id}>
                      {g.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <FormMessage />
            </FormItem>
          )}
        />
        <Button disabled={form.formState.isSubmitting} type="submit">
          {form.formState.isSubmitting ? "Saving…" : editingGroup ? "Save changes" : "Create group"}
        </Button>
      </form>
    </Form>
  );
}
