import type { Metadata } from "next";
import { headers } from "next/headers";

import { DemoShell } from "@/app/demo/tour/demo-shell";
import { DEMO_LAB_KINDS, DEMO_TABS, type DemoLabKind, type DemoTabId } from "@/app/demo/tour/mock-data";

export const metadata: Metadata = {
  title: "Demo",
  description: "Try MindForge's courses, debug labs, quizzes and sheets — no account needed.",
};

interface Props {
  searchParams: Promise<{ tab?: string; course?: string; lab?: string }>;
}

export default async function DemoTourPage({ searchParams }: Props) {
  const { tab, course, lab } = await searchParams;
  const activeTab: DemoTabId = DEMO_TABS.find((t) => t.id === tab)?.id ?? "dashboard";

  const labKind: DemoLabKind = DEMO_LAB_KINDS.find((k) => k.id === lab)?.id ?? "debug";

  // proxy.ts puts the per-request CSP on the request; the preview iframe's
  // inline script needs that nonce because srcdoc frames inherit the policy.
  const csp = (await headers()).get("content-security-policy") ?? "";
  const nonce = /'nonce-([^']+)'/.exec(csp)?.[1] ?? "";

  return <DemoShell activeTab={activeTab} courseSlug={course} labKind={labKind} nonce={nonce} />;
}
