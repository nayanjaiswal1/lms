"use client";

import { useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { PlusCircle } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { FormSelectField } from "@/components/ui/form-select-field";
import { FormTextareaField } from "@/components/ui/form-textarea-field";
import { Input } from "@/components/ui/input";
import { DuplicateCheckPanel } from "@/components/workspace/items/duplicate-check-panel";
import { ItemSearchPicker } from "@/components/workspace/items/item-search-picker";
import { createWorkItemAction, listSimilarItemsAction } from "@/lib/workspace/items-actions";
import { ITEM_TYPE_LABEL, PARENT_REQUIRED, PARENT_TYPE_OPTIONS } from "@/lib/workspace/items-constants";
import type { BugSeverity, ItemType, SimilarItem, Track, WorkItem } from "@/lib/workspace/types";
import ROUTES from "@/lib/routes";

const DEBOUNCE_MS = 400;
const MIN_TITLE_LENGTH = 5;

const Schema = z.object({
  type: z.enum(["epic", "feature", "task", "bug", "subtask"]),
  title: z.string().min(3, "At least 3 characters.").max(200),
  description: z.string().max(20000).optional(),
  priority: z.enum(["low", "medium", "high", "urgent"]),
  severity: z.enum(["S1", "S2", "S3", "S4"]).optional(),
  track_id: z.string().optional(),
});
type FormData = z.infer<typeof Schema>;

const PRIORITY_OPTIONS = [
  { label: "Low", value: "low" },
  { label: "Medium", value: "medium" },
  { label: "High", value: "high" },
  { label: "Urgent", value: "urgent" },
];

const SEVERITY_OPTIONS = [
  { label: "S1 — Critical", value: "S1" },
  { label: "S2 — Major", value: "S2" },
  { label: "S3 — Minor", value: "S3" },
  { label: "S4 — Trivial", value: "S4" },
];

interface CreateItemDialogProps {
  workspaceId: string;
  /** Role-gated by the caller (epic/feature: manager+ or track lead; task/bug/subtask: member+). */
  allowedTypes: ItemType[];
  tracks: Track[];
  /** Set when opened as "Add child" from an existing item — locks the parent and hides the picker. */
  defaultParentId?: string;
  triggerLabel?: string;
  /** Pre-fills title/description/type — an AI suggestion's own "Create" button
   * (contract-phase5.md: "Create per suggestion going through the normal
   * create path"), never auto-submitted, the human still confirms. */
  defaultTitle?: string;
  defaultDescription?: string;
  defaultType?: ItemType;
}

export function CreateItemDialog({
  workspaceId, allowedTypes, tracks, defaultParentId, triggerLabel, defaultTitle, defaultDescription, defaultType,
}: CreateItemDialogProps) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [parent, setParent] = useState<WorkItem | null>(null);
  const [similar, setSimilar] = useState<SimilarItem[]>([]);
  const [searching, startSearch] = useTransition();
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const form = useForm<FormData>({
    resolver: zodResolver(Schema),
    defaultValues: {
      type: defaultType ?? allowedTypes[0] ?? "task",
      title: defaultTitle ?? "",
      description: defaultDescription ?? "",
      priority: "medium",
    },
  });
  const type = form.watch("type");
  const parentTypes = PARENT_TYPE_OPTIONS[type];
  const parentRequired = PARENT_REQUIRED[type] && !defaultParentId;
  const showParentPicker = !defaultParentId && parentTypes.length > 0;

  function checkSimilar(title: string) {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    if (title.trim().length < MIN_TITLE_LENGTH) {
      setSimilar([]);
      return;
    }
    debounceRef.current = setTimeout(() => {
      startSearch(async () => {
        const result = await listSimilarItemsAction(workspaceId, title.trim());
        setSimilar(result.ok ? (result.data ?? []) : []);
      });
    }, DEBOUNCE_MS);
  }

  async function onSubmit(data: FormData) {
    if (parentRequired && !parent) {
      toast.error(`A ${ITEM_TYPE_LABEL[type].toLowerCase()} needs a parent ${parentTypes.map((t) => ITEM_TYPE_LABEL[t]).join(" or ")}.`);
      return;
    }
    const result = await createWorkItemAction(workspaceId, {
      type: data.type,
      parent_id: defaultParentId ?? parent?.id ?? null,
      track_id: data.track_id || null,
      title: data.title,
      description: data.description || null,
      priority: data.priority,
      severity: data.type === "bug" ? (data.severity as BugSeverity | undefined) : undefined,
    });
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(`${result.data?.item.key} created.`);
    setOpen(false);
    form.reset({ type: allowedTypes[0] ?? "task", title: "", description: "", priority: "medium" });
    setParent(null);
    setSimilar([]);
    if (result.data) router.push(ROUTES.workspaceItem(workspaceId, result.data.item.key));
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button className="gap-2">
          <PlusCircle aria-hidden className="h-4 w-4" />
          {triggerLabel ?? "New item"}
        </Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>{triggerLabel ?? "New item"}</DialogTitle>
          <DialogDescription>Similar open items are surfaced as you type so you don&apos;t create a duplicate.</DialogDescription>
        </DialogHeader>
        <Form {...form}>
          <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
            {allowedTypes.length > 1 && (
              <FormSelectField
                control={form.control}
                label="Type"
                name="type"
                options={allowedTypes.map((t) => ({ label: ITEM_TYPE_LABEL[t], value: t }))}
              />
            )}

            <FormField
              control={form.control}
              name="title"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Title</FormLabel>
                  <FormControl>
                    <Input
                      {...field}
                      placeholder="Short, specific summary"
                      onChange={(e) => { field.onChange(e); checkSimilar(e.target.value); }}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <DuplicateCheckPanel searching={searching} similar={similar} workspaceId={workspaceId} />

            {showParentPicker && (
              <div className="flex flex-col gap-1.5">
                <label className="text-sm font-medium">
                  Parent {parentRequired ? "" : "(optional)"}
                </label>
                <ItemSearchPicker
                  filterTypes={parentTypes}
                  placeholder={`Search ${parentTypes.map((t) => ITEM_TYPE_LABEL[t]).join(" / ")}…`}
                  value={parent}
                  workspaceId={workspaceId}
                  onChange={setParent}
                />
              </div>
            )}

            <FormTextareaField control={form.control} label="Description (optional)" name="description" rows={4} />
            <FormSelectField control={form.control} label="Priority" name="priority" options={PRIORITY_OPTIONS} />
            {type === "bug" && (
              <FormSelectField control={form.control} label="Severity" name="severity" options={SEVERITY_OPTIONS} placeholder="Select severity" />
            )}
            {tracks.length > 0 && (
              <FormSelectField
                control={form.control}
                label="Track (optional)"
                name="track_id"
                options={tracks.map((t) => ({ label: t.name, value: t.id }))}
                placeholder="Inherit from parent"
              />
            )}

            <DialogFooter>
              <Button disabled={form.formState.isSubmitting} type="submit">
                {form.formState.isSubmitting ? "Creating…" : "Create"}
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
