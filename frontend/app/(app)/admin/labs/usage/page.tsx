import { notFound } from "next/navigation"
import { getMyPermissions } from "@/lib/server/permissions"
import { PERMISSIONS } from "@/lib/auth/permission-codes"
import { apiGet } from "@/lib/server/api"
import { LabUsageView, type LabUsageResponse } from "./lab-usage-view"

interface SearchParams {
  days?: string
}

const WINDOW_OPTIONS = [7, 30, 90] as const
const DEFAULT_DAYS = 30

export default async function LabUsagePage({
  searchParams,
}: {
  searchParams: Promise<SearchParams>
}) {
  const myPerms = await getMyPermissions()
  if (!myPerms.includes(PERMISSIONS.ADMIN.MANAGE_ORG)) {
    notFound()
  }

  const sp = await searchParams
  const parsedDays = Number(sp.days)
  const days = WINDOW_OPTIONS.includes(parsedDays as (typeof WINDOW_OPTIONS)[number])
    ? parsedDays
    : DEFAULT_DAYS

  const usage = await apiGet<LabUsageResponse>(`/api/admin/labs/usage?days=${days}`)

  return (
    <div className="page-container">
      <LabUsageView days={days} usage={usage} windowOptions={WINDOW_OPTIONS} />
    </div>
  )
}
