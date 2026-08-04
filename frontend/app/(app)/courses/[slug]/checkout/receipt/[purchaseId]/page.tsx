import { notFound } from "next/navigation";

import { getCourses, getEnrollments, findCourseBySlug } from "@/lib/server/courses";
import { getReceipt } from "@/lib/server/mentoring";
import { getMyPermissions } from "@/lib/server/permissions";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import { formatMoney } from "@/lib/money";
import { RefundPurchaseButton } from "./refund-purchase-button";
import { PrintReceiptButton } from "./print-receipt-button";

interface Props {
  params: Promise<{ slug: string; purchaseId: string }>;
}

export default async function ReceiptPage({ params }: Props) {
  const { slug, purchaseId } = await params;
  const [courses, enrollments] = await Promise.all([getCourses(), getEnrollments().catch(() => [])]);
  const course = findCourseBySlug(courses, enrollments, slug);
  if (!course) notFound();

  const [receipt, myPerms] = await Promise.all([
    getReceipt(course.id, purchaseId).catch(() => null),
    getMyPermissions(),
  ]);
  if (!receipt) notFound();

  const canRefund = myPerms.includes(PERMISSIONS.PAYMENTS.MANAGE_REFUNDS) && receipt.status === "completed";

  return (
    <main className="page-container-sm">
      <style>{"@media print { .no-print { display: none; } }"}</style>

      <div className="card-base p-8 space-y-6">
        <div className="flex items-start justify-between gap-4">
          <div>
            <h1 className="section-title">Receipt</h1>
            <p className="text-sm text-muted-foreground">{course.title}</p>
          </div>
          <p className="font-mono text-sm text-muted-foreground">
            {receipt.receipt_number ?? "—"}
          </p>
        </div>

        <dl className="grid grid-cols-2 gap-y-3 text-sm">
          <dt className="text-muted-foreground">Date</dt>
          <dd className="text-right">{new Date(receipt.purchased_at).toLocaleDateString(undefined, { year: "numeric", month: "long", day: "numeric" })}</dd>

          <dt className="text-muted-foreground">Status</dt>
          <dd className="text-right capitalize">{receipt.status}</dd>

          <dt className="text-muted-foreground">Payment method</dt>
          <dd className="text-right capitalize">{receipt.provider}</dd>

          {receipt.discount_cents > 0 && (
            <>
              <dt className="text-muted-foreground">Discount</dt>
              <dd className="text-right">-{formatMoney(receipt.discount_cents, receipt.currency)}</dd>
            </>
          )}

          <dt className="font-medium text-foreground">Amount paid</dt>
          <dd className="text-right font-medium text-foreground">
            {formatMoney(receipt.amount_cents, receipt.currency)}
          </dd>
        </dl>

        <p className="text-xs text-muted-foreground">
          This is a payment receipt, not a GST invoice. Questions about this purchase? Raise a
          billing support ticket.
        </p>

        <div className="no-print flex flex-wrap items-center gap-3 pt-2">
          <PrintReceiptButton />
          {canRefund && <RefundPurchaseButton courseId={course.id} purchaseId={receipt.purchase_id} />}
        </div>
      </div>
    </main>
  );
}
