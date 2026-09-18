"use client";

import { parseAsString, useQueryState } from "nuqs";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Form } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { FormSelectField } from "@/components/ui/form-select-field";
import { FormSwitchField } from "@/components/ui/form-switch-field";
import { FormTextareaField } from "@/components/ui/form-textarea-field";
import { WHATS_NEW_ICON_OPTIONS } from "@/lib/constants";
import type { WhatsNewEntry } from "@/lib/whats-new";
import { createWhatsNewEntryAction, updateWhatsNewEntryAction } from "./actions";

const Schema = z.object({
  title: z.string().trim().min(1, "Required").max(120),
  description: z.string().trim().min(1, "Required").max(500),
  icon: z.string().min(1, "Required"),
  cta_label: z.string().trim().min(1, "Required").max(40),
  cta_href: z.string().trim().min(1, "Required"),
  published: z.boolean(),
});
type FormData = z.infer<typeof Schema>;

const EMPTY_VALUES: FormData = {
  title: "",
  description: "",
  icon: "sparkles",
  cta_label: "",
  cta_href: "",
  published: true,
};

function toFormValues(entry: WhatsNewEntry): FormData {
  return {
    title: entry.title,
    description: entry.description,
    icon: entry.icon,
    cta_label: entry.cta_label,
    cta_href: entry.cta_href,
    published: entry.published,
  };
}

interface EntryFormDialogProps {
  // Omit for the "New entry" trigger; pass the row to edit in place.
  entry?: WhatsNewEntry;
}

// One dialog handles both create and edit — the only difference is which
// action fires and what the form starts prefilled with. Open state lives in
// the URL (?entry=new or ?entry=<id>), mirroring EditPricingTierDialog.
export function EntryFormDialog({ entry }: EntryFormDialogProps) {
  const openKey = entry?.id ?? "new";
  const [openId, setOpenId] = useQueryState("entry", parseAsString);
  const isOpen = openId === openKey;

  const form = useForm<FormData>({
    resolver: zodResolver(Schema),
    defaultValues: entry ? toFormValues(entry) : EMPTY_VALUES,
  });

  const onSubmit = async (data: FormData) => {
    const result = entry
      ? await updateWhatsNewEntryAction(entry.id, data)
      : await createWhatsNewEntryAction(data);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(entry ? "Entry updated." : "Entry created.");
    void setOpenId(null);
    if (!entry) form.reset(EMPTY_VALUES);
  };

  return (
    <Dialog
      open={isOpen}
      onOpenChange={(next) => {
        if (!next) {
          void setOpenId(null);
          return;
        }
        form.reset(entry ? toFormValues(entry) : EMPTY_VALUES);
        void setOpenId(openKey);
      }}
    >
      <DialogTrigger asChild>
        <Button size={entry ? "sm" : "default"} variant={entry ? "outline" : "default"}>
          {entry ? "Edit" : "New entry"}
        </Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>{entry ? `Edit "${entry.title}"` : "New entry"}</DialogTitle>
        </DialogHeader>
        <Form {...form}>
          <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
            <FormInputField control={form.control} label="Title" name="title" placeholder="Diary now tracks its own tasks" />
            <FormTextareaField control={form.control} label="Description" name="description" rows={3} />
            <FormSelectField control={form.control} label="Icon" name="icon" options={WHATS_NEW_ICON_OPTIONS} />
            <div className="stack-sm">
              <FormInputField control={form.control} label="CTA label" name="cta_label" placeholder="Open diary" />
              <FormInputField control={form.control} label="CTA link" name="cta_href" placeholder="/diary" />
            </div>
            <FormSwitchField
              control={form.control}
              description="Off keeps this as a draft — hidden from the sidebar panel until switched on."
              label="Published"
              name="published"
            />

            <Button disabled={form.formState.isSubmitting} type="submit">
              {form.formState.isSubmitting ? "Saving…" : "Save"}
            </Button>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
