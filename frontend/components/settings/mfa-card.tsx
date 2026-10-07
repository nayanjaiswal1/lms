"use client";

import { useRouter } from "next/navigation";
import { ShieldCheck } from "lucide-react";

import { beginMfaSetupAction, enableMfaAction } from "@/app/(app)/settings/security/actions";
import { MfaRecoveryRegenerate } from "@/components/settings/mfa-recovery-regenerate";
import { MfaDisableForm } from "@/components/settings/mfa-disable-form";
import { MfaEnrollment } from "@/components/shared/mfa-enrollment";

export interface MfaStatus {
  enabled: boolean;
  required: boolean;
  recovery_codes_remaining: number;
}

interface MfaCardProps {
  status: MfaStatus;
}

export function MfaCard({ status }: MfaCardProps) {
  const router = useRouter();
  const refresh = () => router.refresh();

  return (
    <section aria-labelledby="mfa-heading" className="card-base space-y-5 p-6">
      <div>
        <h2 className="flex items-center gap-2 text-lg font-semibold text-foreground" id="mfa-heading">
          <ShieldCheck aria-hidden className="h-5 w-5 text-primary" />
          Two-factor authentication
        </h2>
        <p className="text-sm text-muted-foreground">
          Require a code from an authenticator app, in addition to your password, when you sign in.
          {status.required && " It is required for your role."}
        </p>
      </div>

      {status.enabled ? (
        <>
          <p className="text-sm text-foreground">
            Enabled. {status.recovery_codes_remaining} recovery code
            {status.recovery_codes_remaining === 1 ? "" : "s"} remaining.
          </p>
          <MfaRecoveryRegenerate onDone={refresh} />
          {!status.required && <MfaDisableForm onDisabled={refresh} />}
        </>
      ) : (
        <MfaEnrollment
          begin={beginMfaSetupAction}
          continueLabel="Done"
          finish={enableMfaAction}
          startLabel="Set up two-factor authentication"
          onComplete={refresh}
        />
      )}
    </section>
  );
}
