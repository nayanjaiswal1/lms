import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { getPublicTest } from "@/lib/server/public";
import { HireTestFlow } from "@/components/assessments/hire-test-flow";

interface PageProps {
  params: Promise<{ code: string }>;
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { code } = await params;
  try {
    const test = await getPublicTest(code);
    return { title: test.title, description: test.description };
  } catch {
    return { title: "Assessment" };
  }
}

export default async function HireLandingPage({ params }: PageProps) {
  const { code } = await params;
  let test;
  try {
    test = await getPublicTest(code);
  } catch {
    notFound();
  }

  return <HireTestFlow code={code} testInfo={test} />;
}
