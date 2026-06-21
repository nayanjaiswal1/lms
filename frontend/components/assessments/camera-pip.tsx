"use client";

import * as React from "react";
import { Camera, ChevronDown, ChevronUp, Smartphone } from "lucide-react";

import { cn } from "@/lib/utils";
import { CameraVideo } from "@/components/assessments/camera-video";

interface CameraPipProps {
  stream: MediaStream | null;
  phoneConnected: boolean;
}

export function CameraPip({ stream, phoneConnected }: CameraPipProps) {
  const [collapsed, setCollapsed] = React.useState(false);

  return (
    <div className="fixed bottom-4 right-4 z-raised flex flex-col items-end gap-1">
      {/* Toggle button */}
      <button
        onClick={() => setCollapsed((v) => !v)}
        aria-label={collapsed ? "Show cameras" : "Hide cameras"}
        className="flex h-7 items-center gap-1.5 rounded-full border border-border bg-background/90 px-2.5 text-xs font-medium text-muted-foreground shadow-sm backdrop-blur-sm transition-colors duration-fast hover:text-foreground"
      >
        {collapsed ? (
          <>
            <Camera aria-hidden className="h-3 w-3" />
            <span>Cameras</span>
            <ChevronUp aria-hidden className="h-3 w-3" />
          </>
        ) : (
          <>
            <ChevronDown aria-hidden className="h-3 w-3" />
            <span>Hide</span>
          </>
        )}
      </button>

      {/* Camera panels */}
      {!collapsed && (
        <div className="flex gap-1.5">
          {/* Primary — you */}
          <div className="flex flex-col gap-1">
            <div className="relative h-[72px] w-24 overflow-hidden rounded-lg border border-border bg-muted shadow sm:h-20 sm:w-28">
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
            <p className="text-center text-xs text-muted-foreground">Primary</p>
          </div>

          {/* Secondary — phone */}
          <div className="flex flex-col gap-1">
            <div
              className={cn(
                "relative flex h-[72px] w-24 flex-col items-center justify-center gap-1 overflow-hidden rounded-lg border bg-muted shadow transition-colors duration-normal sm:h-20 sm:w-28",
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
            <p className="text-center text-xs text-muted-foreground">Secondary</p>
          </div>
        </div>
      )}
    </div>
  );
}
