"use server";

import { revalidatePath } from "next/cache";
import { forceRetryJob, pauseAllOrgJobs, cancelAdminJob } from "@/lib/jobs/admin-server";
import ROUTES from "@/lib/routes";

export async function forceRetryJobAction(jobID: string): Promise<void> {
  await forceRetryJob(jobID);
  revalidatePath(ROUTES.PLATFORM_JOBS);
}

export async function cancelJobAction(jobID: string): Promise<void> {
  await cancelAdminJob(jobID);
  revalidatePath(ROUTES.PLATFORM_JOBS);
}

export async function pauseOrgJobsAction(orgID: string): Promise<void> {
  await pauseAllOrgJobs(orgID);
  revalidatePath(ROUTES.PLATFORM_JOBS);
}
