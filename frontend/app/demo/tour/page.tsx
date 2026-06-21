import type { Metadata } from "next";

import { DemoShell } from "@/app/demo/tour/demo-shell";

export const metadata: Metadata = {
  title: "Demo · MindForge",
  description: "Explore MindForge as a learner or team admin — no account needed.",
};

interface Props {
  searchParams: Promise<{ view?: string }>;
}

export default async function DemoTourPage({ searchParams }: Props) {
  const { view } = await searchParams;
  const activeView: "learner" | "admin" = view === "admin" ? "admin" : "learner";

  return <DemoShell activeView={activeView} />;
}
