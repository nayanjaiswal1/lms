"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import type { ChecklistOption } from "@/components/shared/checklist-grid";
import type { Coupon } from "@/lib/server/coupons";
import { deactivateCouponAction } from "./actions";
import { EditCouponDialog } from "./edit-coupon-dialog";

function formatDiscount(c: Coupon): string {
  const base = c.discount_type === "percent" ? `${c.discount_value}% off` : `$${(c.discount_value / 100).toFixed(2)} off`;
  if (c.discount_type === "percent" && c.max_discount_cents) {
    return `${base} (up to $${(c.max_discount_cents / 100).toFixed(2)})`;
  }
  return base;
}

function formatRedemptions(c: Coupon): string {
  return c.max_redemptions ? `${c.redeemed_count} / ${c.max_redemptions}` : `${c.redeemed_count} / ∞`;
}

function formatScope(c: Coupon, courseTitleById: Map<string, string>): string {
  if (c.course_ids.length === 0) return "All courses";
  const titles = c.course_ids.map((id) => courseTitleById.get(id) ?? "Unknown course");
  return titles.length <= 2 ? titles.join(", ") : `${titles.slice(0, 2).join(", ")} +${titles.length - 2} more`;
}

interface CouponTableProps {
  coupons: Coupon[];
  courseTitleById: Map<string, string>;
  courseOptions: ChecklistOption[];
}

export function CouponTable({ coupons, courseTitleById, courseOptions }: CouponTableProps) {
  const [pendingId, setPendingId] = useState<string | null>(null);
  const [, startTransition] = useTransition();

  function handleDeactivate(couponId: string) {
    setPendingId(couponId);
    startTransition(async () => {
      const res = await deactivateCouponAction(couponId);
      setPendingId(null);
      if (res.error) {
        toast.error(res.error);
        return;
      }
      toast.success("Coupon deactivated.");
    });
  }

  return (
    <div className="table-responsive">
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b border-border text-left text-muted-foreground">
            <th className="pb-2 pr-6 font-medium">Code</th>
            <th className="pb-2 pr-6 font-medium">Discount</th>
            <th className="pb-2 pr-6 font-medium">Courses</th>
            <th className="pb-2 pr-6 font-medium">Redemptions</th>
            <th className="pb-2 pr-6 font-medium">Status</th>
            <th className="pb-2 font-medium" />
          </tr>
        </thead>
        <tbody>
          {coupons.map((c) => (
            <tr className="whitespace-nowrap border-b border-border last:border-0" key={c.id}>
              <td className="min-w-0 py-3 pr-6">
                <p className="font-mono font-medium">{c.code}</p>
                {c.description && <p className="truncate text-xs text-muted-foreground">{c.description}</p>}
              </td>
              <td className="py-3 pr-6 text-muted-foreground">{formatDiscount(c)}</td>
              <td className="min-w-0 max-w-64 truncate py-3 pr-6 text-muted-foreground">
                {formatScope(c, courseTitleById)}
              </td>
              <td className="py-3 pr-6 text-muted-foreground">{formatRedemptions(c)}</td>
              <td className="py-3 pr-6">
                {c.is_active ? <Badge variant="default">Active</Badge> : <Badge variant="secondary">Inactive</Badge>}
              </td>
              <td className="py-3 text-right">
                <div className="flex justify-end gap-2">
                  <EditCouponDialog coupon={c} courseOptions={courseOptions} />
                  {c.is_active && (
                    <Button
                      disabled={pendingId === c.id}
                      size="sm"
                      variant="outline"
                      onClick={() => handleDeactivate(c.id)}
                    >
                      Deactivate
                    </Button>
                  )}
                </div>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
