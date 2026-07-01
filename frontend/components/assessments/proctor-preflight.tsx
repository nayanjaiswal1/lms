"use client";

import * as React from "react";
import {
  AlertCircle,
  Camera,
  CheckCircle2,
  Clock,
  Loader2,
  Maximize,
  Mic,
  Play,
  QrCode,
  ShieldCheck,
  Smartphone,
  Target,
  Terminal,
} from "lucide-react";
import { useDevToolsDetector } from "@/lib/assessments/use-devtools-detector";

import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Label } from "@/components/ui/label";
import { cn } from "@/lib/utils";
import { CameraVideo } from "@/components/assessments/camera-video";
import type { UseCameraSetup, PermissionStatus } from "@/lib/assessments/use-camera-setup";
import type { AttemptMeta, ProctoringConfig } from "@/lib/assessments/types";

interface ProctorPreflightProps {
  meta: AttemptMeta;
  proctoring: ProctoringConfig;
  setup: UseCameraSetup;
  onBegin: () => void;
}

function StatusDot({ status }: { status: PermissionStatus }) {
  if (status === "granted")
    return <CheckCircle2 aria-hidden className="h-4 w-4 shrink-0 text-ai" />;
  if (status === "denied")
    return <AlertCircle aria-hidden className="h-4 w-4 shrink-0 text-destructive" />;
  if (status === "requesting")
    return <Loader2 aria-hidden className="h-4 w-4 shrink-0 animate-spin text-muted-foreground" />;
  return (
    <span
      aria-hidden
      className="block h-4 w-4 shrink-0 rounded-full border-2 border-muted-foreground/40"
    />
  );
}

function PermissionRow({
  status,
  icon: Icon,
  label,
}: {
  status: PermissionStatus;
  icon: React.ElementType;
  label: string;
}) {
  const statusText =
    status === "granted"
      ? "Allowed"
      : status === "denied"
        ? "Blocked"
        : status === "requesting"
          ? "Requesting…"
          : "Not allowed yet";

  return (
    <div className="flex items-center gap-3 py-1">
      <StatusDot status={status} />
      <Icon aria-hidden className="h-4 w-4 shrink-0 text-muted-foreground" />
      <span className="flex-1 text-sm">{label}</span>
      <span
        className={cn(
          "text-xs font-medium",
          status === "granted"
            ? "text-ai"
            : status === "denied"
              ? "text-destructive"
              : "text-muted-foreground",
        )}
      >
        {statusText}
      </span>
    </div>
  );
}

export function ProctorPreflight({
  meta,
  proctoring,
  setup,
  onBegin,
}: ProctorPreflightProps) {
  const devToolsOpen = useDevToolsDetector(proctoring.block_devtools);
  const cameraReady = !proctoring.require_camera || setup.canProceed || setup.camera === "denied";
  const canBegin = cameraReady && !(proctoring.block_devtools && devToolsOpen);
  const beginLabel =
    proctoring.require_fullscreen ? "Enter Fullscreen & Begin" : "Begin Test";

  return (
    <div className="flex min-h-dvh flex-col lg:flex-row">

      {/* ── Left panel ────────────────────────────────────────────────────── */}
      <div className="flex flex-col items-center justify-center gap-4 bg-muted p-6 lg:sticky lg:top-0 lg:h-dvh lg:w-2/5 lg:p-10">
        {proctoring.require_camera ? (
          <>
            {/* Camera preview */}
            <div className="relative w-full max-w-sm overflow-hidden rounded-xl border border-border shadow-raised">
              <div className="aspect-video bg-background">
                {setup.stream ? (
                  <>
                    <CameraVideo
                      stream={setup.stream}
                      autoPlay
                      muted
                      playsInline
                      aria-label="Your camera preview"
                      className="h-full w-full object-cover"
                    />
                    <span className="absolute bottom-3 left-3 inline-flex items-center gap-1.5 rounded-full bg-ai px-2.5 py-1 text-xs font-semibold text-ai-foreground shadow">
                      <span aria-hidden className="block h-1.5 w-1.5 animate-pulse rounded-full bg-ai-foreground" />
                      Live
                    </span>
                  </>
                ) : (
                  <div className="flex h-full flex-col items-center justify-center gap-3">
                    <Camera aria-hidden className="h-12 w-12 text-muted-foreground/50" />
                    <p className="text-sm text-muted-foreground">Camera preview</p>
                  </div>
                )}
              </div>
            </div>
            <p className="text-center text-xs text-muted-foreground">
              Your primary camera — faces you during the test
            </p>
          </>
        ) : (
          <div className="flex w-full max-w-sm flex-col items-center gap-5 text-center">
            <div className="flex h-20 w-20 items-center justify-center rounded-full bg-primary/10 ring-1 ring-primary/20">
              <ShieldCheck aria-hidden className="h-10 w-10 text-primary" />
            </div>
            <div className="flex flex-col gap-1.5">
              <p className="text-base font-semibold">{meta.title}</p>
              <p className="text-sm text-muted-foreground">
                Review the rules below and begin when you&apos;re ready.
              </p>
            </div>
          </div>
        )}

        {/* Quick stats row (desktop) */}
        <div className="hidden w-full max-w-sm grid-cols-3 gap-3 lg:grid">
          <div className="flex flex-col items-center gap-1 rounded-lg border border-border/60 bg-card p-3">
            <Clock aria-hidden className="h-4 w-4 text-muted-foreground" />
            <span className="text-sm font-semibold">{meta.duration_minutes}m</span>
            <span className="text-xs text-muted-foreground">Duration</span>
          </div>
          <div className="flex flex-col items-center gap-1 rounded-lg border border-border/60 bg-card p-3">
            <Target aria-hidden className="h-4 w-4 text-muted-foreground" />
            <span className="text-sm font-semibold">{meta.pass_percentage}%</span>
            <span className="text-xs text-muted-foreground">Pass mark</span>
          </div>
          <div className="flex flex-col items-center gap-1 rounded-lg border border-border/60 bg-card p-3">
            <ShieldCheck aria-hidden className="h-4 w-4 text-muted-foreground" />
            <span className="text-sm font-semibold">{meta.total_points}pt</span>
            <span className="text-xs text-muted-foreground">Points</span>
          </div>
        </div>
      </div>

      {/* ── Right panel: setup steps ──────────────────────────────────────── */}
      <div className="flex flex-1 flex-col gap-6 overflow-y-auto p-6 lg:p-10">

        {/* Header */}
        <div className="flex flex-col gap-1">
          <h1 className="text-2xl font-bold leading-tight">{meta.title}</h1>
          <p className="text-sm text-muted-foreground">
            {proctoring.require_camera || proctoring.allow_secondary_camera
              ? "Complete setup before starting. Your session will be monitored."
              : "Review the rules below, then begin your test."}
          </p>
        </div>

        {/* Quick stats row (mobile only) */}
        <div className="grid grid-cols-3 gap-3 lg:hidden">
          <div className="flex flex-col items-center gap-1 rounded-lg border border-border bg-muted p-3">
            <Clock aria-hidden className="h-4 w-4 text-muted-foreground" />
            <span className="text-sm font-semibold">{meta.duration_minutes}m</span>
            <span className="text-xs text-muted-foreground">Duration</span>
          </div>
          <div className="flex flex-col items-center gap-1 rounded-lg border border-border bg-muted p-3">
            <Target aria-hidden className="h-4 w-4 text-muted-foreground" />
            <span className="text-sm font-semibold">{meta.pass_percentage}%</span>
            <span className="text-xs text-muted-foreground">Pass mark</span>
          </div>
          <div className="flex flex-col items-center gap-1 rounded-lg border border-border bg-muted p-3">
            <ShieldCheck aria-hidden className="h-4 w-4 text-muted-foreground" />
            <span className="text-sm font-semibold">{meta.total_points}pt</span>
            <span className="text-xs text-muted-foreground">Points</span>
          </div>
        </div>

        {/* ── Step 1: Camera & Mic ─────────────────────────────────────────── */}
        {proctoring.require_camera && (
          <section aria-labelledby="step-camera">
            <div className="mb-3 flex items-center gap-2">
              <span
                className={cn(
                  "flex h-6 w-6 shrink-0 items-center justify-center rounded-full text-xs font-bold",
                  setup.canProceed
                    ? "bg-ai text-ai-foreground"
                    : "bg-muted text-muted-foreground",
                )}
              >
                {setup.canProceed ? <CheckCircle2 aria-hidden className="h-3.5 w-3.5" /> : "1"}
              </span>
              <h2 id="step-camera" className="font-semibold">
                Camera &amp; Microphone
              </h2>
              <span className="ml-auto rounded-full bg-destructive/10 px-2 py-0.5 text-xs font-medium text-destructive">
                Required
              </span>
            </div>

            <div className="rounded-xl border border-border bg-card p-4">
              <PermissionRow status={setup.camera} icon={Camera} label="Camera" />
              <div className="my-1 border-b border-border" />
              <PermissionRow status={setup.microphone} icon={Mic} label="Microphone" />

              {setup.camera !== "granted" && (
                <div className="mt-4 flex flex-col gap-2">
                  <Button
                    onClick={() => void setup.requestPermissions()}
                    disabled={setup.camera === "requesting"}
                    className="w-full sm:w-auto"
                  >
                    {setup.camera === "requesting" ? (
                      <>
                        <Loader2 aria-hidden className="animate-spin" />
                        Requesting access…
                      </>
                    ) : (
                      <>
                        <Camera aria-hidden />
                        Allow Camera &amp; Microphone
                      </>
                    )}
                  </Button>
                  {setup.camera === "denied" && (
                    <p className="text-xs text-destructive">
                      Blocked — open browser settings → Site permissions → Camera, then refresh.
                    </p>
                  )}
                </div>
              )}
            </div>
          </section>
        )}

        {/* ── Step 2: Secondary camera ─────────────────────────────────────── */}
        {proctoring.allow_secondary_camera && (
          <section aria-labelledby="step-phone">
            <div className="mb-3 flex items-center gap-2">
              <span
                className={cn(
                  "flex h-6 w-6 shrink-0 items-center justify-center rounded-full text-xs font-bold",
                  setup.phoneConnected
                    ? "bg-ai text-ai-foreground"
                    : "bg-muted text-muted-foreground",
                )}
              >
                {setup.phoneConnected ? (
                  <CheckCircle2 aria-hidden className="h-3.5 w-3.5" />
                ) : (
                  proctoring.require_camera ? "2" : "1"
                )}
              </span>
              <h2 id="step-phone" className="font-semibold">
                Secondary Camera via Phone
              </h2>
              <span className="ml-auto rounded-full bg-muted px-2 py-0.5 text-xs text-muted-foreground">
                Optional
              </span>
            </div>

            <div
              className={cn(
                "rounded-xl border border-border bg-card p-4 transition-opacity duration-normal",
                setup.skipSecondary && "pointer-events-none opacity-40",
              )}
            >
              <div className="flex flex-col gap-4 sm:flex-row sm:items-start">
                {/* QR placeholder */}
                <div
                  aria-label="QR code to connect phone as secondary camera"
                  className="relative flex h-36 w-36 shrink-0 flex-col items-center justify-center self-center overflow-hidden rounded-lg border-2 border-dashed border-border bg-background p-2 sm:self-auto"
                >
                  <div className="absolute left-2 top-2 h-4 w-4 rounded-sm border-l-2 border-t-2 border-foreground/60" />
                  <div className="absolute right-2 top-2 h-4 w-4 rounded-sm border-r-2 border-t-2 border-foreground/60" />
                  <div className="absolute bottom-2 left-2 h-4 w-4 rounded-sm border-b-2 border-l-2 border-foreground/60" />
                  <div className="absolute bottom-2 right-2 h-4 w-4 rounded-sm border-b-2 border-r-2 border-foreground/60" />
                  <QrCode aria-hidden className="h-16 w-16 text-foreground/70" />
                  <span className="mt-1 text-center text-xs leading-tight text-muted-foreground">
                    QR ready after launch
                  </span>
                </div>

                {/* Instructions */}
                <div className="flex flex-col gap-3">
                  <p className="text-sm text-muted-foreground">
                    Open your phone camera and scan to join as a rear-facing secondary camera.
                    Reduces false proctoring flags and provides a second verification angle.
                  </p>

                  {setup.phoneConnected ? (
                    <div className="flex items-center gap-2">
                      <CheckCircle2 aria-hidden className="h-4 w-4 text-ai" />
                      <span className="text-sm font-medium text-ai">Phone connected</span>
                    </div>
                  ) : (
                    <div className="flex items-center gap-1.5">
                      <Smartphone aria-hidden className="h-4 w-4 text-muted-foreground" />
                      <span className="text-sm text-muted-foreground">Waiting for phone…</span>
                    </div>
                  )}

                  <div className="flex items-center gap-2.5">
                    <Checkbox
                      id="skip-phone"
                      checked={setup.skipSecondary}
                      onCheckedChange={(v) => setup.setSkipSecondary(v === true)}
                      disabled={setup.phoneConnected}
                    />
                    <Label htmlFor="skip-phone" className="cursor-pointer text-sm">
                      Skip secondary camera
                    </Label>
                  </div>
                </div>
              </div>
            </div>
          </section>
        )}

        {/* ── Test rules (compact) ──────────────────────────────────────────── */}
        {(proctoring.require_fullscreen ||
          proctoring.block_copy_paste ||
          proctoring.block_devtools ||
          proctoring.max_tab_switches > 0) && (
          <section
            aria-label="Test rules"
            className={cn(
              !proctoring.require_camera && !proctoring.allow_secondary_camera &&
                "flex flex-1 flex-col justify-center",
            )}
          >
            <div className="rounded-xl border border-border bg-card p-4">
              <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                Proctoring Rules
              </p>
              <ul className="flex flex-col gap-1.5 text-sm text-muted-foreground">
                {proctoring.require_fullscreen && (
                  <li className="flex items-start gap-2">
                    <Maximize aria-hidden className="mt-0.5 h-3.5 w-3.5 shrink-0" />
                    Fullscreen required — leaving triggers a flag
                  </li>
                )}
                {proctoring.block_copy_paste && (
                  <li className="flex items-start gap-2">
                    <span aria-hidden className="mt-0.5 block h-3.5 w-3.5 shrink-0 text-center text-xs font-bold leading-4">
                      ⌘
                    </span>
                    Copy, paste, and right-click are blocked
                  </li>
                )}
                {proctoring.max_tab_switches > 0 && (
                  <li className="flex items-start gap-2">
                    <span aria-hidden className="mt-0.5 block h-3.5 w-3.5 shrink-0 text-center text-xs font-bold leading-4">
                      ⊕
                    </span>
                    Max {proctoring.max_tab_switches} tab switch
                    {proctoring.max_tab_switches !== 1 ? "es" : ""} allowed
                  </li>
                )}
                {proctoring.block_devtools && (
                  <li className="flex items-start gap-2">
                    {devToolsOpen ? (
                      <AlertCircle
                        aria-hidden
                        className="mt-0.5 h-3.5 w-3.5 shrink-0 text-destructive"
                      />
                    ) : (
                      <Terminal
                        aria-hidden
                        className="mt-0.5 h-3.5 w-3.5 shrink-0"
                      />
                    )}
                    <span className={devToolsOpen ? "font-medium text-destructive" : ""}>
                      {devToolsOpen
                        ? "Close Developer Tools to begin the test"
                        : "Developer tools must remain closed during the test"}
                    </span>
                  </li>
                )}
              </ul>
            </div>
          </section>
        )}

        {/* ── CTA ───────────────────────────────────────────────────────────── */}
        <div className="mt-auto flex flex-col gap-2 pb-6 lg:pb-0">
          <Button
            size="lg"
            disabled={!canBegin}
            onClick={onBegin}
            className="w-full gap-2 font-semibold"
          >
            {proctoring.require_fullscreen ? (
              <>
                <Maximize aria-hidden />
                {beginLabel}
              </>
            ) : (
              <>
                <Play aria-hidden />
                {beginLabel}
              </>
            )}
          </Button>

          {!setup.canProceed && setup.camera === "idle" && (
            <p className="text-center text-xs text-muted-foreground">
              Allow camera and microphone access above to continue.
            </p>
          )}
          {setup.camera === "denied" && (
            <p className="text-center text-xs text-muted-foreground">
              Proceeding without camera — your attempt may receive additional flags.
            </p>
          )}
          {proctoring.block_devtools && devToolsOpen && (
            <p className="text-center text-xs text-destructive">
              Developer tools are open — close them to begin your test.
            </p>
          )}
        </div>
      </div>
    </div>
  );
}
