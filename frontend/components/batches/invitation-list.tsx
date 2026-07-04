import { MailCheck, MailX, Clock } from "lucide-react";
import { cn } from "@/lib/utils";

interface Invitation {
  id: string;
  email: string;
  accepted_at: string | null;
  declined_at: string | null;
  expires_at: string;
  created_at: string;
}

interface InvitationListProps {
  invitations: Invitation[];
}

function statusLabel(inv: Invitation): { label: string; className: string; Icon: React.ComponentType<{ className?: string }> } {
  if (inv.accepted_at) return { label: "Accepted", className: "text-primary", Icon: MailCheck };
  if (inv.declined_at) return { label: "Declined", className: "text-destructive", Icon: MailX };
  if (new Date(inv.expires_at) < new Date()) return { label: "Expired", className: "text-muted-foreground", Icon: Clock };
  return { label: "Pending", className: "text-muted-foreground", Icon: Clock };
}

export function InvitationList({ invitations }: InvitationListProps) {
  if (invitations.length === 0) {
    return <p className="text-sm text-muted-foreground">No invitations sent yet.</p>;
  }

  return (
    <div className="table-responsive">
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b border-border text-left text-xs text-muted-foreground">
            <th className="pb-2 font-medium">Email</th>
            <th className="pb-2 font-medium">Status</th>
            <th className="pb-2 font-medium">Sent</th>
            <th className="pb-2 font-medium">Expires</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-border">
          {invitations.map((inv) => {
            const { label, className, Icon } = statusLabel(inv);
            return (
              <tr className="text-sm" key={inv.id}>
                <td className="py-2.5 pr-4 font-mono text-xs">{inv.email}</td>
                <td className="py-2.5 pr-4">
                  <span className={cn("flex items-center gap-1", className)}>
                    <Icon className="h-3.5 w-3.5" />
                    {label}
                  </span>
                </td>
                <td className="py-2.5 pr-4 text-muted-foreground">
                  {new Date(inv.created_at).toLocaleDateString()}
                </td>
                <td className="py-2.5 text-muted-foreground">
                  {new Date(inv.expires_at).toLocaleDateString()}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
