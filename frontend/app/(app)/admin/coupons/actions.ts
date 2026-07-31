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
  course_id?: string;
  max_redemptions?: number;
  expires_at?: string;
}

export async function createCouponAction(input: CreateCouponInput): Promise<ActionResult<Coupon>> {
  const result = await apiAction<Coupon>("POST", "/api/coupons", input);
  if (result.ok) revalidatePath(ROUTES.ADMIN_COUPONS);
  return result;
}

export async function deactivateCouponAction(couponId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/coupons/${couponId}`);
  if (result.ok) revalidatePath(ROUTES.ADMIN_COUPONS);
  return result;
}
