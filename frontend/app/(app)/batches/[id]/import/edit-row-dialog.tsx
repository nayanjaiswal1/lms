"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Form } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import type { ImportMemberRow } from "@/lib/server/batches";

const Schema = z.object({
  full_name: z.string().min(1, "Full name is required."),
  email: z.string().email("Enter a valid email address."),
  roll_number: z.string().optional(),
  phone_number: z.string().optional(),
  department: z.string().optional(),
});
type FormData = z.infer<typeof Schema>;

interface EditRowDialogProps {
  row: ImportMemberRow;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSave: (row: ImportMemberRow) => void;
}

export function EditRowDialog({ row, open, onOpenChange, onSave }: EditRowDialogProps) {
  const form = useForm<FormData>({
    resolver: zodResolver(Schema),
    values: {
      full_name: row.full_name,
      email: row.email,
      roll_number: row.roll_number ?? "",
      phone_number: row.phone_number ?? "",
      department: row.department ?? "",
    },
  });

  function onSubmit(data: FormData) {
    onSave({
      ...row,
      full_name: data.full_name,
      email: data.email.toLowerCase().trim(),
      roll_number: data.roll_number?.trim() || undefined,
      phone_number: data.phone_number?.trim() || undefined,
      department: data.department?.trim() || undefined,
    });
    onOpenChange(false);
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>Edit student</DialogTitle>
        </DialogHeader>
        <Form {...form}>
          <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
            <FormInputField control={form.control} label="Full name" name="full_name" />
            <FormInputField control={form.control} label="Email" name="email" type="email" />
            <FormInputField control={form.control} label="Roll number" name="roll_number" />
            <FormInputField control={form.control} label="Phone number" name="phone_number" />
            <FormInputField control={form.control} label="Department" name="department" />

            <div className="flex justify-end gap-2">
              <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
                Cancel
              </Button>
              <Button disabled={form.formState.isSubmitting} type="submit">
                Save
              </Button>
            </div>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
