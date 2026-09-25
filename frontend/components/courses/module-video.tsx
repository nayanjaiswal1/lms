"use client";

import { useRef, useState } from "react";
import { updateProgressAction } from "@/lib/courses/actions";
import { showRewardToasts } from "@/components/shared/reward-toast";

interface ModuleVideoProps {
  moduleId: string;
  presignedUrl: string;
  initialPositionSeconds?: number;
}

export function ModuleVideo({ moduleId, presignedUrl, initialPositionSeconds = 0 }: ModuleVideoProps) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const [reported, setReported] = useState(false);

  function handleTimeUpdate() {
    const video = videoRef.current;
    if (!video || video.duration === 0) return;

    const pct = video.currentTime / video.duration;
    if (!reported && pct >= 0.9) {
      setReported(true);
      updateProgressAction({ moduleID: moduleId, status: "completed" }).then((res) => {
        if (res.ok && res.data?.rewards) showRewardToasts(res.data.rewards);
      });
    }
  }

  function handlePlay() {
    void updateProgressAction({ moduleID: moduleId, status: "in_progress" });
  }

  return (
    <div className="flex flex-col gap-3">
      <div className="overflow-hidden rounded-lg bg-card">
        {/* eslint-disable-next-line jsx-a11y/media-has-caption */}
        <video
          controls
          className="w-full"
          ref={videoRef}
          src={presignedUrl}
          onPlay={handlePlay}
          onTimeUpdate={handleTimeUpdate}
           
          {...(initialPositionSeconds > 0 ? { onLoadedMetadata: () => {
            if (videoRef.current) videoRef.current.currentTime = initialPositionSeconds;
          }} : {})}
        />
      </div>
    </div>
  );
}
