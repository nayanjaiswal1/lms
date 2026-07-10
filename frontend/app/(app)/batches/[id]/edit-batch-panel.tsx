"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { Pencil } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { updateBatchAction } from "@/app/(app)/batches/actions";
import { BatchAvatar } from "@/components/batches/batch-avatar";
import type { Batch, OrgMemberSummary } from "@/lib/server/batches";

const NO_MENTOR = "__none__";

// datetime-local inputs work in local time with no timezone suffix; the API
// exchanges UTC ISO strings, so convert at the edges.
function isoToLocalInput(iso: string | null): string {
  if (!iso) return "";
  const d = new Date(iso);
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

function localInputToIso(value: string): string | null {
  if (!value) return null;
  return new Date(value).toISOString();
}

const Schema = z
  .object({
    name: z.string().min(2, "Name is too short."),
    description: z.string().optional(),
    mentor_id: z.string().optional(),
    starts_at: z.string().optional(),
    ends_at: z.string().optional(),
  })
  .refine((v) => !v.starts_at || !v.ends_at || v.ends_at > v.starts_at, {
    message: "End date must be after the start date.",
    path: ["ends_at"],
  });
type FormData = z.infer<typeof Schema>;

interface EditBatchFormProps {
  batch: Batch;
  orgMembers: OrgMemberSummary[];
  onClose: () => void;
}

function EditBatchForm({ batch, orgMembers, onClose }: EditBatchFormProps) {
  const router = useRouter();
  const form = useForm<FormData>({
    resolver: zodResolver(Schema),
    defaultValues: {
      name: batch.name,
      description: batch.description ?? "",
      mentor_id: batch.mentor_id ?? NO_MENTOR,
      starts_at: isoToLocalInput(batch.starts_at),
      ends_at: isoToLocalInput(batch.ends_at),
    },
  });

  const onSubmit = async (data: FormData) => {
    const result = await updateBatchAction(batch.id, {
      name: data.name,
      description: data.description?.trim() ? data.description.trim() : null,
      mentor_id: data.mentor_id && data.mentor_id !== NO_MENTOR ? data.mentor_id : null,
      starts_at: localInputToIso(data.starts_at ?? ""),
      ends_at: localInputToIso(data.ends_at ?? ""),
    });
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Batch updated.");
    onClose();
    router.refresh();
  };

  return (
    <Form {...form}>
      <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
        <div className="flex justify-center">
          <BatchAvatar editable batchId={batch.id} imageUrl={batch.image_url} name={batch.name} size="lg" />
        </div>

        <FormInputField control={form.control} label="Batch name" name="name" />

        <FormField
          control={form.control}
          name="description"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Description</FormLabel>
              <FormControl>
                <Textarea placeholder="Optional…" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <FormField
          control={form.control}
          name="mentor_id"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Mentor</FormLabel>
              <Select value={field.value || NO_MENTOR} onValueChange={field.onChange}>
                <FormControl>
                  <SelectTrigger>
                    <SelectValue placeholder="— None —" />
                  </SelectTrigger>
                </FormControl>
                <SelectContent>
                  <SelectItem value={NO_MENTOR}>— None —</SelectItem>
                  {orgMembers.map((m) => (
                    <SelectItem key={m.user_id} value={m.user_id}>
                      {m.name} ({m.email})
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <FormMessage />
            </FormItem>
          )}
        />

        <div className="grid grid-cols-2 gap-3">
          <FormField
            control={form.control}
            name="starts_at"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Starts</FormLabel>
                <FormControl>
                  <Input type="datetime-local" {...field} />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />
          <FormField
            control={form.control}
            name="ends_at"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Ends</FormLabel>
                <FormControl>
                  <Input type="datetime-local" {...field} />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />
        </div>

        <Button disabled={form.formState.isSubmitting} type="submit">
          {form.formState.isSubmitting ? "Saving…" : "Save changes"}
        </Button>
      </form>
    </Form>
  );
}

interface EditBatchPanelProps {
  batch: Batch;
  orgMembers: OrgMemberSummary[];
}

export function EditBatchPanel({ batch, orgMembers }: EditBatchPanelProps) {
  const [open, setOpen] = React.useState(false);

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button size="sm" variant="outline">
          <Pencil aria-hidden className="mr-1.5 h-4 w-4" />
          Edit batch
        </Button>
      </DialogTrigger>
      <DialogContent className="max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>Edit batch</DialogTitle>
        </DialogHeader>
        <EditBatchForm batch={batch} orgMembers={orgMembers} onClose={() => setOpen(false)} />
      </DialogContent>
    </Dialog>
  );
}
