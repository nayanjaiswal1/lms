import "server-only";

import { apiGet } from "@/lib/server/api";

// Coupon mirrors coupons.Coupon's JSON shape (backend/internal/coupons/handler.go
// couponResponse) — course discount codes, admin-managed.
export interface Coupon {
  id: string;
  code: string;
  description: string;
  discount_type: "percent" | "fixed";
  discount_value: number;
  course_id?: string;
  max_redemptions?: number;
  redeemed_count: number;
  starts_at?: string;
  expires_at?: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export async function getCoupons(includeInactive = true): Promise<Coupon[]> {
  const query = includeInactive ? "?include_inactive=true" : "";
  const body = await apiGet<{ coupons: Coupon[] }>(`/api/coupons${query}`);
  return body.coupons ?? [];
}
