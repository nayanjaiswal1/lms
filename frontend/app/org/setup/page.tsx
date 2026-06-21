import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { CheckCircle2 } from "lucide-react";

import { getMyOrgs, getOnboardingState } from "@/lib/server/orgs";
import { Step1Identity } from "@/app/org/setup/step-1-identity";
import { Step2Auth } from "@/app/org/setup/step-2-auth";
import { Step3Plan } from "@/app/org/setup/step-3-plan";
import { Step4Team } from "@/app/org/setup/step-4-team";

export const metadata: Metadata = { title: "Organization Setup" };

// ─── Progress indicator ───────────────────────────────────────────────────────

const STEPS = ["Identity", "Authentication", "Plan & Limits", "Team"] as const;

interface SetupProgressProps {
  currentStep: number;
}

function SetupProgress({ currentStep }: SetupProgressProps) {
  return (
    <nav aria-label="Setup progress" className="w-full">
      <ol className="flex items-center justify-between gap-1 sm:gap-2">
        {STEPS.map((label, index) => {
          const step = index + 1;
          const isCompleted = step < currentStep;
          const isCurrent = step === currentStep;

          return (
            <li key={label} className="flex flex-1 flex-col items-center gap-1.5">
              <div className="flex w-full items-center">
                {/* Connector before */}
                {index > 0 && (
                  <div
                    className={`h-px flex-1 transition-colors duration-normal ${
                      isCompleted || isCurrent ? "bg-primary" : "bg-border"
                    }`}
                  />
                )}

                {/* Circle */}
                <div
                  className={`flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-xs font-semibold transition-colors duration-normal ${
                    isCompleted
                      ? "bg-primary text-primary-foreground"
                      : isCurrent
                        ? "border-2 border-primary bg-background text-primary"
                        : "border-2 border-border bg-background text-muted-foreground"
                  }`}
                  aria-current={isCurrent ? "step" : undefined}
                >
                  {isCompleted ? (
                    <CheckCircle2 aria-hidden className="h-4 w-4" />
                  ) : (
                    step
                  )}
                </div>

                {/* Connector after */}
                {index < STEPS.length - 1 && (
                  <div
                    className={`h-px flex-1 transition-colors duration-normal ${
                      isCompleted ? "bg-primary" : "bg-border"
                    }`}
                  />
                )}
              </div>

              <span
                className={`hidden text-center text-xs sm:block ${
                  isCurrent
                    ? "font-medium text-foreground"
                    : isCompleted
                      ? "text-primary"
                      : "text-muted-foreground"
                }`}
              >
                {label}
              </span>
            </li>
          );
        })}
      </ol>
    </nav>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────

interface OrgSetupPageProps {
  searchParams: Promise<{ step?: string }>;
}

export default async function OrgSetupPage({ searchParams }: OrgSetupPageProps) {
  const { step: stepParam } = await searchParams;

  const orgs = await getMyOrgs();
  if (!orgs.length) notFound();

  const orgId = orgs[0].id;
  const state = await getOnboardingState(orgId);

  const requestedStep = parseInt(stepParam ?? "1", 10);
  const currentStep = Math.min(Math.max(Number.isNaN(requestedStep) ? 1 : requestedStep, 1), 4);

  return (
    <main className="page-container-sm py-12">
      <div className="mx-auto max-w-2xl">
        <div className="mb-8 flex flex-col gap-2">
          <h1 className="page-title">Set up your organization</h1>
          <p className="text-muted-foreground">
            Complete these steps to get your workspace ready.
          </p>
        </div>

        <SetupProgress currentStep={currentStep} />

        <div className="card-base mt-8 p-6">
          {currentStep === 1 && (
            <Step1Identity orgId={orgId} org={state.org} />
          )}
          {currentStep === 2 && (
            <Step2Auth orgId={orgId} authConfig={state.auth_config} />
          )}
          {currentStep === 3 && (
            <Step3Plan orgId={orgId} org={state.org} />
          )}
          {currentStep === 4 && (
            <Step4Team orgId={orgId} />
          )}
        </div>
      </div>
    </main>
  );
}
