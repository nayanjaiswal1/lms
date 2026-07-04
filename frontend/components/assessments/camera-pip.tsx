"use client";

import * as React from "react";
import { Camera, ChevronDown, ChevronUp, Smartphone } from "lucide-react";

import { cn } from "@/lib/utils";
import { CameraVideo } from "@/components/assessments/camera-video";

interface CameraPipProps {
  stream: MediaStream | null;
  phoneConnected: boolean;
}

// Rendered inline as a section of the question palette sidebar (not fixed/
// floating) so it never overlaps the Next/Submit controls or question content.
export function CameraPip({ stream, phoneConnected }: CameraPipProps) {
  const [collapsed, setCollapsed] = React.useState(false);

  return (
    <div className="flex flex-col gap-2">
      <button
        onClick={() => setCollapsed((v) => !v)}
        aria-expanded={!collapsed}
        aria-label={collapsed ? "Show cameras" : "Hide cameras"}
        className="flex items-center justify-between text-xs font-medium text-muted-foreground transition-colors duration-fast hover:text-foreground"
      >
        <span>Cameras</span>
        {collapsed ? (
          <ChevronDown aria-hidden className="h-3.5 w-3.5" />
        ) : (
          <ChevronUp aria-hidden className="h-3.5 w-3.5" />
        )}
      </button>

      {!collapsed && (
        <div className="flex flex-col gap-2">
          {/* Primary — you */}
          <div className="flex flex-col gap-1">
            <div className="relative h-20 w-full overflow-hidden rounded-lg border border-border bg-muted">
              {stream ? (
                <>
                  <CameraVideo
                    stream={stream}
                    autoPlay
                    muted
                    playsInline
                    aria-label="Your primary camera"
                    className="h-full w-full object-cover"
                  />
                  <span className="absolute bottom-1 left-1 rounded-full bg-ai px-1.5 py-px text-xs font-semibold leading-tight text-ai-foreground">
                    Live
                  </span>
                </>
              ) : (
                <div className="flex h-full items-center justify-center">
                  <Camera aria-hidden className="h-5 w-5 text-muted-foreground" />
                </div>
              )}
            </div>
            <p className="text-xs text-muted-foreground">Primary</p>
          </div>

          {/* Secondary — phone */}
          <div className="flex flex-col gap-1">
            <div
              className={cn(
                "relative flex h-20 w-full flex-col items-center justify-center gap-1 overflow-hidden rounded-lg border bg-muted transition-colors duration-normal",
                phoneConnected ? "border-ai/60" : "border-border",
              )}
            >
              <Smartphone
                aria-hidden
                className={cn(
                  "h-5 w-5 transition-colors duration-normal",
                  phoneConnected ? "text-ai" : "text-muted-foreground",
                )}
              />
              <span
                className={cn(
                  "text-xs transition-colors duration-normal",
                  phoneConnected ? "text-ai" : "text-muted-foreground",
                )}
              >
                {phoneConnected ? "Connected" : "No phone"}
              </span>
              {phoneConnected && (
                <span className="absolute bottom-1 left-1 rounded-full bg-ai px-1.5 py-px text-xs font-semibold leading-tight text-ai-foreground">
                  Live
                </span>
              )}
            </div>
            <p className="text-xs text-muted-foreground">Secondary</p>
          </div>
        </div>
      )}
    </div>
  );
}
