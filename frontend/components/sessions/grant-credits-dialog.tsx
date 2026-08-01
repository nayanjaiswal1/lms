"use client";

import { parseAsBoolean, useQueryState } from "nuqs";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Form } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { grantSessionCreditsAction } from "@/lib/server/sessions";

const Schema = z.object({
  user_id: z.string().min(1, "Enter a user ID or email."),
  delta: z.coerce
    .number()
    .int()
    .refine((v) => v !== 0, "Delta can't be zero.")
    .refine((v) => v >= -1000 && v <= 1000, "Delta must be between -1000 and 1000."),
  note: z.string().max(500).optional(),
});
type FormInput = z.input<typeof Schema>;
type FormData = z.output<typeof Schema>;

/** Admin-only: directly adjust a specific student's credit balance — support cases, manual corrections. */
export function GrantCreditsDialog() {
  const [open, setOpen] = useQueryState("grant-credits", parseAsBoolean.withDefault(false));
  const form = useForm<FormInput, unknown, FormData>({
    resolver: zodResolver(Schema),
    defaultValues: { user_id: "", delta: 1, note: "" },
  });

  const onSubmit = async (data: FormData) => {
    const res = await grantSessionCreditsAction(data.user_id.trim(), data.delta, data.note?.trim() ?? "");
    if (res.error) {
      toast.error(res.error);
      return;
    }
    toast.success(
      res.data ? `Balance updated — new balance: ${res.data.balance}.` : "Balance updated.",
    );
    form.reset({ user_id: "", delta: 1, note: "" });
    void setOpen(false);
  };

  return (
    <Dialog open={open} onOpenChange={(next) => void setOpen(next || null)}>
      <DialogTrigger asChild>
        <Button size="sm" variant="outline">
          Grant / revoke credits
        </Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>Grant or revoke credits</DialogTitle>
        </DialogHeader>
        <Form {...form}>
          <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
            <FormInputField
              control={form.control}
              label="User ID or email"
              name="user_id"
              placeholder="user@example.com"
            />
            <FormInputField
              control={form.control}
              description="Positive grants credits, negative revokes them. Never zero."
              label="Delta"
              name="delta"
              type="number"
            />
            <FormInputField
              control={form.control}
              label="Note (optional)"
              name="note"
              placeholder="Why this adjustment?"
            />
            <Button disabled={form.formState.isSubmitting} type="submit">
              {form.formState.isSubmitting ? "Saving…" : "Apply"}
            </Button>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
