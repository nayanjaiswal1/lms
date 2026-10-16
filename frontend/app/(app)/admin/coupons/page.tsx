import { notFound } from "next/navigation";
import { getMyPermissions } from "@/lib/server/permissions";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import { getCoupons } from "@/lib/server/coupons";
import { getCourses } from "@/lib/server/courses";
import { CreateCouponDialog } from "./create-coupon-dialog";
import { CouponTable } from "./coupon-table";
import { PageHeader } from "@/components/shared/page-header";

export default async function CouponsPage() {
  const myPerms = await getMyPermissions();
  if (!myPerms.includes(PERMISSIONS.PAYMENTS.MANAGE_COUPONS)) {
    notFound();
  }

  const [coupons, courses] = await Promise.all([getCoupons(), getCourses()]);
  const paidCourses = courses.filter((c) => !c.is_free);
  const courseOptions = paidCourses.map((c) => ({ id: c.id, label: c.title }));
  const courseTitleById = new Map(paidCourses.map((c) => [c.id, c.title]));

  return (
    <div className="page-container">
      <PageHeader title="Coupons" description="Percent or fixed-amount discount codes for paid courses.">
        <CreateCouponDialog courseOptions={courseOptions} />
      </PageHeader>

      {coupons.length === 0 ? (
        <div className="empty-state mt-8">
          <p className="text-muted-foreground">No coupons yet.</p>
        </div>
      ) : (
        <div className="mt-6">
          <CouponTable coupons={coupons} courseOptions={courseOptions} courseTitleById={courseTitleById} />
        </div>
      )}
    </div>
  );
}
