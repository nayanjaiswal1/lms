"use server";

import { revalidatePath } from "next/cache";
import { cancelJob, retryJob, pauseJob } from "@/lib/server/jobs";

export async function cancelJobAction(
  orgID: string,
  jobID: string,
): Promise<void> {
  await cancelJob(orgID, jobID);
  revalidatePath(`/org/settings/jobs`);
  revalidatePath(`/org/settings/jobs/${jobID}`);
}

export async function retryJobAction(
  orgID: string,
  jobID: string,
): Promise<void> {
  await retryJob(orgID, jobID);
  revalidatePath(`/org/settings/jobs`);
  revalidatePath(`/org/settings/jobs/${jobID}`);
}

export async function pauseJobAction(
  orgID: string,
  jobID: string,
  paused: boolean,
): Promise<void> {
  await pauseJob(orgID, jobID, paused);
  revalidatePath(`/org/settings/jobs`);
  revalidatePath(`/org/settings/jobs/${jobID}`);
}
