import { notFound } from "next/navigation";
import { getMyPermissions } from "@/lib/server/permissions";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import { getCoupons } from "@/lib/server/coupons";
import { CreateCouponDialog } from "./create-coupon-dialog";
import { CouponTable } from "./coupon-table";

export default async function CouponsPage() {
  const myPerms = await getMyPermissions();
  if (!myPerms.includes(PERMISSIONS.PAYMENTS.MANAGE_COUPONS)) {
    notFound();
  }

  const coupons = await getCoupons();

  return (
    <div className="page-container">
      <div className="page-header">
        <div>
          <h1 className="page-title">Coupons</h1>
          <p className="mt-1 text-muted-foreground">
            Percent or fixed-amount discount codes for paid courses.
          </p>
        </div>
        <CreateCouponDialog />
      </div>

      {coupons.length === 0 ? (
        <div className="empty-state mt-8">
          <p className="text-muted-foreground">No coupons yet.</p>
        </div>
      ) : (
        <div className="mt-6">
          <CouponTable coupons={coupons} />
        </div>
      )}
    </div>
  );
}
