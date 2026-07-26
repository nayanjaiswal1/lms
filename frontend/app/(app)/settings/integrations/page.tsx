import { apiGet } from "@/lib/server/api";
import { McpConnectionsManager, type McpConnection } from "@/components/settings/mcp-connections-manager";

export default async function SettingsIntegrationsPage() {
  const connections = (await apiGet<McpConnection[] | null>("/api/mcp-connections")) ?? [];
  // MCP_PUBLIC_URL overrides BACKEND_URL for the connector URL shown here —
  // useful when the backend itself is on localhost but reachable externally
  // (e.g. a client, or Claude/ChatGPT's cloud infra) only via a tunnel.
  const connectorUrl = `${process.env.MCP_PUBLIC_URL ?? process.env.BACKEND_URL}/mcp`;

  return (
    <div className="space-y-6">
      <McpConnectionsManager connections={connections} connectorUrl={connectorUrl} />
    </div>
  );
}
