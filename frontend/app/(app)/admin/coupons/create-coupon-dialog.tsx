"use client";

import { useState } from "react";
import { useQueryState, parseAsBoolean } from "nuqs";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { MultiSelectDropdown } from "@/components/shared/multi-select-dropdown";
import type { ChecklistOption } from "@/components/shared/checklist-grid";
import { useCurrency, useMoney } from "@/lib/currency-context";
import { createCouponAction } from "./actions";

const Schema = z.object({
  code: z.string().min(3, "Code must be at least 3 characters.").max(32),
  description: z.string().max(255).optional(),
  discount_type: z.enum(["percent", "fixed"]),
  discount_value: z.coerce.number().int().positive("Must be a positive number."),
  max_discount_cents: z.coerce.number().int().positive().optional(),
  max_redemptions: z.coerce.number().int().positive().optional(),
});
type FormInput = z.input<typeof Schema>;
type FormData = z.output<typeof Schema>;

interface CreateCouponDialogProps {
  courseOptions: ChecklistOption[];
}

// Expiry is left to a direct API call for now — course scope, discount
// value/cap, and redemption cap cover the common case; add a starts_at/
// expires_at field pair here if a time-boxed coupon becomes a real need.
export function CreateCouponDialog({ courseOptions }: CreateCouponDialogProps) {
  const [open, setOpen] = useQueryState("modal", parseAsBoolean.withDefault(false));
  const [courseIDs, setCourseIDs] = useState<Set<string>>(new Set());
  // Amounts are stored in the deployment currency's smallest unit, so both the
  // label and the worked example have to follow PAYMENTS_CURRENCY rather than
  // assume dollars and cents.
  const currency = useCurrency();
  const money = useMoney();
  const form = useForm<FormInput, unknown, FormData>({
    resolver: zodResolver(Schema),
    defaultValues: { code: "", description: "", discount_type: "percent", discount_value: 10 },
  });

  const onSubmit = async (data: FormData) => {
    const res = await createCouponAction({
      code: data.code.trim(),
      description: data.description?.trim(),
      discount_type: data.discount_type,
      discount_value: data.discount_value,
      max_discount_cents: data.discount_type === "percent" ? data.max_discount_cents : undefined,
      course_ids: Array.from(courseIDs),
      max_redemptions: data.max_redemptions,
    });
    if (res.error) {
      toast.error(res.error);
      return;
    }
    toast.success("Coupon created.");
    form.reset();
    setCourseIDs(new Set());
    void setOpen(false);
  };

  const discountType = form.watch("discount_type");

  return (
    <Dialog open={open} onOpenChange={(next) => void setOpen(next || null)}>
      <DialogTrigger asChild>
        <Button>New Coupon</Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>New Coupon</DialogTitle>
        </DialogHeader>
        <Form {...form}>
          <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
            <FormInputField
              control={form.control}
              label="Code"
              name="code"
              placeholder="e.g. LAUNCH25"
            />
            <FormInputField
              control={form.control}
              label="Description (optional)"
              name="description"
              placeholder="What is this coupon for?"
            />
            <FormField
              control={form.control}
              name="discount_type"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Discount type</FormLabel>
                  <Select value={field.value} onValueChange={field.onChange}>
                    <FormControl>
                      <SelectTrigger aria-label="Discount type">
                        <SelectValue />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      <SelectItem value="percent">Percent off</SelectItem>
                      <SelectItem value="fixed">Fixed amount off</SelectItem>
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              )}
            />
            <FormInputField
              control={form.control}
              label={discountType === "percent" ? "Discount (%)" : `Discount (smallest ${currency} unit)`}
              name="discount_value"
              type="number"
            />
            {discountType === "percent" && (
              <FormInputField
                control={form.control}
                label={`Max discount cap (smallest ${currency} unit, optional)`}
                name="max_discount_cents"
                placeholder={`e.g. 2000 caps it at ${money(2000)} off, however large the % is`}
                type="number"
              />
            )}
            <FormInputField
              control={form.control}
              label="Max redemptions (optional)"
              name="max_redemptions"
              placeholder="Leave blank for unlimited"
              type="number"
            />
            <FormItem>
              <FormLabel>Courses (optional)</FormLabel>
              <MultiSelectDropdown
                options={courseOptions}
                placeholder={courseOptions.length ? "Search courses…" : "No paid courses yet"}
                selected={courseIDs}
                onToggle={(id) =>
                  setCourseIDs((prev) => {
                    const next = new Set(prev);
                    if (next.has(id)) next.delete(id);
                    else next.add(id);
                    return next;
                  })
                }
              />
              <p className="text-xs text-muted-foreground">Leave empty to apply to any paid course in the org.</p>
            </FormItem>
            <Button disabled={form.formState.isSubmitting} type="submit">
              {form.formState.isSubmitting ? "Creating…" : "Create Coupon"}
            </Button>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
