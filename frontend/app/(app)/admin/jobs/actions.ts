"use server";

import { revalidatePath } from "next/cache";
import { forceRetryJob, pauseAllOrgJobs } from "@/lib/server/admin-jobs";

export async function forceRetryJobAction(jobID: string): Promise<void> {
  await forceRetryJob(jobID);
  revalidatePath("/admin/jobs");
}

export async function pauseOrgJobsAction(orgID: string): Promise<void> {
  await pauseAllOrgJobs(orgID);
  revalidatePath("/admin/jobs");
}
