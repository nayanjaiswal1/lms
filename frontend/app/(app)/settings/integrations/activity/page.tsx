import type { Metadata } from "next";
import { apiGet } from "@/lib/server/api";
import { McpActionLog, type McpActionLogPage } from "@/components/settings/mcp-action-log";

export const metadata: Metadata = {
  title: "Activity Log — AI Connector",
};

export default async function IntegrationsActivityPage({
  searchParams,
}: {
  searchParams: Promise<{ cursor?: string }>;
}) {
  const { cursor } = await searchParams;
  const query = cursor ? `?cursor=${encodeURIComponent(cursor)}` : "";
  const page = await apiGet<McpActionLogPage>(`/api/mcp-action-log${query}`);

  return (
    <div className="space-y-6">
      <McpActionLog page={page} />
    </div>
  );
}
