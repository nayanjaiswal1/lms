"use server";

import { revalidatePath } from "next/cache";
import { forceRetryJob, pauseAllOrgJobs, cancelAdminJob } from "@/lib/server/admin-jobs";
import ROUTES from "@/lib/routes";

export async function forceRetryJobAction(jobID: string): Promise<void> {
  await forceRetryJob(jobID);
  revalidatePath(ROUTES.ADMIN_JOBS);
}

export async function cancelJobAction(jobID: string): Promise<void> {
  await cancelAdminJob(jobID);
  revalidatePath(ROUTES.ADMIN_JOBS);
}

export async function pauseOrgJobsAction(orgID: string): Promise<void> {
  await pauseAllOrgJobs(orgID);
  revalidatePath(ROUTES.ADMIN_JOBS);
}
