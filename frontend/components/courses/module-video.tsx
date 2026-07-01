"use client";

import { useRef, useState } from "react";
import { updateProgressAction } from "@/lib/courses/actions";
import { showRewardToasts } from "@/components/rewards/reward-toast";

interface ModuleVideoProps {
  moduleId: string;
  presignedUrl: string;
  title: string;
  initialPositionSeconds?: number;
}

export function ModuleVideo({ moduleId, presignedUrl, title, initialPositionSeconds = 0 }: ModuleVideoProps) {
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
      <h2 className="text-xl font-semibold">{title}</h2>
      <div className="overflow-hidden rounded-lg bg-black">
        {/* eslint-disable-next-line jsx-a11y/media-has-caption */}
        <video
          ref={videoRef}
          src={presignedUrl}
          controls
          className="w-full"
          onPlay={handlePlay}
          onTimeUpdate={handleTimeUpdate}
          // eslint-disable-next-line no-restricted-syntax -- currentTime init requires inline assignment
          {...(initialPositionSeconds > 0 ? { onLoadedMetadata: () => {
            if (videoRef.current) videoRef.current.currentTime = initialPositionSeconds;
          }} : {})}
        />
      </div>
    </div>
  );
}
