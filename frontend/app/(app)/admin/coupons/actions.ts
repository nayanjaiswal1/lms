"use server";

import { revalidatePath } from "next/cache";
import { apiAction, type ActionResult } from "@/lib/server/api";
import type { Coupon } from "@/lib/server/coupons";
import ROUTES from "@/lib/routes";

export interface CreateCouponInput {
  code: string;
  description?: string;
  discount_type: "percent" | "fixed";
  discount_value: number;
  max_discount_cents?: number;
  course_ids?: string[];
  max_redemptions?: number;
  expires_at?: string;
}

export async function createCouponAction(input: CreateCouponInput): Promise<ActionResult<Coupon>> {
  const result = await apiAction<Coupon>("POST", "/api/coupons", input);
  if (result.ok) revalidatePath(ROUTES.ADMIN_COUPONS);
  return result;
}

export interface UpdateCouponInput {
  description: string;
  is_active: boolean;
  expires_at?: string;
  max_redemptions?: number;
  max_discount_cents?: number;
  course_ids: string[];
}

// discount_type/discount_value are deliberately absent — the discount itself
// is never mutated on a coupon that may already have redemptions (see
// coupons.Repo.Update's own comment); only scope/caps/description change.
export async function updateCouponAction(couponId: string, input: UpdateCouponInput): Promise<ActionResult<Coupon>> {
  const result = await apiAction<Coupon>("PATCH", `/api/coupons/${couponId}`, input);
  if (result.ok) revalidatePath(ROUTES.ADMIN_COUPONS);
  return result;
}

export async function deactivateCouponAction(couponId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/coupons/${couponId}`);
  if (result.ok) revalidatePath(ROUTES.ADMIN_COUPONS);
  return result;
}
