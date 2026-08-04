import type { Metadata } from "next";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";

import { LandingPage } from "@/components/landing/landing-page";
import { getPublicCourses } from "@/lib/server/courses";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Courses, labs, and mentoring in one place",
  description:
    "Browse ready-to-enroll courses with hands-on labs, assessments, and mentoring. Free to sign up.",
};

export default async function RootPage() {
  const cookieStore = await cookies();
  const accessToken = cookieStore.get("access_token")?.value;

  if (accessToken) {
    redirect(ROUTES.DASHBOARD);
  }

  const { total } = await getPublicCourses(1);

  return <LandingPage total={total} />;
}
