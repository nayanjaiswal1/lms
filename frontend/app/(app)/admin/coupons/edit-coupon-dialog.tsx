"use client";

import { useState } from "react";
import { parseAsString, useQueryState } from "nuqs";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Form, FormItem, FormLabel } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { MultiSelectDropdown } from "@/components/shared/multi-select-dropdown";
import type { ChecklistOption } from "@/components/shared/checklist-grid";
import type { Coupon } from "@/lib/server/coupons";
import { updateCouponAction } from "./actions";

const Schema = z.object({
  description: z.string().max(255).optional(),
  max_discount_cents: z.coerce.number().int().positive().optional(),
  max_redemptions: z.coerce.number().int().positive().optional(),
});
type FormInput = z.input<typeof Schema>;
type FormData = z.output<typeof Schema>;

interface EditCouponDialogProps {
  coupon: Coupon;
  courseOptions: ChecklistOption[];
}

// Discount type/value are never editable here — see updateCouponAction's own
// comment. is_active and expires_at are passed through unchanged (toggling
// active is the existing standalone Deactivate button's job; expiry has no
// UI surface yet at all, same gap the create dialog already has).
export function EditCouponDialog({ coupon, courseOptions }: EditCouponDialogProps) {
  const [openId, setOpenId] = useQueryState("edit-coupon", parseAsString);
  const isOpen = openId === coupon.id;
  const [courseIDs, setCourseIDs] = useState<Set<string>>(new Set(coupon.course_ids));

  const form = useForm<FormInput, unknown, FormData>({
    resolver: zodResolver(Schema),
    defaultValues: {
      description: coupon.description,
      max_discount_cents: coupon.max_discount_cents,
      max_redemptions: coupon.max_redemptions,
    },
  });

  const onSubmit = async (data: FormData) => {
    const res = await updateCouponAction(coupon.id, {
      description: data.description?.trim() ?? "",
      is_active: coupon.is_active,
      expires_at: coupon.expires_at,
      max_discount_cents: coupon.discount_type === "percent" ? data.max_discount_cents : undefined,
      max_redemptions: data.max_redemptions,
      course_ids: Array.from(courseIDs),
    });
    if (res.error) {
      toast.error(res.error);
      return;
    }
    toast.success("Coupon updated.");
    void setOpenId(null);
  };

  return (
    <Dialog
      open={isOpen}
      onOpenChange={(next) => {
        if (!next) {
          void setOpenId(null);
          return;
        }
        form.reset({
          description: coupon.description,
          max_discount_cents: coupon.max_discount_cents,
          max_redemptions: coupon.max_redemptions,
        });
        setCourseIDs(new Set(coupon.course_ids));
        void setOpenId(coupon.id);
      }}
    >
      <DialogTrigger asChild>
        <Button size="sm" variant="outline">
          Edit
        </Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>Edit {coupon.code}</DialogTitle>
        </DialogHeader>
        <Form {...form}>
          <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
            <FormInputField
              control={form.control}
              label="Description (optional)"
              name="description"
              placeholder="What is this coupon for?"
            />
            {coupon.discount_type === "percent" && (
              <FormInputField
                control={form.control}
                label="Max discount cap in cents (optional)"
                name="max_discount_cents"
                placeholder="e.g. 2000 caps it at $20 off"
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
              {form.formState.isSubmitting ? "Saving…" : "Save Changes"}
            </Button>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
