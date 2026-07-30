import { apiGet } from "@/lib/server/api";
import { AccessGate } from "@/components/shared/access-gate";
import { FEATURES } from "@/lib/features";
import { McpConnectionsManager, type McpConnection } from "@/components/settings/mcp-connections-manager";
import { GitlabConnectionManager, type GitlabConnectionStatus } from "@/components/settings/gitlab-connection-manager";
import type { GitlabInstallationStatus } from "@/components/settings/gitlab-installation-manager";

// GET /api/gitlab/status's real response shape (backend gitlab.StatusView) —
// always 200, an empty installations array and Connected:false on connection
// when nothing is set up yet.
interface GitlabStatusResponse {
  installations: GitlabInstallationStatus[];
  connection: GitlabConnectionStatus;
}

export default async function SettingsIntegrationsPage() {
  const [connections, gitlabStatus] = await Promise.all([
    apiGet<McpConnection[] | null>("/api/mcp-connections").then((c) => c ?? []),
    apiGet<GitlabStatusResponse>("/api/gitlab/status"),
  ]);
  // MCP_PUBLIC_URL overrides BACKEND_URL for the connector URL shown here —
  // useful when the backend itself is on localhost but reachable externally
  // (e.g. a client, or Claude/ChatGPT's cloud infra) only via a tunnel.
  const connectorUrl = `${process.env.MCP_PUBLIC_URL ?? process.env.BACKEND_URL}/mcp`;

  return (
    <div className="space-y-6">
      <AccessGate feature={FEATURES.AI_CONNECTOR} mode="hide">
        <McpConnectionsManager connections={connections} connectorUrl={connectorUrl} />
      </AccessGate>
      <GitlabConnectionManager
        connection={gitlabStatus.connection}
        installationConnected={gitlabStatus.installations.length > 0}
      />
    </div>
  );
}
